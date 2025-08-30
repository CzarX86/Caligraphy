import SwiftUI

struct TemplateOverlay: View {
    let template: TemplateDef
    var strokeColor: Color = .blue.opacity(0.5)

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let rect = geo.frame(in: .local).insetBy(dx: 16, dy: 16)
                let pts = template.polyline
                guard !pts.isEmpty else { return }
                // Compute bounds
                let minX = pts.map { $0.x }.min() ?? 0
                let maxX = pts.map { $0.x }.max() ?? 1
                let minY = pts.map { $0.y }.min() ?? 0
                let maxY = pts.map { $0.y }.max() ?? 1
                let w = maxX - minX
                let h = maxY - minY
                let scale = min(rect.width / max(w, 1), rect.height / max(h, 1))
                let offsetX = rect.midX - (minX + w/2) * scale
                let offsetY = rect.midY - (minY + h/2) * scale

                func map(_ p: CGPoint) -> CGPoint {
                    CGPoint(x: p.x * scale + offsetX, y: p.y * scale + offsetY)
                }

                path.addLines(pts.map(map))
            }
            .strokedPath(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .fill(strokeColor)

            if let baseline = template.layout.baseline {
                Path { p in
                    let rect = geo.frame(in: .local).insetBy(dx: 16, dy: 16)
                    let pts = template.polyline
                    guard !pts.isEmpty else { return }
                    let minX = pts.map { $0.x }.min() ?? 0
                    let maxX = pts.map { $0.x }.max() ?? 1
                    let minY = pts.map { $0.y }.min() ?? 0
                    let maxY = pts.map { $0.y }.max() ?? 1
                    let w = maxX - minX
                    let h = maxY - minY
                    let scale = min(rect.width / max(w, 1), rect.height / max(h, 1))
                    let offsetX = rect.midX - (minX + w/2) * scale
                    let offsetY = rect.midY - (minY + h/2) * scale
                    func map(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x * scale + offsetX, y: q.y * scale + offsetY) }
                    p.move(to: map(baseline.start))
                    p.addLine(to: map(baseline.end))
                }
                .stroke(Color.green.opacity(0.4), style: .init(lineWidth: 2, dash: [6,6]))
            }
        }
        .allowsHitTesting(false)
    }
}
