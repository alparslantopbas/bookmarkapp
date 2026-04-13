# 🚀 Edge → Bookmarks.app: Basit 2 Adımlı Kullanım

## ⚡ HIZLI BAŞLANGIÇ

### Adım 1: Terminal'de Export
```bash
cd /Users/alparslantopbas/Testler/Google-Antigravity/SwiftUI/bookmarkapp
./edge_to_bookmarks_sync.py
```

### Adım 2: Bookmarks.app'te Import
1. Bookmarks.app'i açın
2. **File → Import Bookmarks...** (veya `⌘I`)
3. Şu dosyayı seçin: `~/EdgeBookmarksExport/edge_bookmarks_latest.html`

**Bitti!** 🎉

---

## 📋 DETAYLI ADIMLAR

### 1️⃣ Edge Bookmark'larını Export Et

Terminal'de:

```bash
# Proje dizinine git
cd ~/Testler/Google-Antigravity/SwiftUI/bookmarkapp

# Export script'ini çalıştır
./edge_to_bookmarks_sync.py
```

**Çıktı:**
```
============================================================
🌐 Edge Bookmarks → Bookmarks.app Exporter
============================================================

📊 Statistics:
   Total Bookmarks: 4254
   Total Folders: 92
   Total Items: 4346

🚀 Starting export...
🔍 Reading Edge bookmarks...
📑 Extracting Favorites Bar...
✅ Found 1815 items in Favorites Bar
✅ Exported to: ~/EdgeBookmarksExport/edge_bookmarks_20251214_150234.html
🔒 File permissions set to: -rw------- (owner only)
📌 Latest file link: ~/EdgeBookmarksExport/edge_bookmarks_latest.html

============================================================
✅ EXPORT SUCCESSFUL!
============================================================
```

### 2️⃣ Bookmarks.app'e Import Et

1. **Bookmarks.app'i aç**

2. **File → Import Bookmarks...** tıkla

3. File picker'da şu dosyayı seç:
   ```
   ~/EdgeBookmarksExport/edge_bookmarks_latest.html
   ```

4. **Open** tıkla

5. ✅ Import başarılı! Yeni bir koleksiyon oluşturuldu:
   ```
   "Imported Dec 14, 2025 at 3:02 PM"
   ```

---

## 🔁 GÜNLÜK KULLANIM

Her gün Edge bookmark'larınızı sync etmek için:

### Alias Oluşturma (Opsiyonel)

`.zshrc` veya `.bash_profile` dosyanıza ekleyin:

```bash
# Edge bookmarks export alias
alias edge-export='cd ~/Testler/Google-Antigravity/SwiftUI/bookmarkapp && ./edge_to_bookmarks_sync.py'
```

Sonra terminal'de sadece:

```bash
edge-export
```

yazmanız yeterli!

---

## 🛠️ DOSYA KONUMLARI

### Export Script:
```
~/Testler/Google-Antigravity/SwiftUI/bookmarkapp/edge_to_bookmarks_sync.py
```

### Export Dizini:
```
~/EdgeBookmarksExport/
```

### Son Export:
```
~/EdgeBookmarksExport/edge_bookmarks_latest.html  # Her zaman en son versiyonu gösterir
```

---

## 📊 Export İçeriği

Script **sadece Favorites Bar** (Edge toolbar'daki favoriler) bookmark'larını export eder:

✅ Favorites Bar içindeki tüm bookmark'lar  
✅ Klasör yapısı korunarak  
✅ HTML format (Safari/Chrome/Firefox uyumlu)

❌ Diğer Edge klasörleri export EDİLMEZ (istenirse script'i değiştirebiliriz)

---

## 🔐 Güvenlik

✅ Export edilen dosyalar sadece sizin için okunabilir (`-rw-------`)  
✅ Hiçbir network bağlantısı yok  
✅ Edge database'i sadece okunur, değiştirilmez  
✅ URL sanitization yapılır

Detaylı güvenlik analizi: `SECURITY_ANALYSIS.md`

---

## 🐛 Sorun Giderme

### "Edge bookmarks not found" hatası

Edge'in en az bir kere açılmış olduğundan emin olun:

```bash
# Edge bookmarks dosyasını kontrol et
ls -la ~/Library/Application\ Support/Microsoft\ Edge/Default/Bookmarks
```

### "Permission denied" hatası

Script'e execute izni verin:

```bash
chmod +x edge_to_bookmarks_sync.py
```

### "Python3 not found" hatası

Python3'ün kurulu olduğundan emin olun:

```bash
python3 --version

# Yoksa Homebrew ile kurun:
brew install python3
```

---

## 💡 İPUCU: Daha Hızlı Import

File picker'da `edge_bookmarks_latest.html` dosyasını seçmek yerine:

1. Finder'da `~/EdgeBookmarksExport/` klasörünü bookmark'layın
2. Veya export sonrası dosyayı direkt Bookmarks.app'e sürükleyip bırakabilirsiniz (drag & drop)

---

## 📝 Özet

```bash
# 1. Export
./edge_to_bookmarks_sync.py

# 2. Import
Bookmarks.app → File → Import Bookmarks... → edge_bookmarks_latest.html
```

**O kadar! 🎉**

---

## ℹ️ Ek Bilgiler

- **Bookmark sayısı:** Script export sırasında gösterir
- **Klasör yapısı:** Korunur
- **Timestamp:** Her export yeni dosya oluşturur (geçmiş tutuluyor)
- **Latest link:** Her zaman en son versiyona işaret eder

---

Daha fazla bilgi için:
- `EDGE_SYNC_README.md` - Detaylı dokümantasyon
- `SECURITY_ANALYSIS.md` - Güvenlik analizi
- `SECURITY_IMPROVEMENTS.md` - Uygulanan güvenlik önlemleri
