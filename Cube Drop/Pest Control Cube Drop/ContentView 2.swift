import SwiftUI

// Main SwiftUI entry point for the game UI
struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            // Embed the 3D game scene
            GameView(gameState: gameState)
                .edgesIgnoringSafeArea(.all)
            // You can add overlays below if desired (score, buttons, etc.)
        }
    }
}

#Preview {
    ContentView()
}
