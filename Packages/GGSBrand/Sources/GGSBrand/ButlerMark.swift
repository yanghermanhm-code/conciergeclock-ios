// New in GGSBrand (Concierge Clock): the butler node mesh. Same drawing style as
// ShieldNetworkMark and GradCapNetworkMark — if another app adopts it, keep every copy identical.
// Geometry: tools/butler_geometry.py in the Concierge Clock repository
// (`python3 tools/generate_icons.py --swift` prints the tables below).

import SwiftUI

public extension Brand {
    /// Concierge Clock's brass/gold (decoration only: marks, rings, the cloche).
    static let brass = Color(hex: 0xC9A44C)
    static let brassOnDark = Color(hex: 0xD9B65E)
    /// Concierge Clock's teal (decoration only).
    static let teal = Color(hex: 0x1FA3A0)
    static let tealOnDark = Color(hex: 0x36C2BC)
}

/// Concierge Clock's signature mark: the Greater Good node-and-edge mesh shaped into a butler
/// carrying a tray with a domed cloche. Drawn natively so it is sharp at any size and needs no
/// image assets. Geometry matches Design/conciergeclock-mark.svg.
public struct ButlerNetworkMark: View {
    private let style: ShieldNetworkMark.Style

    public init(style: ShieldNetworkMark.Style = .standard) {
        self.style = style
    }

    public var body: some View {
        ButlerCanvas(progress: 1, style: style)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Concierge Clock"))
            .accessibilityAddTraits(.isImage)
    }
}

/// The butler drawn up to `progress` (0…1): nodes pop in one by one, then the edges connect
/// them. At 1 it is the finished mark. Used by the launch animation.
public struct AnimatedButlerMark: View {
    private let progress: Double
    private let style: ShieldNetworkMark.Style

    public init(progress: Double, style: ShieldNetworkMark.Style = .standard) {
        self.progress = min(max(progress, 0), 1)
        self.style = style
    }

    public var body: some View {
        ButlerCanvas(progress: progress, style: style)
            .accessibilityHidden(true)
    }
}

/// Draws the mesh up to `progress`; shared by the static and animated marks.
private struct ButlerCanvas: View {
    let progress: Double
    let style: ShieldNetworkMark.Style

    var body: some View {
        Canvas { context, size in
            let box = ButlerGeometry.bounds
            let scale = min(size.width / box.width, size.height / box.height)
            let offset = CGPoint(
                x: (size.width - box.width * scale) / 2 - box.minX * scale,
                y: (size.height - box.height * scale) / 2 - box.minY * scale
            )
            func point(_ index: Int) -> CGPoint {
                let node = ButlerGeometry.nodes[index]
                return CGPoint(x: node.x * scale + offset.x, y: node.y * scale + offset.y)
            }

            // Edges grow during the second half of the animation.
            let edgePhase = min(max((progress - 0.45) / 0.55, 0), 1)
            let lineWidth = max(1, ButlerGeometry.lineWidth * scale)
            let edgeCount = Double(ButlerGeometry.edges.count)
            for (index, edge) in ButlerGeometry.edges.enumerated() {
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

            // Nodes pop in, with a small overshoot, during the first 60%.
            let nodeCount = Double(ButlerGeometry.nodes.count)
            for (index, node) in ButlerGeometry.nodes.enumerated() {
                let start = Double(index) / nodeCount * 0.45
                let local = min(max((progress - start) / 0.15, 0), 1)
                guard local > 0 else { continue }
                let pop = local < 1 ? sin(local * .pi * 0.75) / sin(.pi * 0.75) : 1
                let radius = node.radius * scale * pop
                let center = point(index)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color(for: node.tone))
                )
            }
        }
        .aspectRatio(ButlerGeometry.bounds.width / ButlerGeometry.bounds.height, contentMode: .fit)
    }

    private func color(for tone: ButlerGeometry.Tone) -> Color {
        switch style {
        case let .monochrome(color):
            return color
        case .standard:
            switch tone {
            case .brass: return Brand.brass
            case .teal: return Brand.teal
            case .slate: return Brand.slate
            }
        case .onDark:
            switch tone {
            case .brass: return Brand.brassOnDark
            case .teal: return Brand.tealOnDark
            case .slate: return Brand.slateLight
            }
        }
    }
}

/// Node/edge data shared by the in-app mark, the launch animation and the SVG design files.
enum ButlerGeometry {
    enum Tone { case brass, teal, slate }
    struct Node { let x: CGFloat; let y: CGFloat; let tone: Tone; var radius: CGFloat = 17 }
    struct Edge { let from: Int; let to: Int; let tone: Tone }

    static let lineWidth: CGFloat = 9
    /// Node extents plus node radius.
    static let bounds = CGRect(x: 273, y: 235, width: 540, height: 498)

    static let nodes: [Node] = [
        Node(x: 430, y: 252, tone: .teal),
        Node(x: 376, y: 282, tone: .teal),
        Node(x: 484, y: 282, tone: .teal),
        Node(x: 380, y: 346, tone: .teal),
        Node(x: 480, y: 346, tone: .teal),
        Node(x: 430, y: 380, tone: .teal),
        Node(x: 430, y: 314, tone: .slate, radius: 18),
        Node(x: 384, y: 420, tone: .brass, radius: 15),
        Node(x: 384, y: 462, tone: .brass, radius: 15),
        Node(x: 476, y: 420, tone: .brass, radius: 15),
        Node(x: 476, y: 462, tone: .brass, radius: 15),
        Node(x: 430, y: 441, tone: .brass, radius: 21),
        Node(x: 322, y: 478, tone: .slate),
        Node(x: 538, y: 478, tone: .slate),
        Node(x: 430, y: 560, tone: .teal, radius: 19),
        Node(x: 344, y: 626, tone: .slate),
        Node(x: 516, y: 626, tone: .slate),
        Node(x: 332, y: 716, tone: .slate),
        Node(x: 528, y: 716, tone: .slate),
        Node(x: 624, y: 540, tone: .slate),
        Node(x: 690, y: 476, tone: .teal),
        Node(x: 290, y: 572, tone: .slate),
        Node(x: 394, y: 606, tone: .slate, radius: 15),
        Node(x: 584, y: 448, tone: .brass),
        Node(x: 690, y: 448, tone: .brass),
        Node(x: 796, y: 448, tone: .brass),
        Node(x: 612, y: 448, tone: .brass, radius: 13),
        Node(x: 622, y: 409, tone: .brass, radius: 15),
        Node(x: 651, y: 380, tone: .brass, radius: 15),
        Node(x: 690, y: 370, tone: .brass, radius: 15),
        Node(x: 729, y: 380, tone: .brass, radius: 15),
        Node(x: 758, y: 409, tone: .brass, radius: 15),
        Node(x: 768, y: 448, tone: .brass, radius: 13),
        Node(x: 690, y: 336, tone: .brass, radius: 19),
    ]

    static let edges: [Edge] = [
        Edge(from: 0, to: 1, tone: .teal),
        Edge(from: 0, to: 2, tone: .teal),
        Edge(from: 1, to: 3, tone: .teal),
        Edge(from: 2, to: 4, tone: .teal),
        Edge(from: 3, to: 5, tone: .teal),
        Edge(from: 4, to: 5, tone: .teal),
        Edge(from: 6, to: 0, tone: .slate),
        Edge(from: 6, to: 3, tone: .slate),
        Edge(from: 6, to: 4, tone: .slate),
        Edge(from: 6, to: 5, tone: .slate),
        Edge(from: 5, to: 11, tone: .brass),
        Edge(from: 7, to: 8, tone: .brass),
        Edge(from: 7, to: 11, tone: .brass),
        Edge(from: 8, to: 11, tone: .brass),
        Edge(from: 9, to: 10, tone: .brass),
        Edge(from: 9, to: 11, tone: .brass),
        Edge(from: 10, to: 11, tone: .brass),
        Edge(from: 7, to: 12, tone: .slate),
        Edge(from: 9, to: 13, tone: .slate),
        Edge(from: 8, to: 14, tone: .teal),
        Edge(from: 10, to: 14, tone: .teal),
        Edge(from: 12, to: 14, tone: .slate),
        Edge(from: 13, to: 14, tone: .slate),
        Edge(from: 12, to: 15, tone: .slate),
        Edge(from: 13, to: 16, tone: .slate),
        Edge(from: 14, to: 15, tone: .slate),
        Edge(from: 14, to: 16, tone: .slate),
        Edge(from: 15, to: 16, tone: .slate),
        Edge(from: 15, to: 17, tone: .slate),
        Edge(from: 16, to: 18, tone: .slate),
        Edge(from: 14, to: 17, tone: .slate),
        Edge(from: 14, to: 18, tone: .slate),
        Edge(from: 13, to: 19, tone: .slate),
        Edge(from: 19, to: 20, tone: .teal),
        Edge(from: 20, to: 24, tone: .teal),
        Edge(from: 12, to: 21, tone: .slate),
        Edge(from: 21, to: 22, tone: .slate),
        Edge(from: 23, to: 26, tone: .brass),
        Edge(from: 26, to: 24, tone: .brass),
        Edge(from: 24, to: 32, tone: .brass),
        Edge(from: 32, to: 25, tone: .brass),
        Edge(from: 26, to: 27, tone: .brass),
        Edge(from: 27, to: 28, tone: .brass),
        Edge(from: 28, to: 29, tone: .brass),
        Edge(from: 29, to: 30, tone: .brass),
        Edge(from: 30, to: 31, tone: .brass),
        Edge(from: 31, to: 32, tone: .brass),
        Edge(from: 24, to: 28, tone: .brass),
        Edge(from: 24, to: 29, tone: .brass),
        Edge(from: 24, to: 30, tone: .brass),
        Edge(from: 29, to: 33, tone: .brass),
    ]
}

/// The white badge with a brass concierge bell that sits on the ring in the app icon.
public struct BellBadge: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let s = side * 0.58
            let cx = side / 2
            let cy = side / 2 + side * 0.04
            ZStack {
                Circle().fill(.white)
                Path { path in
                    // Dome: a half circle above the base, drawn as one cubic curve.
                    let base = cy + s * 0.18
                    path.move(to: CGPoint(x: cx - s * 0.52, y: base))
                    path.addCurve(
                        to: CGPoint(x: cx + s * 0.52, y: base),
                        control1: CGPoint(x: cx - s * 0.52, y: base - s * 0.69),
                        control2: CGPoint(x: cx + s * 0.52, y: base - s * 0.69)
                    )
                    path.closeSubpath()
                    // Knob
                    path.addEllipse(in: CGRect(x: cx - s * 0.10, y: cy - s * 0.50, width: s * 0.20, height: s * 0.20))
                }
                .fill(Brand.brass)
                Path { path in
                    path.move(to: CGPoint(x: cx - s * 0.66, y: cy + s * 0.30))
                    path.addLine(to: CGPoint(x: cx + s * 0.66, y: cy + s * 0.30))
                }
                .stroke(Brand.brass, style: StrokeStyle(lineWidth: s * 0.13, lineCap: .round))
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview("Butler mark") {
    VStack(spacing: 32) {
        ButlerNetworkMark().frame(width: 220)
        ButlerNetworkMark(style: .onDark)
            .frame(width: 220)
            .padding()
            .background(Brand.navy)
        BellBadge().frame(width: 40)
            .padding()
            .background(Brand.navy)
    }
    .padding()
}
