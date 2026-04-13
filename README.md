# Bookmarks — macOS Bookmark Manager

A native macOS bookmark manager built with **SwiftUI** and **Core Data**, featuring iCloud sync, tab-based web browsing, drag & drop, and HTML import/export.

---

## ✨ Features

| Feature | Description |
|---|---|
| 📁 **Collections** | Organize bookmarks into nested groups (unlimited depth) |
| 🌐 **Built-in Browser** | Multi-tab WebView powered by WKWebView |
| ☁️ **iCloud Sync** | Automatic CloudKit sync across your Macs |
| 🖱️ **Drag & Drop** | Drag URLs from Safari/Chrome/Edge directly into the app |
| 📥 **Import** | Import bookmarks from Safari, Chrome, Edge, or Firefox (HTML format) |
| 📤 **Export** | Export all bookmarks as a standard Netscape HTML file |
| ⭐ **Favorites Bar** | Pin your most-visited bookmarks in a persistent top bar |
| 🔍 **Metadata Fetching** | Automatically fetches page title, description, and screenshot |
| ⌨️ **Keyboard Shortcuts** | Move collections up/down (`⌘↑ / ⌘↓`), delete all data (`⌘⇧D`) |
| 🗂️ **Sidebar Navigation** | Three-column layout (Collections → Bookmarks → Browser) |

---

## 🖥️ Requirements

- **macOS 15.6** or later
- **Xcode 16** or later
- An Apple Developer account (required for iCloud / CloudKit entitlements)

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/bookmarkapp.git
cd bookmarkapp
```

### 2. Open in Xcode

```bash
open bookmarkapp.xcodeproj
```

### 3. Configure signing

1. Select the `bookmarkapp` target in Xcode.
2. Under **Signing & Capabilities**, choose your own **Team** and set a unique **Bundle Identifier** (e.g. `com.yourname.bookmarkapp`).
3. If you don't need iCloud sync, you can remove the **iCloud / CloudKit** capability — the app falls back to local Core Data storage automatically in Debug builds.

### 4. Build & Run

Press **⌘R** in Xcode.

---

## ☁️ iCloud / CloudKit Setup

The app uses a conditional build setting:

| Build | Storage |
|---|---|
| **Debug** | Local Core Data (no iCloud required) |
| **Release** | `NSPersistentCloudKitContainer` (requires a valid CloudKit container) |

To use iCloud sync in Release builds, you need to:

1. Create a CloudKit container named `iCloud.com.YOURBUNDLEID` in the [Apple Developer portal](https://developer.apple.com).
2. Update `bookmarkapp.entitlements` with your container identifier.
3. Enable **iCloud** + **CloudKit** in Signing & Capabilities.

---

## 📦 Project Structure

```
bookmarkapp/
├── bookmarkappApp.swift      # App entry point, menu commands
├── ContentView.swift         # Root three-column NavigationSplitView
├── SidebarView.swift         # Collections sidebar (groups + CRUD)
├── BookmarkListView.swift    # Bookmark list with drag & drop
├── FavoritesBar.swift        # Favorites / pinned bookmarks bar
├── WebView.swift             # WKWebView wrapper
├── WebViewStore.swift        # Tab state management
├── TabManager.swift          # Multi-tab controller
├── TabBarView.swift          # Tab bar UI
├── BookmarkManager.swift     # HTML import & export, metadata fetcher
├── Persistence.swift         # Core Data / CloudKit stack
├── SelectionManager.swift    # Shared selection state
├── CodeDataModels.swift      # Core Data model extensions
└── bookmarkapp.xcdatamodeld/ # Core Data schema
```

---

## 🔑 Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘↑` | Move selected collection up |
| `⌘↓` | Move selected collection down |
| `⌘⇧D` | Delete all data (with confirmation) |

---

## 🌐 Browser Integration

Drag any URL from Safari, Chrome, Edge, or Firefox directly into the bookmark list. The app:

1. Creates a new bookmark entry.
2. Loads the page in a headless WKWebView.
3. Extracts title, meta description, and a screenshot preview.

YouTube URLs get special treatment — the oEmbed API is used to fetch the video title, author, and thumbnail.

---

## 📥 Import / Export

- **Import**: `File → Import Bookmarks…` — Supports the standard Netscape HTML bookmark format exported by all major browsers.
- **Export**: `File → Export Bookmarks…` — Exports the full collection tree as a valid Netscape HTML file.

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/my-feature`).
3. Commit your changes (`git commit -m 'Add my feature'`).
4. Push to the branch (`git push origin feature/my-feature`).
5. Open a Pull Request.

Please follow Swift API Design Guidelines and keep commits focused.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- Apple's [Core Data](https://developer.apple.com/documentation/coredata) & [CloudKit](https://developer.apple.com/documentation/cloudkit) frameworks
- Apple's [WebKit](https://developer.apple.com/documentation/webkit) for the embedded browser
- Inspired by Safari, Arc, and other Mac-native bookmark tools
