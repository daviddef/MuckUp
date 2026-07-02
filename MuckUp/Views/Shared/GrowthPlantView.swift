import SwiftUI

/// A little plant that grows as the user's streak builds — hand-drawn
/// vector shapes (no image assets), so it scales cleanly at any size.
enum PlantStage: Int, CaseIterable {
    case seedling, sapling, tree, blooming

    static func forStreak(_ streak: Int) -> PlantStage {
        switch streak {
        case 0...2:   return .seedling
        case 3...6:   return .sapling
        case 7...13:  return .tree
        default:      return .blooming
        }
    }

    var label: String {
        switch self {
        case .seedling: return "Seedling"
        case .sapling:  return "Sapling"
        case .tree:     return "Growing strong"
        case .blooming: return "In full bloom"
        }
    }
}

struct GrowthPlantView: View {
    let stage: PlantStage
    var size: CGFloat = 64

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let stemBaseY = h * 0.95
            let stemTopY = h * (stage == .seedling ? 0.55 : 0.18)

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.5, y: stemBaseY))
            stem.addLine(to: CGPoint(x: w * 0.5, y: stemTopY))
            context.stroke(stem, with: .color(.muckMoss), lineWidth: max(2, w * 0.035))

            // Leaves — count grows with stage
            let leafPairs = stage == .seedling ? 1 : stage == .sapling ? 2 : 3
            for i in 0..<leafPairs {
                let t = CGFloat(i + 1) / CGFloat(leafPairs + 1)
                let y = stemBaseY - (stemBaseY - stemTopY) * t
                let leafSize = w * (0.28 - CGFloat(i) * 0.02)
                drawLeaf(&context, at: CGPoint(x: w * 0.5 - leafSize * 0.6, y: y), size: leafSize, flip: false)
                drawLeaf(&context, at: CGPoint(x: w * 0.5 + leafSize * 0.6, y: y), size: leafSize, flip: true)
            }

            // Canopy for tree/blooming stages
            if stage == .tree || stage == .blooming {
                let canopyRect = CGRect(x: w * 0.22, y: h * 0.02, width: w * 0.56, height: w * 0.5)
                context.fill(Path(ellipseIn: canopyRect), with: .color(.muckFern))
            }

            // Blooms
            if stage == .blooming {
                let bloomPositions: [CGPoint] = [
                    CGPoint(x: w * 0.35, y: h * 0.18),
                    CGPoint(x: w * 0.62, y: h * 0.12),
                    CGPoint(x: w * 0.5, y: h * 0.28),
                ]
                for p in bloomPositions {
                    let r = w * 0.06
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.muckAmber))
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: stage)
    }

    private func drawLeaf(_ context: inout GraphicsContext, at point: CGPoint, size: CGFloat, flip: Bool) {
        var path = Path()
        let dx: CGFloat = flip ? 1 : -1
        path.move(to: point)
        path.addQuadCurve(
            to: CGPoint(x: point.x + dx * size, y: point.y - size * 0.15),
            control: CGPoint(x: point.x + dx * size * 0.5, y: point.y - size * 0.6)
        )
        path.addQuadCurve(
            to: point,
            control: CGPoint(x: point.x + dx * size * 0.5, y: point.y + size * 0.4)
        )
        context.fill(path, with: .color(.muckLime))
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        ForEach(PlantStage.allCases, id: \.self) { stage in
            VStack {
                GrowthPlantView(stage: stage, size: 72)
                Text(stage.label).font(.muckCaption)
            }
        }
    }
    .padding()
    .background(Color.muckBg)
}
