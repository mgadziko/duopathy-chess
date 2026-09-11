import AppKit
import SwiftUI

final class AboutBoxController {
    static let shared = AboutBoxController()
    private var panel: NSPanel?

    func show() {
        if let panel { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 286), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(rootView: AboutBoxView())
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutBoxView: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if build.count == 10, build.allSatisfy(\.isNumber) {
            return "Version: \(build.prefix(6))-\(build.suffix(4))"
        }
        return build.isEmpty ? "Version: \(version)" : "Version: \(version) (Build \(build))"
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 20) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Duopathy Chess").font(.title2.weight(.semibold)).padding(.bottom, 6)
                        Text(versionText).foregroundStyle(.secondary).padding(.bottom, 18)
                        Text("A local Ollama chess arena where two language models play while revealing candidate moves on the board.").fixedSize(horizontal: false, vertical: true).padding(.bottom, 18)
                        Text("©2026 Mark Gadzikowski. All Rights Reserved Worldwide.").fontWeight(.semibold)
                        Text("Contact: duopathy-chess@quantumpenguin.net").padding(.top, 16)
                    }
                    Spacer(minLength: 0)
                }
                Spacer()
                HStack { Spacer(); Button("OK") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction).frame(width: 210); Spacer() }
            }
            .padding(24)
        }
        .frame(width: 520, height: 286)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView { let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active; return view }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
