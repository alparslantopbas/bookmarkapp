//
//  TabManager.swift
//  bookmarkapp
//

import Foundation
import SwiftUI
import Combine

struct BrowserTab: Identifiable, Equatable {
    let id = UUID()
    var title: String = "New Tab"
    var url: URL?
    var favicon: URL?
    var color: Color = .blue // Tab color for visual distinction
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

// Pastel color palette for tabs
let tabColorPalette: [Color] = [
    Color(red: 0.8, green: 0.9, blue: 1.0),   // Light blue
    Color(red: 1.0, green: 0.9, blue: 0.8),   // Light orange
    Color(red: 0.9, green: 0.8, blue: 1.0),   // Light purple
    Color(red: 0.8, green: 1.0, blue: 0.9),   // Light green
    Color(red: 1.0, green: 0.8, blue: 0.9),   // Light pink
    Color(red: 0.95, green: 0.95, blue: 0.8), // Light yellow
    Color(red: 0.85, green: 0.95, blue: 0.95) // Light cyan
]

class TabManager: ObservableObject {
    static let shared = TabManager()
    
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?
    
    init() {
        // Start with one empty tab
        addTab()
    }
    
    func addTab(url: URL? = nil, title: String = "New Tab") {
        let randomColor = tabColorPalette.randomElement() ?? .blue
        var newTab = BrowserTab(title: title, url: url)
        newTab.color = randomColor
        tabs.append(newTab)
        selectedTabID = newTab.id
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        // If closing the selected tab, select another one
        if selectedTabID == id {
            if tabs.count > 1 {
                // Select the one to the left, or the first one if it was the first
                // We need to remove first to get the correct next tab, but we need the ID.
                // Actually, let's just pick the neighbor.
                let neighborIndex = index == 0 ? 1 : index - 1
                if neighborIndex < tabs.count {
                     selectedTabID = tabs[neighborIndex].id
                }
            } else {
                // Closing the last tab
                selectedTabID = nil
            }
        }
        
        tabs.remove(at: index)
        
        // Notify WebViewStore to clean up the WebView for this tab
        NotificationCenter.default.post(
            name: NSNotification.Name("TabClosed"),
            object: nil,
            userInfo: ["tabID": id]
        )
        
        // If all tabs closed, maybe create a new empty one? 
        // Or show empty state. Let's keep it empty for now.
        if tabs.isEmpty {
            addTab()
        }
    }
    
    func updateTab(id: UUID, title: String? = nil, url: URL? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        // Create a new instance with updated values to trigger SwiftUI update
        var updatedTab = tabs[index]
        if let title = title { updatedTab.title = title }
        if let url = url { updatedTab.url = url }
        
        // Replace the tab (this triggers @Published)
        tabs[index] = updatedTab
    }
    
    func selectTab(id: UUID) {
        selectedTabID = id
    }
}
