//
//  FavoritesBar.swift
//  bookmarkapp
//


import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Combine

struct FavoritesBar: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bookmark.favoriteOrderIndex, ascending: true)],
        predicate: NSPredicate(format: "isFavorite == YES"),
        animation: .default)
    private var favoriteBookmarks: FetchedResults<Bookmark>
    
    @Binding var selectedBookmark: Bookmark?
    @State private var isDragOver = false
    @State private var draggedBookmark: Bookmark?
    @ObservedObject private var tabManager = TabManager.shared
    
    // Check if a bookmark's URL matches the current tab's URL
    private func isBookmarkSelected(_ bookmark: Bookmark) -> Bool {
        guard let selectedTabID = tabManager.selectedTabID,
              let selectedTab = tabManager.tabs.first(where: { $0.id == selectedTabID }),
              let tabURL = selectedTab.url,
              let bookmarkURL = bookmark.url else {
            return false
        }
        return tabURL.absoluteString == bookmarkURL
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(favoriteBookmarks) { bookmark in
                    FavoriteItem(
                        bookmark: bookmark,
                        isSelected: isBookmarkSelected(bookmark),
                        isDragging: draggedBookmark == bookmark
                    )
                        .onTapGesture {
                            selectedBookmark = bookmark
                            openBookmarkInTab(bookmark)
                        }
                        .onDrag {
                            self.draggedBookmark = bookmark
                            return NSItemProvider(object: bookmark.id!.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: FavoriteDropDelegate(
                            bookmark: bookmark,
                            draggedBookmark: $draggedBookmark,
                            favoriteBookmarks: Array(favoriteBookmarks),
                            onReorder: reorderFavorites
                        ))
                        .contextMenu {
                            Button("Open in New Tab") {
                                openInNewTab(bookmark)
                            }
                            
                            Divider()
                            
                            Button("Remove from Favorites") {
                                removeFavorite(bookmark)
                            }
                        }
                }
                
                if favoriteBookmarks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Drag bookmarks here to add to favorites")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 80)
        .frame(height: 80)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.secondary.opacity(0.2)),
            alignment: .bottom
        )
        .overlay(
            // Visual indicator when dragging over
            isDragOver ? 
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.05))
                : nil
        )
        .onDrop(of: [UTType.url, UTType.plainText, .text], isTargeted: $isDragOver) { providers in
            return handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        for provider in providers {
            // Check for URL type first
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.createFavoriteFromURL(url: url)
                        }
                    }
                }
                handled = true
            }
            // Check for plain text (could be a URL string or bookmark UUID)
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    if let string = string {
                        DispatchQueue.main.async {
                            // Try to parse as UUID first (existing bookmark)
                            if let uuid = UUID(uuidString: string) {
                                self.fetchAndAddToFavorites(uuid: uuid)
                            }
                            // Otherwise, try to parse as URL
                            else if let url = URL(string: string),
                                    (url.scheme == "http" || url.scheme == "https") {
                                self.createFavoriteFromURL(url: url)
                            }
                        }
                    }
                }
                handled = true
            }
        }
        
        return handled
    }
    
    private func createFavoriteFromURL(url: URL) {
        // Find or create Favorites group FIRST
        let groupFetchRequest: NSFetchRequest<Group> = Group.fetchRequest() as! NSFetchRequest<Group>
        groupFetchRequest.predicate = NSPredicate(format: "name ==[c] %@", "Favorites")
        groupFetchRequest.fetchLimit = 1
        
        var favoritesGroup: Group?
        
        do {
            let groups = try viewContext.fetch(groupFetchRequest)
            if let existingGroup = groups.first {
                favoritesGroup = existingGroup
            } else {
                // Create new Favorites group
                let newGroup = Group(context: viewContext)
                newGroup.id = UUID()
                newGroup.name = "Favorites"
                newGroup.createdAt = Date()
                newGroup.orderIndex = 0
                favoritesGroup = newGroup
                print("📁 Created new Favorites collection")
            }
        } catch {
            print("Error finding/creating Favorites group: \(error)")
            return
        }
        
        guard let group = favoritesGroup else { return }
        
        // Check if bookmark already exists
        let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest() as! NSFetchRequest<Bookmark>
        fetchRequest.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let existingBookmark = results.first {
                // Bookmark exists - move to Favorites and mark as favorite
                print("⭐ Bookmark exists, adding to Favorites: \(existingBookmark.wrappedTitle)")
                
                existingBookmark.isFavorite = true
                existingBookmark.favoriteOrderIndex = Int16(favoriteBookmarks.count)
                
                // Move to Favorites collection if not already there
                if existingBookmark.group != group {
                    print("📌 Moving bookmark from '\(existingBookmark.group?.wrappedName ?? "nil")' to 'Favorites'")
                    existingBookmark.group = group
                    existingBookmark.orderIndex = 0  // Add to top
                    
                    // Increment orderIndex for all other bookmarks in Favorites
                    for bookmark in group.bookmarkArray where bookmark != existingBookmark {
                        bookmark.orderIndex += 1
                    }
                }
                
                try viewContext.save()
                
                // Force UI refresh
                existingBookmark.objectWillChange.send()
                group.objectWillChange.send()
                
            } else {
                // Create new bookmark
                let newBookmark = Bookmark(context: viewContext)
                newBookmark.id = UUID()
                newBookmark.url = url.absoluteString
                newBookmark.title = "Loading..."
                newBookmark.createdAt = Date()
                newBookmark.isFavorite = true
                newBookmark.favoriteOrderIndex = Int16(favoriteBookmarks.count)
                
                // Increment orderIndex for all existing bookmarks in group
                for bookmark in group.bookmarkArray {
                    bookmark.orderIndex += 1
                }
                
                newBookmark.group = group
                newBookmark.orderIndex = 0  // Add to top
                
                try viewContext.save()
                
                print("✅ Created new favorite bookmark: \(url.absoluteString)")
                
                // Fetch metadata in background
                BookmarkManager.shared.fetchMetadata(for: url) { title, description, imageData in
                    DispatchQueue.main.async {
                        // Check if bookmark still exists
                        if newBookmark.managedObjectContext != nil {
                            newBookmark.title = title ?? url.host ?? "No Title"
                            newBookmark.summary = description
                            newBookmark.imageData = imageData
                            
                            do {
                                try self.viewContext.save()
                                
                                // Force UI refresh
                                newBookmark.objectWillChange.send()
                                group.objectWillChange.send()
                            } catch {
                                print("Error updating bookmark metadata: \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error creating favorite from URL: \(error)")
        }
    }
    
    private func reorderFavorites(from source: Bookmark, to destination: Bookmark) {
        var favorites = Array(favoriteBookmarks)
        guard let sourceIndex = favorites.firstIndex(of: source),
              let destIndex = favorites.firstIndex(of: destination) else { return }
        
        withAnimation(.default) {
            favorites.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
        }
        
        for (index, bookmark) in favorites.enumerated() {
            bookmark.favoriteOrderIndex = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error reordering favorites: \(error)")
        }
    }
    
    private func fetchAndAddToFavorites(uuid: UUID) {
        // Find or create Favorites group FIRST
        let groupFetchRequest: NSFetchRequest<Group> = Group.fetchRequest() as! NSFetchRequest<Group>
        groupFetchRequest.predicate = NSPredicate(format: "name ==[c] %@", "Favorites")
        groupFetchRequest.fetchLimit = 1
        
        var favoritesGroup: Group?
        
        do {
            let groups = try viewContext.fetch(groupFetchRequest)
            if let existingGroup = groups.first {
                favoritesGroup = existingGroup
            } else {
                // Create new Favorites group
                let newGroup = Group(context: viewContext)
                newGroup.id = UUID()
                newGroup.name = "Favorites"
                newGroup.createdAt = Date()
                newGroup.orderIndex = 0
                favoritesGroup = newGroup
                print("📁 Created new Favorites collection")
            }
        } catch {
            print("Error finding/creating Favorites group: \(error)")
            return
        }
        
        guard let group = favoritesGroup else { return }
        
        // Fetch the bookmark
        let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest() as! NSFetchRequest<Bookmark>
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let bookmark = results.first {
                print("⭐ Adding bookmark to Favorites: \(bookmark.wrappedTitle)")
                
                // Mark as favorite
                bookmark.isFavorite = true
                bookmark.favoriteOrderIndex = Int16(favoriteBookmarks.count)
                
                // Move to Favorites collection if not already there
                if bookmark.group != group {
                    print("📌 Moving bookmark from '\(bookmark.group?.wrappedName ?? "nil")' to 'Favorites'")
                    bookmark.group = group
                    bookmark.orderIndex = 0  // Add to top
                    
                    // Increment orderIndex for all other bookmarks in Favorites
                    for otherBookmark in group.bookmarkArray where otherBookmark != bookmark {
                        otherBookmark.orderIndex += 1
                    }
                }
                
                try viewContext.save()
                
                // Force UI refresh
                bookmark.objectWillChange.send()
                group.objectWillChange.send()
                
                print("✅ Bookmark added to Favorites and moved to Favorites collection")
            }
        } catch {
            print("Error adding to favorites: \(error)")
        }
    }

    
    
    private func removeFavorite(_ bookmark: Bookmark) {
        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Remove '\(bookmark.wrappedTitle)' from Favorites?"
        alert.informativeText = "This will permanently delete this bookmark."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Delete the bookmark completely
            viewContext.delete(bookmark)
            
            do {
                try viewContext.save()
                print("✅ Removed '\(bookmark.wrappedTitle)' from Favorites and deleted")
            } catch {
                print("Error removing favorite: \(error)")
            }
        }
    }
    
    
    private func openBookmarkInTab(_ bookmark: Bookmark) {
        guard let urlString = bookmark.url, let url = URL(string: urlString) else { return }
        
        let tabManager = TabManager.shared
        
        // If there's a selected tab, update it; otherwise create a new tab
        if let selectedID = tabManager.selectedTabID {
            tabManager.updateTab(id: selectedID, title: bookmark.wrappedTitle, url: url)
        } else {
            tabManager.addTab(url: url, title: bookmark.wrappedTitle)
        }
    }
    
    private func openInNewTab(_ bookmark: Bookmark) {
        guard let urlString = bookmark.url, let url = URL(string: urlString) else { return }
        TabManager.shared.addTab(url: url, title: bookmark.wrappedTitle)
    }
}

struct FavoriteItem: View {
    @ObservedObject var bookmark: Bookmark
    let isSelected: Bool
    let isDragging: Bool
    
    var faviconURL: URL? {
        guard let urlString = bookmark.url,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Favicon Icon
            if let faviconURL = faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                    case .failure(_), .empty:
                        Image(systemName: "globe")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                            .padding(6)
                    @unknown default:
                        Image(systemName: "globe")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Title
            Text(bookmark.wrappedTitle)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .opacity(isDragging ? 0 : 1)
    }
}

// Drop delegate for reordering favorites
struct FavoriteDropDelegate: DropDelegate {
    let bookmark: Bookmark
    @Binding var draggedBookmark: Bookmark?
    let favoriteBookmarks: [Bookmark]
    let onReorder: (Bookmark, Bookmark) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggedBookmark = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedBookmark = draggedBookmark,
              draggedBookmark != bookmark else { return }
        
        onReorder(draggedBookmark, bookmark)
    }
}
