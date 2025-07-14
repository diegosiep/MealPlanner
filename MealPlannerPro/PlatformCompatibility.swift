
import SwiftUI
import Foundation

// MARK: - PlatformCompatibility.swift
// Purpose: Provides cross-platform compatibility for iOS and macOS
// Why needed: Your code uses iOS-only APIs that don't exist on macOS

// Add these imports at the top of files that need platform-specific features
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

// ==========================================
// NAVIGATION COMPATIBILITY EXTENSIONS
// ==========================================

// These extensions solve the "navigationBar" errors you're seeing
// Think of them as translators that convert iOS concepts to macOS concepts

extension View {
    
    // PROBLEM: .navigationBarTitleDisplayMode(.large) only exists on iOS
    // SOLUTION: Apply it only on iOS, ignore on macOS
    @ViewBuilder
    func compatibleNavigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        #if canImport(UIKit)
        // On iOS/iPadOS, use the navigation bar title display mode
        self.navigationBarTitleDisplayMode(mode)
        #else
        // On macOS, just return the view unchanged since macOS doesn't have navigation bars
        self
        #endif
    }
    
    // PROBLEM: .navigationBarLeading only exists on iOS
    // SOLUTION: Use different toolbar placements for different platforms
    @ViewBuilder
    func compatibleNavigationBarLeading<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if canImport(UIKit)
        // iOS uses navigationBarLeading
        self.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                content()
            }
        }
        #else
        // macOS uses different toolbar placement
        self.toolbar {
            ToolbarItem(placement: .navigation) {
                content()
            }
        }
        #endif
    }
    
    // PROBLEM: .navigationBarTrailing only exists on iOS
    // SOLUTION: Use appropriate trailing placement for each platform
    @ViewBuilder
    func compatibleNavigationBarTrailing<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if canImport(UIKit)
        // iOS uses navigationBarTrailing
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                content()
            }
        }
        #else
        // macOS uses primaryAction for trailing items
        self.toolbar {
            ToolbarItem(placement: .primaryAction) {
                content()
            }
        }
        #endif
    }
    
    // PROBLEM: Some navigation styles behave differently across platforms
    // SOLUTION: Provide a unified interface that adapts to each platform
    @ViewBuilder
    func compatibleNavigationViewStyle() -> some View {
        #if canImport(UIKit)
        // iOS works best with stack navigation for phone-like interfaces
        self.navigationViewStyle(StackNavigationViewStyle())
        #else
        // macOS works better with sidebar navigation for desktop-like interfaces
        self.navigationViewStyle(DefaultNavigationViewStyle())
        #endif
    }
}

// ==========================================
// ALERT AND SHEET COMPATIBILITY
// ==========================================

// These solve issues with alert and sheet presentation across platforms
extension View {
    
    // PROBLEM: Alert modifiers can behave differently on different platforms
    // SOLUTION: Provide a consistent alert interface
    @ViewBuilder
    func compatibleAlert<A, M>(
        _ title: Text,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View where A: View, M: View {
        #if canImport(UIKit)
        // iOS alert style
        self.alert(title, isPresented: isPresented, actions: actions, message: message)
        #else
        // macOS alert style (same API, but mentioning it for clarity)
        self.alert(title, isPresented: isPresented, actions: actions, message: message)
        #endif
    }
    
    // PROBLEM: Sheet presentation can have different behaviors
    // SOLUTION: Ensure consistent sheet behavior across platforms
    @ViewBuilder
    func compatibleSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
}

// ==========================================
// FILE HANDLING COMPATIBILITY
// ==========================================

// This solves the "Cannot find type 'UTType'" error
// UTType is used for file type definitions in modern iOS/macOS development
#if canImport(UniformTypeIdentifiers)
extension UTType {
    // Ensure PDF type is available (it should be, but this makes it explicit)
    static var compatiblePDF: UTType {
        return .pdf
    }
    
    // Add any other file types your app needs
    static var compatibleJSON: UTType {
        return .json
    }
    
    static var compatibleText: UTType {
        return .plainText
    }
}
#endif

// ==========================================
// COLOR SYSTEM COMPATIBILITY
// ==========================================

// Different platforms have different ways of handling system colors
extension Color {
    // PROBLEM: NSColor vs UIColor differences
    // SOLUTION: Provide unified color access
    
    static var compatibleControlBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    static var compatibleSecondaryBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
    
    static var compatibleLabel: Color {
        #if canImport(UIKit)
        return Color(UIColor.label)
        #elseif canImport(AppKit)
        return Color(NSColor.labelColor)
        #else
        return Color.primary
        #endif
    }
    
    static var compatibleSecondaryLabel: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondaryLabel)
        #elseif canImport(AppKit)
        return Color(NSColor.secondaryLabelColor)
        #else
        return Color.secondary
        #endif
    }
}

// ==========================================
// LAYOUT COMPATIBILITY
// ==========================================

// Different platforms have different optimal layouts
struct PlatformAdaptiveLayout<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if canImport(UIKit)
        // iOS: Stack-based layout works well for touch interfaces
        VStack {
            content
        }
        #else
        // macOS: Horizontal splits work well for larger screens
        HSplitView {
            content
        }
        #endif
    }
}

// ==========================================
// WINDOW SIZE COMPATIBILITY
// ==========================================

// Different platforms have different optimal window sizes
struct PlatformAdaptiveFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit)
        // iOS: Let the system handle sizing
        content
        #else
        // macOS: Set minimum window size for desktop use
        content
            .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

extension View {
    func platformAdaptiveFrame() -> some View {
        modifier(PlatformAdaptiveFrame())
    }
}

// ==========================================
// MENU COMPATIBILITY
// ==========================================

// Menu behavior can differ between platforms
extension View {
    @ViewBuilder
    func compatibleContextMenu<MenuItems: View>(
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        #if canImport(UIKit)
        // iOS: Use context menu (long press)
        self.contextMenu {
            menuItems()
        }
        #else
        // macOS: Use context menu (right click)
        self.contextMenu {
            menuItems()
        }
        #endif
    }
}

// ==========================================
// KEYBOARD SHORTCUTS COMPATIBILITY
// ==========================================

// Keyboard shortcuts work differently on different platforms
extension View {
    @ViewBuilder
    func compatibleKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        #if canImport(UIKit)
        // iOS: Limited keyboard shortcut support
        self.keyboardShortcut(key, modifiers: modifiers)
        #else
        // macOS: Full keyboard shortcut support
        self.keyboardShortcut(key, modifiers: modifiers)
        #endif
    }
}

// ==========================================
// PDF DOCUMENT COMPATIBILITY
// ==========================================

// Fix the PDF-related compilation errors
#if canImport(PDFKit)
import PDFKit

// Ensure PDFDocument is available on both platforms
extension PDFDocument {
    // Safe PDF creation that works on both platforms
    static func compatiblePDFDocument(data: Data) -> PDFDocument? {
        return PDFDocument(data: data)
    }
    
    // Safe data representation
    func compatibleDataRepresentation() -> Data? {
        return self.dataRepresentation()
    }
}
#endif

// ==========================================
// FILE DOCUMENT COMPATIBILITY
// ==========================================

// This fixes the UTType import issues in file handling
#if canImport(UniformTypeIdentifiers)
struct PlatformCompatiblePDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let pdfDocument: PDFDocument
    
    init(pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let document = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.pdfDocument = document
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = pdfDocument.dataRepresentation() ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
#endif

// ==========================================
// USAGE INSTRUCTIONS
// ==========================================

/*
 HOW TO USE THESE COMPATIBILITY FIXES:

 STEP 1: ADD THIS FILE
 - Add this file to your project as "PlatformCompatibility.swift"
 - Make sure to add the imports at the top of any file that uses these features

 STEP 2: REPLACE PLATFORM-SPECIFIC APIS
 In your existing views, replace iOS-only calls:

 BEFORE (causes macOS errors):
 .navigationBarTitleDisplayMode(.large)
 .toolbar {
     ToolbarItem(placement: .navigationBarLeading) { ... }
 }

 AFTER (works on both platforms):
 .compatibleNavigationBarTitleDisplayMode(.large)
 .compatibleNavigationBarLeading { ... }

 STEP 3: UPDATE COLOR USAGE
 Replace direct color calls:

 BEFORE:
 .background(Color(NSColor.controlBackgroundColor))  // macOS only

 AFTER:
 .background(Color.compatibleControlBackground)      // both platforms

 STEP 4: FIX IMPORT ERRORS
 Add these imports to files that have UTType errors:

 #if canImport(UniformTypeIdentifiers)
 import UniformTypeIdentifiers
 #endif

 STEP 5: TEST ON BOTH PLATFORMS
 - Build for iOS/iPadOS to ensure functionality works
 - Build for macOS to ensure no more compilation errors
 - The same code should now compile and run on both platforms

 The key principle here is: "Write once, run everywhere"
 Instead of having separate iOS and macOS code, these compatibility layers
 translate your intent into the appropriate platform-specific implementation.
 */
