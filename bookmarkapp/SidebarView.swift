//
//  SidebarView.swift
//  bookmarkapp
//


import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Combine

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var selectionManager: SelectionManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.orderIndex, ascending: true)],
        predicate: NSPredicate(format: "parent == nil"),
        animation: .default)
    private var groups: FetchedResults<Group>
    
    @Binding var selectedGroup: Group?
    
    // Add Group Alert
    @State private var showingAddGroupAlert = false
    @State private var newGroupName = ""
    @State private var parentGroupForNewGroup: Group?
    
    // Rename Group Alert
    @State private var groupToRename: Group?
    @State private var renameGroupName = ""
    
    // Error Alert
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Search
    @State private var searchText: String = ""
    
    var filteredGroups: [Group] {
        if searchText.isEmpty {
            return Array(groups)
        } else {
            return Array(groups).filter { group in
                matchesSearch(group: group, searchText: searchText)
            }
        }
    }
    
    // Recursive search: returns true if group or any of its children match
    private func matchesSearch(group: Group, searchText: String) -> Bool {
        if group.wrappedName.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        
        if let children = group.childrenArray {
            return children.contains { child in
                matchesSearch(group: child, searchText: searchText)
            }
        }
        
        return false
    }
    
    var body: some View {
        listContent
            .onChange(of: selectedGroup) { _, newValue in
                selectionManager.selectedGroup = newValue
            }
            .alert(parentGroupForNewGroup == nil ? "New Collection" : "New Subcollection", isPresented: $showingAddGroupAlert) {
                TextField("Name", text: $newGroupName)
                Button("Cancel", role: .cancel) {
                    newGroupName = ""
                    parentGroupForNewGroup = nil
                }
                Button("Create") {
                    addGroup()
                }
            }
            .alert("Rename Collection", isPresented: Binding<Bool>(
                get: { groupToRename != nil },
                set: { if !$0 { groupToRename = nil } }
            )) {
                TextField("New Name", text: $renameGroupName)
                    .id(groupToRename?.id)
                Button("Cancel", role: .cancel) {
                    groupToRename = nil
                }
                Button("Rename") {
                    if let group = groupToRename {
                        renameGroup(group, newName: renameGroupName)
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
    }
    
    private var listContent: some View {
        List(selection: $selectedGroup) {
            ForEach(filteredGroups) { group in
                RecursiveGroupView(
                    group: group,
                    selectedGroup: $selectedGroup,
                    searchText: searchText,
                    onAddSubcollection: { parent in
                        parentGroupForNewGroup = parent
                        showingAddGroupAlert = true
                    },
                    onRename: { group in
                        renameGroupName = group.name ?? ""
                        DispatchQueue.main.async {
                            groupToRename = group
                        }
                    },
                    onDelete: { group in
                        deleteGroup(group)
                    },
                    onMoveUp: { group in
                        moveGroupUp(group)
                    },
                    onMoveDown: { group in
                        moveGroupDown(group)
                    },
                    onMoveToTop: { group in
                        moveGroupToTop(group)
                    },
                    onMoveToBottom: { group in
                        moveGroupToBottom(group)
                    }
                )
            }
        }
        .contextMenu {
            Button("New Collection") {
                parentGroupForNewGroup = nil
                showingAddGroupAlert = true
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Bookmarks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    parentGroupForNewGroup = nil
                    showingAddGroupAlert = true
                }) {
                    Image(systemName: "plus")
                }
                .help("Add Collection")
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Collections")
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
                .padding(.vertical, 4)
                
                Divider()
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func addGroup() {
        withAnimation {
            let newGroup = Group(context: viewContext)
            newGroup.id = UUID()
            newGroup.createdAt = Date()
            newGroup.name = newGroupName.isEmpty ? (parentGroupForNewGroup == nil ? "New Collection" : "New Subcollection") : newGroupName
            
            if let parent = parentGroupForNewGroup {
                // Increment orderIndex for all existing children
                if let children = parent.childrenArray {
                    for child in children {
                        child.orderIndex += 1
                    }
                }
                newGroup.parent = parent
                newGroup.orderIndex = 0  // Add to top
            } else {
                // Increment orderIndex for all existing root groups
                for group in groups {
                    group.orderIndex += 1
                }
                newGroup.orderIndex = 0  // Add to top
            }
            
            newGroupName = ""
            parentGroupForNewGroup = nil
            
            saveContext()
        }
    }
    
    private func renameGroup(_ group: Group, newName: String) {
        withAnimation {
            group.name = newName.isEmpty ? "Untitled" : newName
            saveContext()
            
            // Reset states
            groupToRename = nil
        }
    }
    
    private func moveGroupUp(_ group: Group) {
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            siblings = groups.map { $0 }
        }
        
        guard let index = siblings.firstIndex(of: group), index > 0 else { return }
        let prevGroup = siblings[index - 1]
        
        // Swap orderIndex
        let tempOrder = group.orderIndex
        group.orderIndex = prevGroup.orderIndex
        prevGroup.orderIndex = tempOrder
        
        saveContext()
        
        // Force UI refresh
        group.objectWillChange.send()
        prevGroup.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }

    private func moveGroupDown(_ group: Group) {
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            siblings = groups.map { $0 }
        }
        
        guard let index = siblings.firstIndex(of: group), index < siblings.count - 1 else { return }
        let nextGroup = siblings[index + 1]
        
        // Swap orderIndex
        let tempOrder = group.orderIndex
        group.orderIndex = nextGroup.orderIndex
        nextGroup.orderIndex = tempOrder
        
        saveContext()
        
        // Force UI refresh
        group.objectWillChange.send()
        nextGroup.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }
    
    private func moveGroupToTop(_ group: Group) {
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            siblings = groups.map { $0 }
        }
        
        guard let index = siblings.firstIndex(of: group), index > 0 else { return }
        
        // Set to -1 temporarily to place it first
        group.orderIndex = -1
        
        // Save to ensure orderIndex is updated
        saveContext()
        
        // Reload siblings sorted by orderIndex to get the correct order
        if let parent = group.parent {
            siblings = (parent.childrenArray ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        } else {
            siblings = groups.sorted(by: { $0.orderIndex < $1.orderIndex })
        }
        
        // Reindex all groups with correct sequential indices
        for (newIndex, g) in siblings.enumerated() {
            g.orderIndex = Int16(newIndex)
        }
        
        saveContext()
        
        // Force UI refresh
        group.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }
    
    private func moveGroupToBottom(_ group: Group) {
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            siblings = groups.map { $0 }
        }
        
        guard let index = siblings.firstIndex(of: group), index < siblings.count - 1 else { return }
        
        // Set to high value to place it last
        group.orderIndex = Int16(siblings.count + 100)
        
        // Save to ensure orderIndex is updated
        saveContext()
        
        // Reload siblings sorted by orderIndex to get the correct order
        if let parent = group.parent {
            siblings = (parent.childrenArray ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        } else {
            siblings = groups.sorted(by: { $0.orderIndex < $1.orderIndex })
        }
        
        // Reindex all groups with correct sequential indices
        for (newIndex, g) in siblings.enumerated() {
            g.orderIndex = Int16(newIndex)
        }
        
        saveContext()
        
        // Force UI refresh
        group.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }
    
    private func deleteGroup(_ group: Group) {
        // Calculate total items that will be deleted (recursively)
        var bookmarksCount = 0
        var collectionsCount = 0
        var favoriteBookmarksCount = 0
        
        func countItems(in g: Group) {
            for bookmark in g.bookmarkArray {
                bookmarksCount += 1
                if bookmark.isFavorite {
                    favoriteBookmarksCount += 1
                }
            }
            collectionsCount += 1
            
            if let children = g.childrenArray {
                for child in children {
                    countItems(in: child)
                }
            }
        }
        
        countItems(in: group)
        
        print("🗑️ Attempting to delete: \(group.wrappedName)")
        print("   Total Bookmarks: \(bookmarksCount)")
        print("   Favorite Bookmarks: \(favoriteBookmarksCount) (will be moved to Favorites)")
        print("   Total Collections (including this): \(collectionsCount)")
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete '\(group.wrappedName)'?"
        
        var itemsDescription = ""
        if collectionsCount > 1 {
            itemsDescription += "\(collectionsCount) collection(s)"
        }
        if bookmarksCount > 0 {
            if !itemsDescription.isEmpty {
                itemsDescription += " and "
            }
            let regularBookmarks = bookmarksCount - favoriteBookmarksCount
            if regularBookmarks > 0 && favoriteBookmarksCount > 0 {
                itemsDescription += "\(regularBookmarks) bookmark(s) (+ \(favoriteBookmarksCount) favorites will be moved)"
            } else if favoriteBookmarksCount > 0 {
                itemsDescription += "\(favoriteBookmarksCount) bookmark(s) (will be moved to Favorites)"
            } else {
                itemsDescription += "\(bookmarksCount) bookmark(s)"
            }
        }
        
        if !itemsDescription.isEmpty {
            alert.informativeText = "This will permanently delete \(itemsDescription).\n\nThis action cannot be undone."
        } else {
            alert.informativeText = "This action cannot be undone."
        }
        
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User confirmed - proceed with recursive deletion
            withAnimation {
                if selectedGroup == group {
                    selectedGroup = nil
                }
                
                // Find or create Favorites group FIRST
                let favoritesGroup = findOrCreateFavoritesGroup()
                
                // Recursive delete function
                func recursiveDelete(_ g: Group) {
                    // First delete all child groups (recursively)
                    if let children = g.childrenArray {
                        for child in children {
                            recursiveDelete(child)
                        }
                    }
                    
                    // Then handle bookmarks in this group
                    for bookmark in g.bookmarkArray {
                        if bookmark.isFavorite {
                            // Move to Favorites collection instead of deleting
                            print("⭐ Moving favorite bookmark '\(bookmark.wrappedTitle)' to Favorites collection")
                            bookmark.group = favoritesGroup
                            bookmark.orderIndex = Int16(favoritesGroup.bookmarkArray.count)
                        } else {
                            // Regular bookmark - delete it
                            viewContext.delete(bookmark)
                        }
                    }
                    
                    // Finally delete the group itself
                    viewContext.delete(g)
                }
                
                recursiveDelete(group)
                saveContext()
                
                print("✅ Successfully deleted '\(group.wrappedName)' and all its contents")
                if favoriteBookmarksCount > 0 {
                    print("⭐ \(favoriteBookmarksCount) favorite bookmark(s) moved to Favorites collection")
                }
            }
        } else {
            print("❌ Delete cancelled by user")
        }
    }
    
    private func findOrCreateFavoritesGroup() -> Group {
        // Try to find existing Favorites group
        let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest() as! NSFetchRequest<Group>
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", "Favorites")
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let favoritesGroup = results.first {
                return favoritesGroup
            }
        } catch {
            print("Error fetching Favorites group: \(error)")
        }
        
        // Create new Favorites group if not found
        print("Creating new Favorites collection")
        let newFavoritesGroup = Group(context: viewContext)
        newFavoritesGroup.id = UUID()
        newFavoritesGroup.name = "Favorites"
        newFavoritesGroup.createdAt = Date()
        newFavoritesGroup.orderIndex = 0
        
        return newFavoritesGroup
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
struct RecursiveGroupView: View {
    @ObservedObject var group: Group
    @Binding var selectedGroup: Group?
    var searchText: String
    let onAddSubcollection: (Group) -> Void
    let onRename: (Group) -> Void
    let onDelete: (Group) -> Void
    let onMoveUp: (Group) -> Void
    let onMoveDown: (Group) -> Void
    let onMoveToTop: (Group) -> Void
    let onMoveToBottom: (Group) -> Void
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var isExpanded: Bool = false
    
    // Custom binding that disables animation
    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { 
                if !searchText.isEmpty { return true }
                return isExpanded 
            },
            set: { newValue in
                if searchText.isEmpty {
                    withAnimation(nil) {
                        isExpanded = newValue
                    }
                }
            }
        )
    }
    
    private func matchesSearch(_ group: Group) -> Bool {
        if searchText.isEmpty { return true }
        if group.wrappedName.localizedCaseInsensitiveContains(searchText) { return true }
        if let children = group.childrenArray {
            return children.contains { matchesSearch($0) }
        }
        return false
    }
    
    var body: some View {
        let children = group.childrenArray ?? []
        let filteredChildren = children.filter { matchesSearch($0) }
        
        if !filteredChildren.isEmpty {
            DisclosureGroup(isExpanded: isExpandedBinding) {
                ForEach(filteredChildren) { child in
                    RecursiveGroupView(
                        group: child,
                        selectedGroup: $selectedGroup,
                        searchText: searchText,
                        onAddSubcollection: onAddSubcollection,
                        onRename: onRename,
                        onDelete: onDelete,
                        onMoveUp: onMoveUp,
                        onMoveDown: onMoveDown,
                        onMoveToTop: onMoveToTop,
                        onMoveToBottom: onMoveToBottom
                    )
                }
            } label: {
                GroupRow(
                    group: group,
                    isSelected: selectedGroup == group,
                    onDropBookmark: moveBookmarkToGroup,
                    onAddSubcollection: {
                        onAddSubcollection(group)
                    },
                    onRename: {
                        onRename(group)
                    },
                    onDelete: {
                        onDelete(group)
                    },
                    onMoveUp: {
                        onMoveUp(group)
                    },
                    onMoveDown: {
                        onMoveDown(group)
                    },
                    onMoveToTop: {
                        onMoveToTop(group)
                    },
                    onMoveToBottom: {
                        onMoveToBottom(group)
                    }
                )
            }
            .tag(group)
            // Disable animation for expansion/collapse to prevent sliding effect
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            GroupRow(
                group: group,
                isSelected: selectedGroup == group,
                onDropBookmark: moveBookmarkToGroup,
                onAddSubcollection: {
                    onAddSubcollection(group)
                },
                onRename: {
                    onRename(group)
                },
                onDelete: {
                    onDelete(group)
                },
                onMoveUp: {
                    onMoveUp(group)
                },
                onMoveDown: {
                    onMoveDown(group)
                },
                onMoveToTop: {
                    onMoveToTop(group)
                },
                onMoveToBottom: {
                    onMoveToBottom(group)
                }
            )
            .tag(group)
        }
    }
    
    private func moveBookmarkToGroup(bookmarkUUID: String) {
        guard let uuid = UUID(uuidString: bookmarkUUID) else { return }
        
        let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest() as! NSFetchRequest<Bookmark>
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let bookmark = results.first {
                bookmark.group = group
                bookmark.orderIndex = Int16(group.bookmarkArray.count)
                try viewContext.save()
            }
        } catch {
            print("Error moving bookmark: \(error)")
        }
    }
}

struct GroupRow: View {
    @ObservedObject var group: Group
    var isSelected: Bool
    var onDropBookmark: ((String) -> Void)?
    var onAddSubcollection: (() -> Void)?
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onMoveToTop: (() -> Void)?
    var onMoveToBottom: (() -> Void)?
    @State private var isTargeted = false
    
    var body: some View {
        HStack {
            Label(group.wrappedName, systemImage: "folder")
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isTargeted ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                if let bookmarkUUID = string {
                    DispatchQueue.main.async {
                        onDropBookmark?(bookmarkUUID)
                    }
                }
            }
            return true
        }
        .contextMenu {
            if let onAddSubcollection = onAddSubcollection {
                Button("New Subcollection") {
                    onAddSubcollection()
                }
            }
            if let onRename = onRename {
                Button("Rename") {
                    onRename()
                }
            }
            
            Divider()
            
            if let onMoveUp = onMoveUp {
                Button(action: onMoveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
            }
            
            if let onMoveDown = onMoveDown {
                Button(action: onMoveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
            }
            
            if let onMoveToTop = onMoveToTop {
                Button(action: onMoveToTop) {
                    Label("Move to Top", systemImage: "arrow.up.to.line")
                }
            }
            
            if let onMoveToBottom = onMoveToBottom {
                Button(action: onMoveToBottom) {
                    Label("Move to Bottom", systemImage: "arrow.down.to.line")
                }
            }
            
            Divider()
            if let onDelete = onDelete {
                Button("Delete") {
                    onDelete()
                }
            }
        }
    }
}
