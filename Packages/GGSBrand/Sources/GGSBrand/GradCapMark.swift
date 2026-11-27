// New in GGSBrand (PrepPilot): the graduation-cap node mesh. Same drawing style as
// ShieldNetworkMark — if another app adopts it, keep every copy identical.

import SwiftUI

/// PrepPilot's signature mark: the Greater Good node-and-edge mesh shaped into a
/// mortarboard with a hanging tassel node. Drawn natively so it is sharp at any size and
/// needs no image assets. Geometry matches Design/preppilot-mark.svg.
public struct GradCapNetworkMark: View {
    private let style: ShieldNetworkMark.Style

    public init(style: ShieldNetworkMark.Style = .standard) {
        self.style = style
    }

    public var body: some View {
        GradCapCanvas(progress: 1, style: style)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "PrepPilot"))
            .accessibilityAddTraits(.isImage)
    }
}

/// The graduation-cap mark drawn up to `progress` (0…1): nodes pop in one by one, then the
/// edges connect them. At 1 it is the finished mark. Used by the launch animation.
public struct AnimatedGradCapMark: View {
    private let progress: Double
    private let style: ShieldNetworkMark.Style

    public init(progress: Double, style: ShieldNetworkMark.Style = .standard) {
        self.progress = min(max(progress, 0), 1)
        self.style = style
    }

    public var body: some View {
        GradCapCanvas(progress: progress, style: style)
            .accessibilityHidden(true)
    }
}

/// Draws the mesh up to `progress`; shared by the static and animated marks.
private struct GradCapCanvas: View {
    let progress: Double
    let style: ShieldNetworkMark.Style

    var body: some View {
        Canvas { context, size in
            let box = GradCapGeometry.bounds
            let scale = min(size.width / box.width, size.height / box.height)
            let offset = CGPoint(
                x: (size.width - box.width * scale) / 2 - box.minX * scale,
                y: (size.height - box.height * scale) / 2 - box.minY * scale
            )
            func point(_ index: Int) -> CGPoint {
                let node = GradCapGeometry.nodes[index]
                return CGPoint(x: node.x * scale + offset.x, y: node.y * scale + offset.y)
            }

            // Edges grow during the second half of the animation.
            let edgePhase = min(max((progress - 0.45) / 0.55, 0), 1)
            let lineWidth = max(1, GradCapGeometry.lineWidth * scale)
            let edgeCount = Double(GradCapGeometry.edges.count)
            for (index, edge) in GradCapGeometry.edges.enumerated() {
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
            let nodeCount = Double(GradCapGeometry.nodes.count)
            for (index, node) in GradCapGeometry.nodes.enumerated() {
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
        .aspectRatio(GradCapGeometry.bounds.width / GradCapGeometry.bounds.height, contentMode: .fit)
    }

    private func color(for tone: GradCapGeometry.Tone) -> Color {
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

/// Node/edge data shared by the in-app mark, the launch animation and the SVG design files.
enum GradCapGeometry {
    enum Tone { case green, blue, slate }
    struct Node { let x: CGFloat; let y: CGFloat; let tone: Tone; var radius: CGFloat = 17 }
    struct Edge { let from: Int; let to: Int; let tone: Tone }

    static let lineWidth: CGFloat = 9
    /// Node extents plus node radius.
    static let bounds = CGRect(x: 223, y: 283, width: 587, height: 349)

    // Board (diamond seen in perspective): 0 left, 1 back, 2 right, 3 front, 4 button,
    // 5–8 board mid-points. Cap band: 9–15. Tassel: 16 cord, 17 tassel end.
    static let nodes: [Node] = [
        Node(x: 240, y: 390, tone: .green), Node(x: 512, y: 300, tone: .green),
        Node(x: 784, y: 390, tone: .blue), Node(x: 512, y: 480, tone: .blue),
        Node(x: 512, y: 390, tone: .green, radius: 22),
        Node(x: 376, y: 345, tone: .green), Node(x: 648, y: 345, tone: .blue),
        Node(x: 376, y: 435, tone: .slate), Node(x: 648, y: 435, tone: .slate),
        Node(x: 410, y: 470, tone: .green), Node(x: 614, y: 470, tone: .blue),
        Node(x: 410, y: 580, tone: .green), Node(x: 512, y: 615, tone: .slate),
        Node(x: 614, y: 580, tone: .blue), Node(x: 461, y: 545, tone: .blue),
        Node(x: 563, y: 545, tone: .slate),
        Node(x: 784, y: 500, tone: .blue), Node(x: 784, y: 590, tone: .green, radius: 26),
    ]

    static let edges: [Edge] = [
        // Board outline
        Edge(from: 0, to: 5, tone: .green), Edge(from: 5, to: 1, tone: .green),
        Edge(from: 1, to: 6, tone: .blue), Edge(from: 6, to: 2, tone: .blue),
        Edge(from: 2, to: 8, tone: .slate), Edge(from: 8, to: 3, tone: .slate),
        Edge(from: 3, to: 7, tone: .slate), Edge(from: 7, to: 0, tone: .green),
        // Board mesh through the button
        Edge(from: 4, to: 5, tone: .green), Edge(from: 4, to: 6, tone: .blue),
        Edge(from: 4, to: 7, tone: .slate), Edge(from: 4, to: 8, tone: .slate),
        Edge(from: 4, to: 1, tone: .green), Edge(from: 4, to: 3, tone: .blue),
        Edge(from: 0, to: 4, tone: .green),
        // Cap band
        Edge(from: 7, to: 9, tone: .green), Edge(from: 8, to: 10, tone: .blue),
        Edge(from: 9, to: 11, tone: .green), Edge(from: 10, to: 13, tone: .blue),
        Edge(from: 11, to: 12, tone: .green), Edge(from: 12, to: 13, tone: .slate),
        Edge(from: 9, to: 14, tone: .blue), Edge(from: 14, to: 12, tone: .blue),
        Edge(from: 10, to: 15, tone: .slate), Edge(from: 15, to: 12, tone: .slate),
        Edge(from: 14, to: 15, tone: .slate), Edge(from: 3, to: 14, tone: .blue),
        Edge(from: 3, to: 15, tone: .slate), Edge(from: 11, to: 14, tone: .green),
        Edge(from: 13, to: 15, tone: .slate),
        // Tassel: cord from the button to the corner, then hanging down
        Edge(from: 4, to: 2, tone: .blue), Edge(from: 2, to: 16, tone: .blue),
        Edge(from: 16, to: 17, tone: .green),
    ]
}

/// The white badge with a green check that sits on the ring in the app icon and on the
/// PrepPilot progress ring ("you passed").
public struct CheckBadge: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(.white)
                Path { path in
                    path.move(to: CGPoint(x: side * 0.28, y: side * 0.52))
                    path.addLine(to: CGPoint(x: side * 0.44, y: side * 0.67))
                    path.addLine(to: CGPoint(x: side * 0.73, y: side * 0.36))
                }
                .stroke(Brand.green, style: StrokeStyle(lineWidth: side * 0.12, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview("Grad cap mark") {
    VStack(spacing: 32) {
        GradCapNetworkMark().frame(width: 220)
        GradCapNetworkMark(style: .onDark)
            .frame(width: 220)
            .padding()
            .background(Brand.navy)
        CheckBadge().frame(width: 40)
            .padding()
            .background(Brand.navy)
    }
    .padding()
}
