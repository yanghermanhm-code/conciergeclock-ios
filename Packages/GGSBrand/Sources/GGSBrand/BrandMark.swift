// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/BrandMark.swift).

import SwiftUI

/// The Greater Good Software network-shield mark, drawn natively so it is sharp at any
/// size, adapts to dark mode, and needs no image assets. Geometry matches Design/*.svg.
public struct ShieldNetworkMark: View {
    public enum Style: Sendable {
        /// Green / blue / slate on light backgrounds.
        case standard
        /// Lighter slate for dark backgrounds.
        case onDark
        /// Single colour (e.g. for watermarks).
        case monochrome(Color)
    }

    private let style: Style

    public init(style: Style = .standard) {
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

            let lineWidth = max(1, BrandMarkGeometry.lineWidth * scale)
            for edge in BrandMarkGeometry.edges {
                var path = Path()
                path.move(to: point(edge.from))
                path.addLine(to: point(edge.to))
                context.stroke(path, with: .color(color(for: edge.tone)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }

            let radius = BrandMarkGeometry.nodeRadius * scale
            for (index, node) in BrandMarkGeometry.nodes.enumerated() {
                let center = point(index)
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color(for: node.tone)))
            }
        }
        .aspectRatio(BrandMarkGeometry.bounds.width / BrandMarkGeometry.bounds.height, contentMode: .fit)
        .accessibilityLabel("Greater Good Software logo")
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

/// Node/edge data shared by the in-app mark and the SVG design files.
enum BrandMarkGeometry {
    enum Tone { case green, blue, slate }
    struct Node { let x: CGFloat; let y: CGFloat; let tone: Tone }
    struct Edge { let from: Int; let to: Int; let tone: Tone }

    static let lineWidth: CGFloat = 9
    static let nodeRadius: CGFloat = 17
    /// Node extents plus node radius.
    static let bounds = CGRect(x: 336, y: 213, width: 353, height: 414)

    // Indices: 0 top, 1 tl, 2 tr, 3 il, 4 ir, 5 ml, 6 mr, 7 c, 8 l2, 9 c2, 10 c3, 11 r2, 12 bl, 13 br, 14 bot
    static let nodes: [Node] = [
        Node(x: 512, y: 232, tone: .green), Node(x: 355, y: 290, tone: .green), Node(x: 670, y: 290, tone: .blue),
        Node(x: 430, y: 340, tone: .green), Node(x: 595, y: 335, tone: .blue), Node(x: 355, y: 398, tone: .slate),
        Node(x: 668, y: 398, tone: .slate), Node(x: 512, y: 418, tone: .green), Node(x: 373, y: 473, tone: .green),
        Node(x: 457, y: 487, tone: .blue), Node(x: 572, y: 465, tone: .slate), Node(x: 650, y: 473, tone: .blue),
        Node(x: 423, y: 550, tone: .blue), Node(x: 600, y: 550, tone: .slate), Node(x: 512, y: 608, tone: .green),
    ]

    static let edges: [Edge] = [
        Edge(from: 0, to: 1, tone: .green), Edge(from: 0, to: 2, tone: .blue), Edge(from: 1, to: 5, tone: .green),
        Edge(from: 2, to: 6, tone: .blue), Edge(from: 0, to: 3, tone: .green), Edge(from: 0, to: 4, tone: .blue),
        Edge(from: 0, to: 7, tone: .green), Edge(from: 1, to: 3, tone: .green), Edge(from: 2, to: 4, tone: .blue),
        Edge(from: 3, to: 4, tone: .green), Edge(from: 3, to: 7, tone: .green), Edge(from: 4, to: 7, tone: .blue),
        Edge(from: 3, to: 5, tone: .slate), Edge(from: 4, to: 6, tone: .slate), Edge(from: 3, to: 8, tone: .green),
        Edge(from: 3, to: 14, tone: .green), Edge(from: 4, to: 10, tone: .blue), Edge(from: 4, to: 11, tone: .blue),
        Edge(from: 5, to: 8, tone: .green), Edge(from: 6, to: 11, tone: .slate), Edge(from: 5, to: 9, tone: .slate),
        Edge(from: 7, to: 9, tone: .blue), Edge(from: 7, to: 10, tone: .slate), Edge(from: 9, to: 10, tone: .slate),
        Edge(from: 10, to: 11, tone: .blue), Edge(from: 10, to: 6, tone: .slate), Edge(from: 8, to: 9, tone: .blue),
        Edge(from: 9, to: 12, tone: .blue), Edge(from: 9, to: 13, tone: .slate), Edge(from: 12, to: 14, tone: .blue),
        Edge(from: 10, to: 14, tone: .slate), Edge(from: 10, to: 13, tone: .slate), Edge(from: 13, to: 14, tone: .slate),
        Edge(from: 11, to: 13, tone: .slate), Edge(from: 8, to: 12, tone: .green),
    ]
}

/// Horizontal company lockup: mark + "GREATER / GOOD" + "— SOFTWARE —".
/// Text is live (not an image) so it stays crisp and follows dark mode.
public struct BrandLockup: View {
    @Environment(\.colorScheme) private var colorScheme
    private let height: CGFloat

    /// - Parameter height: overall height of the lockup in points.
    public init(height: CGFloat = 64) {
        self.height = height
    }

    public var body: some View {
        let isDark = colorScheme == .dark
        let wordColor = isDark ? Color(hex: 0xE8F1F5) : Brand.navy
        let subColor = isDark ? Color(hex: 0x9FB0BC) : Color(hex: 0x4F6170)
        let wordSize = height * 0.30
        HStack(alignment: .center, spacing: height * 0.18) {
            ShieldNetworkMark(style: isDark ? .onDark : .standard)
                .frame(height: height)
            VStack(alignment: .leading, spacing: 0) {
                Text("GREATER")
                Text("GOOD")
                HStack(spacing: height * 0.08) {
                    Rectangle().fill(wordColor).frame(width: height * 0.32, height: max(1, height * 0.018))
                    Text("SOFTWARE")
                        .font(.system(size: wordSize * 0.38, weight: .medium))
                        .tracking(wordSize * 0.17)
                        .foregroundStyle(subColor)
                        .fixedSize()
                    Rectangle().fill(wordColor).frame(width: height * 0.32, height: max(1, height * 0.018))
                }
                .padding(.top, height * 0.04)
            }
            .font(.system(size: wordSize, weight: .bold))
            .tracking(wordSize * 0.03)
            .foregroundStyle(wordColor)
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Greater Good Software")
    }
}

#Preview("Brand") {
    VStack(spacing: 32) {
        ShieldNetworkMark().frame(width: 120)
        BrandLockup(height: 72)
    }
    .padding()
}
