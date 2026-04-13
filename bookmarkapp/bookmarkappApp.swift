//
//  bookmarkappApp.swift
//  bookmarkapp
//
//  Created by Alparslan Topbas on 29.11.2025.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
@main
struct BookmarkApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var selectionManager = SelectionManager.shared
    @State private var showingDeleteConfirmation = false
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(selectionManager)
        }
        .commands {
            SidebarCommands()
            
            CommandGroup(replacing: .newItem) {
                // Empty to remove default "New" menu
            }
            
            // Move commands for Collections
            CommandMenu("Collections") {
                Button("Move Up") {
                    selectionManager.moveSelectedGroupUp(in: persistenceController.container.viewContext)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(selectionManager.selectedGroup == nil)
                
                Button("Move Down") {
                    selectionManager.moveSelectedGroupDown(in: persistenceController.container.viewContext)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(selectionManager.selectedGroup == nil)
            }
            
            CommandMenu("Database") {
                Button("Delete All Data...") {
                    showDeleteAllDataDialog()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .newItem) {
                Button("Import Bookmarks...") {
                    importBookmarks()
                }
                Button("Export Bookmarks...") {
                    exportBookmarks()
                }
            }
        }
    }
    
    private func showDeleteAllDataDialog() {
        let alert = NSAlert()
        alert.messageText = "Delete All Data?"
        alert.informativeText = "This will permanently delete all groups and bookmarks. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            persistenceController.deleteAllData()
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "All Data Deleted"
            confirmAlert.informativeText = "All groups and bookmarks have been removed."
            confirmAlert.alertStyle = .informational
            confirmAlert.runModal()
        }
    }
    
    private func exportBookmarks() {
        let context = persistenceController.container.viewContext
        // Fetch data in background context if needed, but for now viewContext is main thread bound usually.
        // However, NSSavePanel MUST be on main thread.
        
        let html = BookmarkManager.shared.exportBookmarksToHTML(context: context)
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.html]
            savePanel.nameFieldStringValue = "bookmarks.html"
            savePanel.canCreateDirectories = true
            savePanel.title = "Export Bookmarks"
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try html.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func importBookmarks() {
        let context = persistenceController.container.viewContext
        
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [.html]
            openPanel.canChooseDirectories = false
            openPanel.canChooseFiles = true
            openPanel.allowsMultipleSelection = false
            openPanel.title = "Import Bookmarks"
            openPanel.message = "Select a bookmarks HTML file exported from Safari, Chrome, or Edge."
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    BookmarkManager.shared.importBookmarksFromHTML(url: url, context: context)
                    
                    let alert = NSAlert()
                    alert.messageText = "Import Successful"
                    alert.informativeText = "Bookmarks have been imported into a new collection."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            }
        }
    }
}


