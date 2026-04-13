//
//  TabBarView.swift
//  bookmarkapp
//


import SwiftUI

struct TabBarView: View {
    @ObservedObject var tabManager = TabManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabItemView(
                        tab: tab,
                        title: tab.title, // Explicitly pass title to force update
                        isSelected: tabManager.selectedTabID == tab.id
                    )
                        .onTapGesture {
                            tabManager.selectTab(id: tab.id)
                        }
                }
                
                Button(action: {
                    tabManager.addTab()
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(height: 38)
        
        Divider()
    }
}

struct TabItemView: View {
    let tab: BrowserTab
    let title: String
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Favicon placeholder
            Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .primary : .secondary.opacity(0.5))
            
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary.opacity(0.6))
            
            Button(action: {
                TabManager.shared.closeTab(id: tab.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity((isSelected || isHovered) ? 1.0 : 0.4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isSelected ? 7 : 6)
        .frame(width: 190, height: isSelected ? 30 : 28)
        .background(
            ZStack {
                if isSelected {
                    // Active tab: Bright color + white background
                    tab.color.opacity(0.8)
                    Color(NSColor.windowBackgroundColor).opacity(0.92)
                } else {
                    // Inactive tab: Very subtle color
                    tab.color.opacity(0.15)
                }
            }
        )
        .clipShape(RoundedTopCorner(radius: 16))
        .overlay(
            RoundedTopCorner(radius: 16)
                .stroke(isSelected ? tab.color.opacity(0.8) : Color.clear, lineWidth: isSelected ? 1 : 0)
        )
        .shadow(
            color: isSelected ? tab.color.opacity(0.5) : Color.clear,
            radius: isSelected ? 8 : 0,
            x: 0,
            y: isSelected ? 4 : 0
        )
        .scaleEffect(isSelected ? 1.0 : 0.96)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .padding(.trailing, -1)
        .contextMenu {
            if let url = tab.url {
                Button("Open in Default Browser") {
                    NSWorkspace.shared.open(url)
                }
                
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
                
                Divider()
            }
            
            Button("Close Tab") {
                TabManager.shared.closeTab(id: tab.id)
            }
            
            if tabManager.tabs.count > 1 {
                Button("Close Other Tabs") {
                    let otherTabs = tabManager.tabs.filter { $0.id != tab.id }
                    for otherTab in otherTabs {
                        TabManager.shared.closeTab(id: otherTab.id)
                    }
                }
            }
        }
    }
    
    @ObservedObject private var tabManager = TabManager.shared
}

// Custom Shape for rounded top corners only
struct RoundedTopCorner: Shape {
    var radius: CGFloat = 16
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from bottom left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left side going up
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Top-right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right side going down
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge (close the path)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        return path
    }
}
