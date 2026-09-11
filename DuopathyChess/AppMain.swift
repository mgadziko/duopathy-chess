import SwiftUI

@main
struct DuopathyChessApp: App {
    @StateObject private var game = ChessGameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .frame(minWidth: 1060, minHeight: 760)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Duopathy Chess") { AboutBoxController.shared.show() }
            }
        }
    }
}
