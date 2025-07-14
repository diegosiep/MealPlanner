import SwiftUI
import Foundation

// MARK: - PlatformCompatibility.swift
// Fixed: NavigationBarItem unavailable in macOS

#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

#if canImport(PDFKit)
import PDFKit
#endif

// ==========================================
// NAVIGATION COMPATIBILITY EXTENSIONS
// ==========================================

extension View {
    @ViewBuilder
    func compatibleNavigationBarTitleDisplayMode(_ mode: CompatibleTitleDisplayMode) -> some View {
#if canImport(UIKit)
        self.navigationBarTitleDisplayMode(mode.toiOSMode)
#else
        self
#endif
    }
    
    @ViewBuilder
    func compatibleNavigationBarLeading<Content: View>(@ViewBuilder content: () -> Content) -> some View {
#if canImport(UIKit)
        self.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                content()
            }
        }
#else
        self.toolbar {
            ToolbarItem(placement: .navigation) {
                content()
            }
        }
#endif
    }
    
    @ViewBuilder
    func compatibleNavigationBarTrailing<Content: View>(@ViewBuilder content: () -> Content) -> some View {
#if canImport(UIKit)
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                content()
            }
        }
#else
        self.toolbar {
            ToolbarItem(placement: .primaryAction) {
                content()
            }
        }
#endif
    }
    
    @ViewBuilder
    func compatibleNavigationViewStyle() -> some View {
#if canImport(UIKit)
        self.navigationViewStyle(StackNavigationViewStyle())
#else
        self.navigationViewStyle(DefaultNavigationViewStyle())
#endif
    }
}

// ==========================================
// COMPATIBLE TITLE DISPLAY MODE
// ==========================================

enum CompatibleTitleDisplayMode {
    case automatic
    case inline
    case large
    
#if canImport(UIKit)
    var toiOSMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .automatic:
            return .automatic
        case .inline:
            return .inline
        case .large:
            return .large
        }
    }
#endif
}

// ==========================================
// COLOR COMPATIBILITY EXTENSIONS
// ==========================================

extension Color {
    static var compatibleControlBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
#else
        return Color(NSColor.controlBackgroundColor)
#endif
    }
    
    static var compatibleWindowBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.systemBackground)
#else
        return Color(NSColor.windowBackgroundColor)
#endif
    }
    
    static var compatibleTextBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.systemBackground)
#else
        return Color(NSColor.textBackgroundColor)
#endif
    }
    
    static var compatibleSecondaryBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
#else
        return Color(NSColor.controlBackgroundColor)
#endif
    }
}

// ==========================================
// ALERT AND SHEET COMPATIBILITY
// ==========================================

extension View {
    @ViewBuilder
    func compatibleAlert<A, M>(
        _ title: Text,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View where A: View, M: View {
        self.alert(title, isPresented: isPresented, actions: actions, message: message)
    }
    
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
// FRAME COMPATIBILITY
// ==========================================

struct PlatformAdaptiveFrame: ViewModifier {
    func body(content: Content) -> some View {
#if canImport(UIKit)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#else
        content
            .frame(minWidth: 800, minHeight: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

extension View {
    @ViewBuilder
    func compatibleContextMenu<MenuItems: View>(
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        self.contextMenu {
            menuItems()
        }
    }
}

// ==========================================
// KEYBOARD SHORTCUTS COMPATIBILITY
// ==========================================

extension View {
    @ViewBuilder
    func compatibleKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        self.keyboardShortcut(key, modifiers: modifiers)
    }
}

// ==========================================
// PDF DOCUMENT COMPATIBILITY
// ==========================================

#if canImport(PDFKit)
extension PDFDocument {
    static func compatiblePDFDocument(data: Data) -> PDFDocument? {
        return PDFDocument(data: data)
    }
    
    func compatibleDataRepresentation() -> Data? {
        return self.dataRepresentation()
    }
}
#endif

// ==========================================
// FILE DOCUMENT COMPATIBILITY
// ==========================================

#if canImport(UniformTypeIdentifiers)
struct PlatformCompatiblePDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let pdfData: Data
    
    init(pdfData: Data) {
        self.pdfData = pdfData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.pdfData = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: pdfData)
    }
}
#endif

// ==========================================
// ROBUST PDF SERVICE WITH COMPATIBILITY
// ==========================================
// Note: RobustPDFService and supporting types are defined in MealPlanPDFService.swift to avoid conflicts

// Removed duplicate VerifiedMealPlanSuggestion and VerifiedFood - using definitions from USDAVerifiedMealPlanningService.swift
