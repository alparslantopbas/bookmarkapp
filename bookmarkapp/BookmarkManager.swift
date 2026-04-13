//
//  BookmarkManager.swift
//  bookmarkapp
//

import Foundation
import WebKit
import Combine


class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    
    // Keep references to active fetchers to prevent deallocation
    private var activeFetchers: Set<MetadataFetcher> = []
    
    private init() {}
    
    func fetchMetadata(for url: URL, completion: @escaping (String?, String?, Data?) -> Void) {
        let fetcher = MetadataFetcher(url: url)
        activeFetchers.insert(fetcher)
        
        fetcher.start { [weak self] title, description, image in
            completion(title, description, image)
            self?.activeFetchers.remove(fetcher)
        }
    }
    
    func exportBookmarksToHTML(context: NSManagedObjectContext) -> String {
        let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest() as! NSFetchRequest<Group>
        fetchRequest.predicate = NSPredicate(format: "parent == nil") // Root groups
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Group.orderIndex, ascending: true)]
        
        var html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <!-- This is an automatically generated file.
             It will be read and overwritten.
             DO NOT EDIT! -->
        <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
        <TITLE>Bookmarks</TITLE>
        <H1>Bookmarks</H1>
        <DL><p>
        """
        
        do {
            let rootGroups = try context.fetch(fetchRequest)
            for group in rootGroups {
                html += generateHTML(for: group, indent: "    ")
            }
        } catch {
            print("Error fetching groups for export: \(error)")
        }
        
        html += "</DL><p>"
        return html
    }
    
    private func generateHTML(for group: Group, indent: String) -> String {
        var html = "\(indent)<DT><H3>\(group.wrappedName)</H3>\n"
        html += "\(indent)<DL><p>\n"
        
        // Add bookmarks in this group
        for bookmark in group.bookmarkArray {
            if let url = bookmark.url, let title = bookmark.title {
                html += "\(indent)    <DT><A HREF=\"\(url)\">\(title)</A>\n"
            }
        }
        
        // Recursively add subgroups
        if let children = group.childrenArray {
            for child in children {
                html += generateHTML(for: child, indent: indent + "    ")
            }
        }
        
        html += "\(indent)</DL><p>\n"
        return html
    }
    
    @Published var isImporting = false
    @Published var importProgress = 0.0
    @Published var importStatusMessage = ""

    // MARK: - Import Logic
    
    func importBookmarksFromHTML(url: URL, context: NSManagedObjectContext) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to read file")
            return
        }
        
        DispatchQueue.main.async {
            self.isImporting = true
            self.importProgress = 0.0
            self.importStatusMessage = "Reading file..."
        }
        
        // Create a root group for imported bookmarks
        let importGroup = Group(context: context)
        importGroup.id = UUID()
        importGroup.name = "Imported " + Date().formatted(date: .abbreviated, time: .shortened)
        importGroup.createdAt = Date()
        
        let lines = content.components(separatedBy: .newlines)
        let totalLines = Double(lines.count)
        
        // Regex patterns
        // H3: <H3 ...>Title</H3>
        let h3Pattern = try! NSRegularExpression(pattern: "<H3[^>]*>(.*?)</H3>", options: .caseInsensitive)
        // A: <A HREF="url" ...>Title</A>
        let aPattern = try! NSRegularExpression(pattern: "<A[^>]*HREF=\"([^\"]*)\"[^>]*>(.*?)</A>", options: .caseInsensitive)
        
        // Process in background to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async {
            let bgContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            bgContext.parent = context
            
            // Re-fetch the import group in the background context
            let bgImportGroup = bgContext.object(with: importGroup.objectID) as! Group
            var bgGroupStack: [Group] = [bgImportGroup]
            var bgCurrentGroup: Group = bgImportGroup
            
            for (index, line) in lines.enumerated() {
                // Update progress every 50 lines or so to avoid UI thrashing
                if index % 50 == 0 {
                    DispatchQueue.main.async {
                        self.importProgress = Double(index) / totalLines
                        self.importStatusMessage = "Importing... \(Int(self.importProgress * 100))%"
                    }
                }
                
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                
                if trimmed.contains("<H3") {
                    // Folder
                    if let match = h3Pattern.firstMatch(in: trimmed, options: [], range: range) {
                        if let titleRange = Range(match.range(at: 1), in: trimmed) {
                            let title = String(trimmed[titleRange])
                            
                            let newGroup = Group(context: bgContext)
                            newGroup.id = UUID()
                            newGroup.name = title
                            newGroup.createdAt = Date()
                            newGroup.parent = bgCurrentGroup
                            
                            // Calculate orderIndex
                            let currentCount = (bgCurrentGroup.children?.count ?? 0) + (bgCurrentGroup.bookmarks?.count ?? 0)
                            newGroup.orderIndex = Int16(currentCount)
                            
                            bgCurrentGroup = newGroup
                            bgGroupStack.append(newGroup)
                        }
                    }
                } else if trimmed.contains("</DL>") {
                    // End of folder
                    if bgGroupStack.count > 1 {
                        bgGroupStack.removeLast()
                        bgCurrentGroup = bgGroupStack.last!
                    }
                } else if trimmed.contains("<A") {
                    // Bookmark
                    if let match = aPattern.firstMatch(in: trimmed, options: [], range: range) {
                        if let urlRange = Range(match.range(at: 1), in: trimmed),
                           let titleRange = Range(match.range(at: 2), in: trimmed) {
                            
                            let urlString = String(trimmed[urlRange])
                            let title = String(trimmed[titleRange])
                            
                            let bookmark = Bookmark(context: bgContext)
                            bookmark.id = UUID()
                            bookmark.title = title
                            bookmark.url = urlString
                            bookmark.createdAt = Date()
                            bookmark.group = bgCurrentGroup
                            
                            // Calculate orderIndex
                            let currentCount = (bgCurrentGroup.children?.count ?? 0) + (bgCurrentGroup.bookmarks?.count ?? 0)
                            bookmark.orderIndex = Int16(currentCount)
                            
                            // NOTE: Metadata fetching is DISABLED here for performance.
                            // It should be done via a separate "Update Metadata" action or background queue.
                        }
                    }
                }
            }
            
            // Save background context
            do {
                try bgContext.save()
                // Save main context
                DispatchQueue.main.async {
                    do {
                        try context.save()
                        self.isImporting = false
                        self.importStatusMessage = "Import Complete"
                    } catch {
                        print("Error saving main context: \(error)")
                        self.isImporting = false
                        self.importStatusMessage = "Import Failed"
                    }
                }
            } catch {
                print("Error saving background context: \(error)")
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.importStatusMessage = "Import Failed"
                }
            }
        }
    }
    
}

class MetadataFetcher: NSObject, WKNavigationDelegate {
    let url: URL
    let id = UUID() // Unique identifier for hashing
    private var webView: WKWebView?
    private var completion: ((String?, String?, Data?) -> Void)?
    private var title: String?
    private var metaDescription: String?
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    func start(completion: @escaping (String?, String?, Data?) -> Void) {
        self.completion = completion
        
        // Check if it's a YouTube URL
        if let videoId = extractYouTubeVideoId(from: url) {
            fetchYouTubeThumbnail(videoId: videoId)
            return
        }
        
        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            // Configure for offscreen/headless if possible, but standard is fine
            self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
            self.webView?.navigationDelegate = self
            self.webView?.load(URLRequest(url: self.url))
        }
    }
    
    private func extractYouTubeVideoId(from url: URL) -> String? {
        let urlString = url.absoluteString
        
        // youtube.com/watch?v=VIDEO_ID
        if urlString.contains("youtube.com/watch") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoId
            }
        }
        
        // youtu.be/VIDEO_ID
        if urlString.contains("youtu.be/") {
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                return pathComponents[1].components(separatedBy: "?").first
            }
        }
        
        return nil
    }
    
    private func fetchYouTubeThumbnail(videoId: String) {
        // First, fetch metadata from oEmbed API
        let oembedURLString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json"
        
        guard let oembedURL = URL(string: oembedURLString) else {
            finish(imageData: nil)
            return
        }
        
        URLSession.shared.dataTask(with: oembedURL) { [weak self] data, _, _ in
            guard let self = self else { return }
            
            var videoTitle = "YouTube Video"
            var videoDescription: String? = nil
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                videoTitle = json["title"] as? String ?? "YouTube Video"
                if let authorName = json["author_name"] as? String {
                    videoDescription = "By \(authorName)"
                }
            }
            
            self.title = videoTitle
            self.metaDescription = videoDescription
            
            // Now fetch thumbnail
            let thumbnailURLString = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
            
            guard let thumbnailURL = URL(string: thumbnailURLString) else {
                self.finish(imageData: nil)
                return
            }
            
            URLSession.shared.dataTask(with: thumbnailURL) { data, response, error in
                // Check if maxresdefault exists (it returns 404 for some videos)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // Fallback to hqdefault
                    let fallbackURL = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")!
                    URLSession.shared.dataTask(with: fallbackURL) { data, _, _ in
                        self.finish(imageData: data)
                    }.resume()
                } else {
                    self.finish(imageData: data)
                }
            }.resume()
        }.resume()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Extract title
        webView.evaluateJavaScript("document.title") { [weak self] result, _ in
            self?.title = result as? String
        }
        
        // Extract description with multiple fallbacks
        let script = """
            (function() {
                // Try meta description
                var meta = document.querySelector('meta[name="description"]');
                if (meta && meta.content && meta.content.trim().length > 0) {
                    return meta.content.trim();
                }
                
                // Try Open Graph description
                var ogDescription = document.querySelector('meta[property="og:description"]');
                if (ogDescription && ogDescription.content && ogDescription.content.trim().length > 0) {
                    return ogDescription.content.trim();
                }
                
                // Try Twitter description
                var twitterDescription = document.querySelector('meta[name="twitter:description"]');
                if (twitterDescription && twitterDescription.content && twitterDescription.content.trim().length > 0) {
                    return twitterDescription.content.trim();
                }
                
                // Try first paragraph
                var paragraphs = document.querySelectorAll('p');
                for (var i = 0; i < paragraphs.length; i++) {
                    var text = paragraphs[i].innerText.trim();
                    if (text.length > 50) {  // Only use substantial paragraphs
                        return text.substring(0, 200);  // Limit to 200 chars
                    }
                }
                
                // Try H1 or H2
                var h1 = document.querySelector('h1');
                if (h1 && h1.innerText && h1.innerText.trim().length > 0) {
                    return h1.innerText.trim();
                }
                
                var h2 = document.querySelector('h2');
                if (h2 && h2.innerText && h2.innerText.trim().length > 0) {
                    return h2.innerText.trim();
                }
                
                return "";
            })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            self?.metaDescription = result as? String
        }
        
        // Wait a bit for rendering to finish before snapshotting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: 1024, height: 768)
            
            webView.takeSnapshot(with: config) { image, error in
                var pngData: Data? = nil
                if let image = image,
                   let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:]) {
                    pngData = png
                }
                
                self.finish(imageData: pngData)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView failed: \(error)")
        finish(imageData: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional failed: \(error)")
        finish(imageData: nil)
    }
    
    private func finish(imageData: Data?) {
        completion?(title, metaDescription, imageData)
        // Cleanup
        webView?.navigationDelegate = nil
        webView = nil
        completion = nil
    }
    
    // MARK: - Hashable
    override var hash: Int {
        return id.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MetadataFetcher else { return false }
        return self.id == other.id
    }
}
