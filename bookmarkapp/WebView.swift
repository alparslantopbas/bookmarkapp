//
//  WebView.swift
//  bookmarkapp
//
//  Created by Alparslan Topbas on 29.11.2025.
//

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    let tabID: UUID?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tabID: tabID)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Disable autoplay for videos
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        
        let webView = CustomWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Observe title changes
        webView.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
            nsView.load(request)
        }
    }
    
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.removeObserver(coordinator, forKeyPath: "title")
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tabID: UUID?
        
        init(tabID: UUID?) {
            self.tabID = tabID
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "title",
               let webView = object as? WKWebView,
               let title = webView.title,
               !title.isEmpty,
               let tabID = tabID {
                
                // Update tab title in TabManager
                DispatchQueue.main.async {
                    TabManager.shared.updateTab(id: tabID, title: title)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let tabID = tabID else { return }
            
            // Update both title and URL to reflect current page
            let title = webView.title?.isEmpty == false ? webView.title : "Untitled"
            let currentURL = webView.url
            
            DispatchQueue.main.async {
                TabManager.shared.updateTab(id: tabID, title: title, url: currentURL)
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
}

class CustomWebView: WKWebView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        // Customize menu items to replace "Window" with "Tab"
        menu?.items.forEach { item in
            if item.title.contains("Window") {
                item.title = item.title.replacingOccurrences(of: "Window", with: "Tab")
            } else if item.title.contains("Pencere") { // Turkish localization support
                item.title = item.title.replacingOccurrences(of: "Pencere", with: "Sekme")
            }
        }
        return menu
    }
}
