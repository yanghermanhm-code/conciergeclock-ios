// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/AnimatedShieldMark.swift).
// geometry as ShieldNetworkMark — if FocusFound adopts it, keep both copies identical.

import SwiftUI

/// The shield mark drawn up to `progress` (0…1): nodes pop in one by one, then the edges
/// grow between them. At 1 it looks exactly like `ShieldNetworkMark`.
public struct AnimatedShieldMark: View {
    private let progress: Double
    private let style: ShieldNetworkMark.Style

    public init(progress: Double, style: ShieldNetworkMark.Style = .standard) {
        self.progress = min(max(progress, 0), 1)
        self.style = style
    }

    public var body: some View {
        Canvas { context, size in
            let box = BrandMarkGeometry.bounds
            let scale = min(size.width / box.width, size.height / box.height)
            let offset = CGPoint(
                x: (size.width - box.width * scale) / 2 - box.minX * scale,
                y: (size.height - box.height * scale) / 2 - box.minY * scale
            )
            func point(_ index: Int) -> CGPoint {
                let n = BrandMarkGeometry.nodes[index]
                return CGPoint(x: n.x * scale + offset.x, y: n.y * scale + offset.y)
            }

            // Edges grow during the second half.
            let edgePhase = min(max((progress - 0.45) / 0.55, 0), 1)
            let lineWidth = max(1, BrandMarkGeometry.lineWidth * scale)
            let edgeCount = Double(BrandMarkGeometry.edges.count)
            for (index, edge) in BrandMarkGeometry.edges.enumerated() {
                let start = Double(index) / edgeCount * 0.6
                let local = min(max((edgePhase - start) / 0.4, 0), 1)
                guard local > 0 else { continue }
                let from = point(edge.from)
                let to = point(edge.to)
                var path = Path()
                path.move(to: from)
                path.addLine(to: CGPoint(x: from.x + (to.x - from.x) * local, y: from.y + (to.y - from.y) * local))
                context.stroke(path, with: .color(color(for: edge.tone)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }

            // Nodes pop in (with a small overshoot) during the first 60%.
            let nodeCount = Double(BrandMarkGeometry.nodes.count)
            let radius = BrandMarkGeometry.nodeRadius * scale
            for (index, node) in BrandMarkGeometry.nodes.enumerated() {
                let start = Double(index) / nodeCount * 0.45
                let local = min(max((progress - start) / 0.15, 0), 1)
                guard local > 0 else { continue }
                let pop = local < 1 ? sin(local * .pi * 0.75) / sin(.pi * 0.75) : 1
                let r = radius * pop
                let center = point(index)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(color(for: node.tone))
                )
            }
        }
        .aspectRatio(BrandMarkGeometry.bounds.width / BrandMarkGeometry.bounds.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func color(for tone: BrandMarkGeometry.Tone) -> Color {
        switch style {
        case let .monochrome(color):
            return color
        case .standard, .onDark:
            switch tone {
            case .green: return Brand.green
            case .blue: return Brand.blue
            case .slate:
                if case .onDark = style { return Brand.slateLight }
                return Brand.slate
            }
        }
    }
}
