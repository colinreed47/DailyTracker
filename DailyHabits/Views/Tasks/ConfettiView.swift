import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id: Int
    let normalizedX: CGFloat   // 0...1 of screen width
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool
    let initialAngle: Double
    let spinDegrees: Double
    let delay: Double
    let fallDuration: Double
    let xDrift: CGFloat        // normalized drift added during fall
    let startY: CGFloat        // above-screen start (negative)
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var falling = false

    private static let palette: [Color] = [
        .red,
        Color(red: 1,   green: 0.6,  blue: 0),    // orange
        Color(red: 1,   green: 0.85, blue: 0),    // gold
        .green,
        Color(red: 0.2, green: 0.8,  blue: 0.4),  // lime
        .blue,
        Color(red: 0.4, green: 0.2,  blue: 1),    // purple
        .pink,
        Color(red: 1,   green: 0.3,  blue: 0.5),  // hot pink
        .cyan, .mint, .teal,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Group {
                        if piece.isCircle {
                            Circle()
                                .fill(piece.color)
                                .frame(width: piece.width, height: piece.width)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(piece.color)
                                .frame(width: piece.width, height: piece.height)
                        }
                    }
                    .rotationEffect(.degrees(
                        falling
                            ? piece.initialAngle + piece.spinDegrees
                            : piece.initialAngle
                    ))
                    // .position uses absolute coords from top-left of the GeometryReader
                    .position(
                        x: piece.normalizedX * geo.size.width
                            + (falling ? piece.xDrift * geo.size.width : 0),
                        y: falling ? geo.size.height + 80 : piece.startY
                    )
                    .animation(
                        .easeIn(duration: piece.fallDuration).delay(piece.delay),
                        value: falling
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            pieces = Self.generate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                falling = true
            }
        }
    }

    private static func generate() -> [ConfettiPiece] {
        (0..<120).map { i in
            let isCircle = i % 5 == 0
            return ConfettiPiece(
                id: i,
                normalizedX: CGFloat(i) / 120 + CGFloat.random(in: -0.02...0.02),
                color: palette[i % palette.count],
                width: CGFloat.random(in: 7...13),
                height: isCircle ? CGFloat.random(in: 7...13) : CGFloat.random(in: 10...20),
                isCircle: isCircle,
                initialAngle: Double.random(in: 0...360),
                spinDegrees: Double.random(in: 200...600) * (i % 2 == 0 ? 1 : -1),
                delay: Double.random(in: 0...1.4),
                fallDuration: Double.random(in: 2.2...4.5),
                xDrift: CGFloat.random(in: -0.08...0.08),
                startY: CGFloat.random(in: -80 ... -10)
            )
        }
    }
}
