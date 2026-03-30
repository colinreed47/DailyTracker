import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id: Int
    let normalizedX: CGFloat
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let initialAngle: Double
    let spinDegrees: Double
    let delay: Double
    let fallDuration: Double
    let xDrift: CGFloat  // normalized (-0.1...0.1 of screen width)
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var falling = false

    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint, .teal
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(
                            falling
                                ? piece.initialAngle + piece.spinDegrees
                                : piece.initialAngle
                        ))
                        .offset(
                            x: piece.normalizedX * geo.size.width
                                + (falling ? piece.xDrift * geo.size.width : 0),
                            y: falling ? geo.size.height + 60 : -30
                        )
                        .animation(
                            .easeIn(duration: piece.fallDuration).delay(piece.delay),
                            value: falling
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            pieces = Self.generate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                falling = true
            }
        }
    }

    private static func generate() -> [ConfettiPiece] {
        (0..<90).map { i in
            ConfettiPiece(
                id: i,
                normalizedX: CGFloat(i) / 90 + CGFloat.random(in: -0.01...0.01),
                color: palette[i % palette.count],
                width: CGFloat.random(in: 6...12),
                height: CGFloat.random(in: 8...16),
                initialAngle: Double.random(in: 0...360),
                spinDegrees: Double.random(in: 180...540) * (i % 2 == 0 ? 1 : -1),
                delay: Double.random(in: 0...1.2),
                fallDuration: Double.random(in: 2.0...4.0),
                xDrift: CGFloat.random(in: -0.12...0.12)
            )
        }
    }
}
