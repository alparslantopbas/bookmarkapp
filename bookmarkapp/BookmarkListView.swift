//
//  BookmarkListView.swift
//  bookmarkapp
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Combine

struct BookmarkListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var group: Group
    @State private var selectedBookmarkID: UUID?
    @AppStorage("bookmarkListWidth") private var bookmarkListWidth: Double = 300
    @AppStorage("isBookmarkListVisible") private var isBookmarkListVisible: Bool = true
    @State private var searchText: String = ""
    
    var initialSelectedBookmark: Bookmark?
    
    private let minWidth: Double = 200
    private let maxWidth: Double = 600
    private let resizeHandleWidth: Double = 8
    
    var selectedBookmark: Bookmark? {
        group.bookmarkArray.first { $0.id == selectedBookmarkID }
    }
    
    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return group.bookmarkArray
        } else {
            return group.bookmarkArray.filter { bookmark in
                bookmark.wrappedTitle.localizedCaseInsensitiveContains(searchText) ||
                bookmark.wrappedUrl.localizedCaseInsensitiveContains(searchText) ||
                (bookmark.summary?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Bookmarks list panel (collapsible)
                if isBookmarkListVisible {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            // Header section with search
                            HStack(spacing: 8) {
                                Text("Bookmarks")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                // Custom search field with icons
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                    
                                    TextField("Search", text: $searchText)
                                        .textFieldStyle(.plain)
                                    
                                    if !searchText.isEmpty {
                                        Button(action: { searchText = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            Divider()
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        List(selection: $selectedBookmarkID) {
                            if filteredBookmarks.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: searchText.isEmpty ? "bookmark.slash" : "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text(searchText.isEmpty ? "No Bookmarks" : "No Results")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(searchText.isEmpty ? "Drag and drop URLs here\nto add them." : "No bookmarks match '\(searchText)'")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(filteredBookmarks) { bookmark in
                                    BookmarkRow(
                                        bookmark: bookmark,
                                        selectedBookmarkID: $selectedBookmarkID,
                                        onMoveUp: { moveBookmarkUp(bookmark) },
                                        onMoveDown: { moveBookmarkDown(bookmark) },
                                        onMoveToTop: { moveBookmarkToTop(bookmark) },
                                        onMoveToBottom: { moveBookmarkToBottom(bookmark) }
                                    )
                                    .tag(bookmark.id)
                                }
                                .onDelete(perform: deleteBookmarks)
                            }
                        }
                        .listStyle(SidebarListStyle())
                        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: nil) { providers in
                            return handleDrop(providers: providers)
                        }
                    }
                    .frame(width: bookmarkListWidth)
                    .transition(.move(edge: .leading))
                    
                    // Enhanced resize handle - wider and easier to grab
                    ResizeHandle(
                        width: bookmarkListWidth,
                        onDrag: { translation in
                            let newWidth = bookmarkListWidth + translation
                            bookmarkListWidth = min(max(newWidth, minWidth), geometry.size.width - 300)
                        }
                    )
                    .frame(width: resizeHandleWidth)
                }
                
                // Detail/Browser
                VStack(spacing: 0) {
                    // Toolbar with toggle button
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isBookmarkListVisible.toggle()
                            }
                        }) {
                            Image(systemName: isBookmarkListVisible ? "sidebar.left" : "sidebar.left")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .help(isBookmarkListVisible ? "Hide Bookmarks" : "Show Bookmarks")
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .frame(height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    BrowserView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            if let initial = initialSelectedBookmark {
                selectedBookmarkID = initial.id
                // Open in current tab
                openBookmarkInTab(initial)
            }
        }
        .onChange(of: selectedBookmarkID) { oldValue, newID in
            if let newID = newID,
               let bookmark = group.bookmarkArray.first(where: { $0.id == newID }) {
                openBookmarkInTab(bookmark)
            }
        }
        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: nil) { providers in
            return handleDrop(providers: providers)
        }
    }
    
    private func deleteBookmarks(offsets: IndexSet) {
        withAnimation {
            offsets.map { group.bookmarkArray[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }
    
    private func moveBookmarkUp(_ bookmark: Bookmark) {
        guard let index = group.bookmarkArray.firstIndex(of: bookmark), index > 0 else { return }
        let prevBookmark = group.bookmarkArray[index - 1]
        
        // Swap orderIndex
        let tempOrder = bookmark.orderIndex
        bookmark.orderIndex = prevBookmark.orderIndex
        prevBookmark.orderIndex = tempOrder
        
        saveContext()
        group.objectWillChange.send()
    }

    private func moveBookmarkDown(_ bookmark: Bookmark) {
        guard let index = group.bookmarkArray.firstIndex(of: bookmark), index < group.bookmarkArray.count - 1 else { return }
        let nextBookmark = group.bookmarkArray[index + 1]
        
        // Swap orderIndex
        let tempOrder = bookmark.orderIndex
        bookmark.orderIndex = nextBookmark.orderIndex
        nextBookmark.orderIndex = tempOrder
        
        saveContext()
        group.objectWillChange.send()
    }
    
    private func moveBookmarkToTop(_ bookmark: Bookmark) {
        guard let index = group.bookmarkArray.firstIndex(of: bookmark), index > 0 else { return }
        
        // Set to -1 temporarily to place it first
        bookmark.orderIndex = -1
        
        // Reindex all bookmarks
        for (newIndex, bm) in group.bookmarkArray.enumerated() {
            bm.orderIndex = Int16(newIndex)
        }
        
        saveContext()
        group.objectWillChange.send()
    }
    
    private func moveBookmarkToBottom(_ bookmark: Bookmark) {
        let bookmarks = group.bookmarkArray
        guard let index = bookmarks.firstIndex(of: bookmark), index < bookmarks.count - 1 else { return }
        
        // Set to a high value to place it last
        bookmark.orderIndex = Int16(bookmarks.count)
        
        // Reindex all bookmarks
        for (newIndex, bm) in group.bookmarkArray.enumerated() {
            bm.orderIndex = Int16(newIndex)
        }
        
        saveContext()
        group.objectWillChange.send()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.addBookmark(url: url)
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    if let string = string,
                       // Filter out UUID strings (bookmark IDs)
                       UUID(uuidString: string) == nil,
                       let url = URL(string: string),
                       // Ensure it's a valid HTTP/HTTPS URL
                       (url.scheme == "http" || url.scheme == "https") {
                        DispatchQueue.main.async {
                            self.addBookmark(url: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    
    private func openBookmarkInTab(_ bookmark: Bookmark) {
        guard let urlString = bookmark.url, let url = URL(string: urlString) else { return }
        
        let tabManager = TabManager.shared
        
        // If there's a selected tab, update it; otherwise create a new tab
        if let selectedID = tabManager.selectedTabID {
            // First load the URL in WebViewStore (this creates the WebView if needed)
            WebViewStore.shared.loadURL(url, for: selectedID)
            // Then update the tab (this triggers SwiftUI update)
            tabManager.updateTab(id: selectedID, title: bookmark.wrappedTitle, url: url)
            // Force SwiftUI to re-render
            tabManager.objectWillChange.send()
        } else {
            tabManager.addTab(url: url, title: bookmark.wrappedTitle)
        }
    }
    
    private func addBookmark(url: URL) {
        // Increment orderIndex for all existing bookmarks
        for bookmark in group.bookmarkArray {
            bookmark.orderIndex += 1
        }
        
        // Create new bookmark at the top (orderIndex 0)
        let newBookmark = Bookmark(context: viewContext)
        newBookmark.id = UUID()
        newBookmark.url = url.absoluteString
        newBookmark.createdAt = Date()
        newBookmark.group = group
        newBookmark.orderIndex = 0  // Add to top
        newBookmark.title = "Loading..."
        
        // ⭐ AUTO-SYNC: If this is the "Favorites" collection, mark as favorite
        if group.wrappedName.lowercased() == "favorites" {
            newBookmark.isFavorite = true
            
            // Set favoriteOrderIndex to appear in Favorites Bar
            let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest() as! NSFetchRequest<Bookmark>
            fetchRequest.predicate = NSPredicate(format: "isFavorite == YES")
            
            do {
                let currentFavorites = try viewContext.fetch(fetchRequest)
                newBookmark.favoriteOrderIndex = Int16(currentFavorites.count)
            } catch {
                newBookmark.favoriteOrderIndex = 0
            }
        }
        
        saveContext()
        
        BookmarkManager.shared.fetchMetadata(for: url) { title, description, imageData in
            DispatchQueue.main.async {
                // Check if bookmark still exists before updating
                if newBookmark.managedObjectContext != nil {
                    newBookmark.title = title ?? url.host ?? "No Title"
                    newBookmark.summary = description
                    newBookmark.imageData = imageData
                    
                    self.saveContext()
                }
            }
        }
    }
}

struct BookmarkRow: View {
    @ObservedObject var bookmark: Bookmark
    @Binding var selectedBookmarkID: UUID?
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onMoveToTop: () -> Void
    var onMoveToBottom: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // Edit dialog states
    @State private var showingEditDialog = false
    @State private var editedURL = ""
    @State private var editedTitle = ""
    @State private var isRefreshingMetadata = false
    
    var faviconURL: URL? {
        guard let urlString = bookmark.url,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }
    
    // Check if this is a YouTube video URL
    private var isYouTubeVideo: Bool {
        guard let urlString = bookmark.url else { return false }
        return urlString.contains("youtube.com/watch") || urlString.contains("youtu.be/")
    }
    
    var body: some View {
        HStack {
            // For YouTube videos, show the thumbnail; for others, show favicon
            if isYouTubeVideo, let data = bookmark.imageData, let nsImage = NSImage(data: data) {
                // YouTube video thumbnail
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .clipped()
                    .cornerRadius(6)
            } else if let faviconURL = faviconURL {
                // Regular website favicon
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding(14)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    case .failure(_), .empty:
                        Image(systemName: "globe")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(14)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 68, height: 68)
            } else {
                // Fallback icon
                Image(systemName: "globe")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .padding(14)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .frame(width: 68, height: 68)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.wrappedTitle)
                    .font(.headline)
                Text(bookmark.wrappedUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let summary = bookmark.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded {
            selectedBookmarkID = bookmark.id
        })
        .padding(.vertical, 2)
        .onDrag {
            NSItemProvider(object: (bookmark.id?.uuidString ?? "") as NSString)
        }
        .contextMenu {
            Button("Open in New Tab") {
                openInNewTab()
            }
            
            Divider()
            
            Button("Edit") {
                editedURL = bookmark.wrappedUrl
                editedTitle = bookmark.wrappedTitle
                showingEditDialog = true
            }
            
            Divider()
            
            Button("Open in Default Browser") {
                if let url = URL(string: bookmark.wrappedUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bookmark.wrappedUrl, forType: .string)
            }
            
            Divider()
            
            Button(action: onMoveUp) {
                Label("Move Up", systemImage: "arrow.up")
            }
            
            Button(action: onMoveDown) {
                Label("Move Down", systemImage: "arrow.down")
            }
            
            Button(action: onMoveToTop) {
                Label("Move to Top", systemImage: "arrow.up.to.line")
            }
            
            Button(action: onMoveToBottom) {
                Label("Move to Bottom", systemImage: "arrow.down.to.line")
            }
            
            Divider()
            
            Button("Delete") {
                deleteBookmark()
            }
        }
        .sheet(isPresented: $showingEditDialog) {
            EditBookmarkDialog(
                url: $editedURL,
                title: $editedTitle,
                isRefreshing: $isRefreshingMetadata,
                onSave: {
                    saveEditedBookmark()
                },
                onCancel: {
                    showingEditDialog = false
                }
            )
        }
    }
    
    private func deleteBookmark() {
        withAnimation {
            viewContext.delete(bookmark)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting bookmark: \(error)")
            }
        }
    }
    
    private func openInNewTab() {
        guard let urlString = bookmark.url, let url = URL(string: urlString) else { return }
        TabManager.shared.addTab(url: url, title: bookmark.wrappedTitle)
    }
    
    private func saveEditedBookmark() {
        // Validate URL
        guard let url = URL(string: editedURL),
              url.scheme == "http" || url.scheme == "https" else {
            // Invalid URL, keep dialog open
            return
        }
        
        isRefreshingMetadata = true
        
        // Update bookmark
        bookmark.url = editedURL
        bookmark.title = editedTitle.isEmpty ? "Loading..." : editedTitle
        
        // Save to Core Data
        do {
            try viewContext.save()
        } catch {
            print("Error saving bookmark: \(error)")
        }
        
        // Fetch new metadata for the updated URL
        BookmarkManager.shared.fetchMetadata(for: url) { title, description, imageData in
            DispatchQueue.main.async {
                // Check if bookmark still exists before updating
                if bookmark.managedObjectContext != nil {
                    // Only update title if user left it empty or wants to refresh
                    if editedTitle.isEmpty {
                        bookmark.title = title ?? url.host ?? "No Title"
                    }
                    bookmark.summary = description
                    bookmark.imageData = imageData
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print("Error updating bookmark metadata: \(error)")
                    }
                    
                    // Force UI refresh
                    bookmark.objectWillChange.send()
                    
                    isRefreshingMetadata = false
                    showingEditDialog = false
                }
            }
        }
    }
}

struct BrowserView: View {
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var webViewStore = WebViewStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            TabBarView()
            
            // WebView area
            ZStack {
                // Render all tabs' WebViews but only show the selected one
                ForEach(tabManager.tabs) { tab in
                    if let url = tab.url {
                        TabWebView(tabID: tab.id, url: url)
                            .opacity(tabManager.selectedTabID == tab.id ? 1 : 0)
                            .allowsHitTesting(tabManager.selectedTabID == tab.id)
                    }
                }
                
                // Show "New Tab" overlay for selected tab without URL
                if let selectedID = tabManager.selectedTabID,
                   let selectedTab = tabManager.tabs.first(where: { $0.id == selectedID }),
                   selectedTab.url == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text("New Tab")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                }
                
                // No tabs
                if tabManager.tabs.isEmpty {
                    Text("No Tabs Open")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        // Force refresh when webViewStore updates
        .id(webViewStore.updateTrigger)
    }
}

// MARK: - Resize Handle Component
struct ResizeHandle: View {
    let width: Double
    let onDrag: (CGFloat) -> Void
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor.opacity(0.3) : 
                  (isHovering ? Color.secondary.opacity(0.2) : Color.clear))
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        onDrag(value.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Edit Bookmark Dialog
struct EditBookmarkDialog: View {
    @Binding var url: String
    @Binding var title: String
    @Binding var isRefreshing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var isValidURL: Bool = true
    
    private var urlIsValid: Bool {
        guard let parsedURL = URL(string: url) else { return false }
        return parsedURL.scheme == "http" || parsedURL.scheme == "https"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Bookmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // URL Field
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("https://example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: url) { _, _ in
                        isValidURL = urlIsValid
                    }
                
                if !isValidURL {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Please enter a valid HTTP or HTTPS URL")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Title Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Bookmark Title (leave empty to auto-fetch)", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                Text("Leave empty to automatically fetch from the website")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Loading Indicator
            if isRefreshing {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Refreshing metadata...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Button("Save") {
                    if urlIsValid {
                        onSave()
                    } else {
                        isValidURL = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!urlIsValid || isRefreshing)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480, height: 340)
        .onAppear {
            isValidURL = urlIsValid
        }
    }
}
