//
//  Persistence.swift
//  bookmarkapp
//

import CoreData
import SwiftUI

struct PersistenceController {
    static let shared = PersistenceController()
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Add some sample data for preview
        let newGroup = Group(context: viewContext)
        newGroup.id = UUID()
        newGroup.name = "Favorites"
        newGroup.createdAt = Date()
        
        let newBookmark = Bookmark(context: viewContext)
        newBookmark.id = UUID()
        newBookmark.url = "https://www.apple.com"
        newBookmark.title = "Apple"
        newBookmark.summary = "Discover the innovative world of Apple."
        newBookmark.createdAt = Date()
        newBookmark.group = newGroup
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        // CONDITIONAL iCloud: Use CloudKit in Release builds, local storage in Debug
        #if DEBUG
        print("🔧 DEBUG MODE: Using local storage (no iCloud)")
        container = NSPersistentContainer(name: "bookmarkapp")
        #else
        print("☁️ RELEASE MODE: Using iCloud sync")
        container = NSPersistentCloudKitContainer(name: "bookmarkapp")
        #endif
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable automatic migration
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        // IMPORTANT: Always enable history tracking to avoid read-only mode
        // Once enabled, it must stay enabled or the database becomes read-only
        if !inMemory {
            description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
            #if !DEBUG
            // CloudKit-specific options (only for Release mode)
            description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            #endif
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Check if it's a migration error
                if error.code == 134140 { // NSPersistentStoreIncompatibleVersionHashError
                    print("⚠️ Core Data model incompatible!")
                    print("💡 Deleting old database...")
                    
                    // Delete the old database files
                    if let storeURL = storeDescription.url {
                        try? FileManager.default.removeItem(at: storeURL)
                        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
                        print("🗑️ Database deleted. Please RESTART the app.")
                    }
                    
                    fatalError("Core Data migration failed. Database deleted. Please RESTART the app to create a fresh database.")
                }
                
                // Other errors
                print("❌ Core Data error: \(error)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func deleteAllData() {
        let viewContext = container.viewContext
        let entities = container.managedObjectModel.entities
        
        viewContext.performAndWait {
            for entity in entities {
                if let name = entity.name {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: name)
                    
                    do {
                        let objects = try viewContext.fetch(fetchRequest)
                        for object in objects {
                            viewContext.delete(object)
                        }
                    } catch {
                        print("Error fetching data for deletion: \(error)")
                    }
                }
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error saving after delete: \(error)")
                viewContext.rollback()
            }
        }
    }
}


