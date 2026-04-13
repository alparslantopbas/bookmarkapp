//
//  WebViewStore.swift
//  bookmarkapp
//
//
//  This store manages WKWebView instances for each tab, keeping them alive
//  when switching between tabs to preserve state (navigation history, form data, video playback, etc.)
//


import Foundation
import WebKit
import SwiftUI
import Combine

/// Manages persistent WKWebView instances for browser tabs
class WebViewStore: ObservableObject {
    static let shared = WebViewStore()
    
    /// Dictionary mapping tab IDs to their WKWebView instances
    private var webViews: [UUID: WKWebView] = [:]
    
    /// Dictionary mapping tab IDs to their coordinators (for proper cleanup)
    private var coordinators: [UUID: WebViewCoordinator] = [:]
    
    /// Track URLs that have been loaded for each tab
    private var loadedURLs: [UUID: URL] = [:]
    
    /// Published property to trigger view updates
    @Published var updateTrigger: UUID = UUID()
    
    private init() {
        // Listen for tab close events to clean up WebViews
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTabClosed(_:)),
            name: NSNotification.Name("TabClosed"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Gets or creates a WKWebView for the given tab ID
    func webView(for tabID: UUID, initialURL: URL?) -> WKWebView {
        if let existingWebView = webViews[tabID] {
            // If there's a new URL that's different from what we loaded, load it
            if let url = initialURL, loadedURLs[tabID] != url {
                loadURL(url, for: tabID)
            }
            return existingWebView
        }
        
        // Create a new WebView with configuration
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        
        // Enable persistent storage
        configuration.websiteDataStore = .default()
        
        let webView = CustomWebView(frame: .zero, configuration: configuration)
        
        // Create and store coordinator
        let coordinator = WebViewCoordinator(tabID: tabID)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        
        // Observe title changes
        webView.addObserver(coordinator, forKeyPath: "title", options: .new, context: nil)
        
        webViews[tabID] = webView
        coordinators[tabID] = coordinator
        
        // Load initial URL if provided
        if let url = initialURL {
            loadURL(url, for: tabID)
        }
        
        return webView
    }
    
    /// Check if a WebView exists for the given tab
    func hasWebView(for tabID: UUID) -> Bool {
        return webViews[tabID] != nil
    }
    
    /// Get the WebView for a specific tab (if it exists)
    func getWebView(for tabID: UUID) -> WKWebView? {
        return webViews[tabID]
    }
    
    /// Loads a new URL in an existing tab's WebView
    func loadURL(_ url: URL, for tabID: UUID) {
        // Check if this URL is already loaded
        if loadedURLs[tabID] == url {
            return
        }
        
        // Store the URL we're loading
        loadedURLs[tabID] = url
        
        // Get or create the WebView
        let webView: WKWebView
        if let existing = webViews[tabID] {
            webView = existing
        } else {
            webView = self.webView(for: tabID, initialURL: url)
            return // webView creation already loads the URL
        }
        
        // Load the URL
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        webView.load(request)
        
        // Trigger view update
        DispatchQueue.main.async {
            self.updateTrigger = UUID()
        }
    }
    
    /// Removes and cleans up the WebView for a closed tab
    func removeWebView(for tabID: UUID) {
        if let coordinator = coordinators[tabID],
           let webView = webViews[tabID] {
            // Remove observer
            webView.removeObserver(coordinator, forKeyPath: "title")
            
            // Stop loading
            webView.stopLoading()
        }
        
        webViews.removeValue(forKey: tabID)
        coordinators.removeValue(forKey: tabID)
        loadedURLs.removeValue(forKey: tabID)
    }
    
    @objc private func handleTabClosed(_ notification: Notification) {
        if let tabID = notification.userInfo?["tabID"] as? UUID {
            removeWebView(for: tabID)
        }
    }
}

/// Coordinator for handling WebView delegate methods
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let tabID: UUID
    
    init(tabID: UUID) {
        self.tabID = tabID
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title",
           let webView = object as? WKWebView,
           let title = webView.title,
           !title.isEmpty {
            
            // Update tab title in TabManager
            DispatchQueue.main.async {
                TabManager.shared.updateTab(id: self.tabID, title: title)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Update both title and URL to reflect current page
        let title = webView.title?.isEmpty == false ? webView.title : "Untitled"
        let currentURL = webView.url
        
        DispatchQueue.main.async {
            TabManager.shared.updateTab(id: self.tabID, title: title, url: currentURL)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleError(error, in: webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleError(error, in: webView)
    }
    
    // Handle "Open in New Window" (context menu or target="_blank") as "Open in New Tab"
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            DispatchQueue.main.async {
                TabManager.shared.addTab(url: url)
            }
        }
        return nil // Return nil to prevent opening a new window, since we handled it
    }
    
    private func handleError(_ error: Error, in webView: WKWebView) {
        let nsError = error as NSError
        // Ignore cancellation errors (happens when quickly switching pages)
        if nsError.code == NSURLErrorCancelled { return }
        
        let html = """
        <html>
        <head>
            <style>
                body { font-family: -apple-system, sans-serif; text-align: center; padding-top: 50px; color: #333; }
                h1 { font-size: 24px; margin-bottom: 10px; }
                p { font-size: 14px; color: #666; }
                .icon { font-size: 48px; margin-bottom: 20px; }
            </style>
        </head>
        <body>
            <div class="icon">⚠️</div>
            <h1>Failed to Load Page</h1>
            <p>\(error.localizedDescription)</p>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Simple WebView wrapper that shows a specific tab's WebView
struct TabWebView: NSViewRepresentable {
    let tabID: UUID
    let url: URL?
    @ObservedObject var webViewStore = WebViewStore.shared
    
    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.autoresizingMask = [.width, .height]
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Remove all existing subviews
        nsView.subviews.forEach { $0.removeFromSuperview() }
        
        guard let url = url else { return }
        
        // Get or create the WebView
        let webView = WebViewStore.shared.webView(for: tabID, initialURL: url)
        
        // Add to container
        webView.frame = nsView.bounds
        webView.autoresizingMask = [.width, .height]
        nsView.addSubview(webView)
        webView.isHidden = false
    }
}
