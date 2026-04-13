//
//  ContentView.swift
//  bookmarkapp
//


import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var bookmarkManager = BookmarkManager.shared
    @ObservedObject var tabManager = TabManager.shared
    @State private var selectedGroup: Group?
    @State private var selectedFavoriteBookmark: Bookmark?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Favorites Bar at the top
                FavoritesBar(selectedBookmark: $selectedFavoriteBookmark)
                
                // Main content
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(selectedGroup: $selectedGroup)
                } detail: {
                    if let favoriteBookmark = selectedFavoriteBookmark {
                        // Selected from favorites bar
                        BookmarkListView(group: favoriteBookmark.group!, initialSelectedBookmark: favoriteBookmark)
                            .id(favoriteBookmark.id) // Force refresh when favorite changes
                    } else if let group = selectedGroup {
                        // Selected from sidebar
                        BookmarkListView(group: group)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "globe.desk")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary.opacity(0.3))
                            
                            VStack(spacing: 8) {
                                Text("No Website Selected")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Text("Choose a bookmark from the list to browse")
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
            .onChange(of: selectedGroup) { oldValue, newGroup in
                // Clear favorite selection when user selects a collection
                if newGroup != nil {
                    selectedFavoriteBookmark = nil
                }
            }
            
            // Import Progress Overlay
            if bookmarkManager.isImporting {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView(value: bookmarkManager.importProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    
                    Text(bookmarkManager.importStatusMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
