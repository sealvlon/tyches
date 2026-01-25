import SwiftUI

/// Confetti celebration view for wins, achievements, streaks
struct ConfettiView: View {
    @State private var confetti: [ConfettiPiece] = []
    
    var body: some View {
        ZStack {
            ForEach(confetti) { piece in
                Text(piece.emoji)
                    .font(.system(size: piece.size))
                    .position(piece.position)
                    .opacity(piece.opacity)
                    .rotationEffect(.degrees(piece.rotation))
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        let emojis = ["🎉", "🎊", "✨", "⭐", "💰", "🏆", "🔥", "💎", "🎯", "💫"]
        
        for i in 0..<50 {
            let piece = ConfettiPiece(
                id: i,
                emoji: emojis.randomElement() ?? "✨",
                size: CGFloat.random(in: 20...40),
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -50
                ),
                opacity: 1,
                rotation: Double.random(in: 0...360)
            )
            confetti.append(piece)
        }
        
        // Animate falling
        for i in confetti.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 2...4)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: duration)) {
                    confetti[i].position.y = UIScreen.main.bounds.height + 100
                    confetti[i].position.x += CGFloat.random(in: -100...100)
                    confetti[i].rotation += Double.random(in: 360...720)
                }
                withAnimation(.easeIn(duration: duration * 0.8).delay(duration * 0.2)) {
                    confetti[i].opacity = 0
                }
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id: Int
    let emoji: String
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
    var rotation: Double
}

