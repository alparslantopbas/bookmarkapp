//
//  SelectionManager.swift
//  bookmarkapp
//
//  Created by Alparslan Topbas on 03.12.2025.
//

import SwiftUI
import CoreData
import Combine

class SelectionManager: ObservableObject {
    static let shared = SelectionManager()
    
    @Published var selectedGroup: Group?
    
    private init() {}
    
    func moveSelectedGroupUp(in context: NSManagedObjectContext) {
        guard let group = selectedGroup else { return }
        
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            let fetchRequest = Group.fetchRequest() as! NSFetchRequest<Group>
            fetchRequest.predicate = NSPredicate(format: "parent == nil")
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Group.orderIndex, ascending: true)]
            siblings = (try? context.fetch(fetchRequest)) ?? []
        }
        
        guard let index = siblings.firstIndex(of: group), index > 0 else { return }
        let prevGroup = siblings[index - 1]
        
        // Swap orderIndex
        let tempOrder = group.orderIndex
        group.orderIndex = prevGroup.orderIndex
        prevGroup.orderIndex = tempOrder
        
        do {
            try context.save()
            print("✅ Saved group move up: \(group.wrappedName)")
        } catch {
            print("❌ Error saving group move: \(error)")
        }
        
        // Force UI refresh
        group.objectWillChange.send()
        prevGroup.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }
    
    func moveSelectedGroupDown(in context: NSManagedObjectContext) {
        guard let group = selectedGroup else { return }
        
        var siblings: [Group]
        if let parent = group.parent {
            siblings = parent.childrenArray ?? []
        } else {
            let fetchRequest = Group.fetchRequest() as! NSFetchRequest<Group>
            fetchRequest.predicate = NSPredicate(format: "parent == nil")
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Group.orderIndex, ascending: true)]
            siblings = (try? context.fetch(fetchRequest)) ?? []
        }
        
        guard let index = siblings.firstIndex(of: group), index < siblings.count - 1 else { return }
        let nextGroup = siblings[index + 1]
        
        // Swap orderIndex
        let tempOrder = group.orderIndex
        group.orderIndex = nextGroup.orderIndex
        nextGroup.orderIndex = tempOrder
        
        do {
            try context.save()
            print("✅ Saved group move down: \(group.wrappedName)")
        } catch {
            print("❌ Error saving group move: \(error)")
        }
        
        // Force UI refresh
        group.objectWillChange.send()
        nextGroup.objectWillChange.send()
        group.parent?.objectWillChange.send()
    }
}
