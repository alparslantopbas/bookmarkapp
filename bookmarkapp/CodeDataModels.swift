//
//  CodeDataModels.swift
//  bookmarkapp
//

import Foundation
import CoreData

// These classes are usually auto-generated, but defining them here helps compile
// before the user creates the xcdatamodeld file, or if they choose "Manual/None" codegen.

@objc(Bookmark)
public class Bookmark: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var url: String?
    @NSManaged public var title: String?
    @NSManaged public var summary: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var imageData: Data?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var favoriteOrderIndex: Int16
    @NSManaged public var orderIndex: Int16
    @NSManaged public var group: Group?
}
extension Bookmark: Identifiable {
    public var wrappedTitle: String {
        title ?? "Unknown Title"
    }
    
    public var wrappedUrl: String {
        url ?? ""
    }
}
@objc(Group)
public class Group: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var bookmarks: NSSet?
    @NSManaged public var parent: Group?
    @NSManaged public var children: NSSet?
}
extension Group: Identifiable {
    public var wrappedName: String {
        name ?? "New Collection"
    }
    
    public var childrenArray: [Group]? {
        guard let childrenSet = children, !childrenSet.allObjects.isEmpty else {
            return nil
        }
        return childrenSet.allObjects
            .compactMap { $0 as? Group }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
    
    public var bookmarkArray: [Bookmark] {
        guard let bookmarksSet = bookmarks else { return [] }
        
        let bookmarksArray = bookmarksSet.allObjects.compactMap { $0 as? Bookmark }
        return bookmarksArray.sorted {
            $0.orderIndex < $1.orderIndex
        }
    }
}

