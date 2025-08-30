import CoreGraphics

enum DemoTemplates {
    static let curvesArc01 = TemplateDef(
        id: "pattern/curves.arc.01",
        type: "pattern",
        polyline: [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 20), CGPoint(x: 80, y: 0), CGPoint(x: 120, y: -20), CGPoint(x: 160, y: 0)],
        layout: TemplateLayout(
            baseline: Line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 160, y: 0)),
            noGoRects: [],
            targetGaps: []
        ),
        tolerance: 12,
        timeMs: 8000
    )

    static let linesLong01 = TemplateDef(
        id: "pattern/lines.long.01",
        type: "pattern",
        polyline: [CGPoint(x: 0, y: 0), CGPoint(x: 180, y: 0)],
        layout: TemplateLayout(
            baseline: Line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 180, y: 0)),
            noGoRects: [],
            targetGaps: []
        ),
        tolerance: 10,
        timeMs: 6000
    )

    static let loops01 = TemplateDef(
        id: "pattern/loops.01",
        type: "pattern",
        polyline: [
            CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 30), CGPoint(x: 40, y: 0),
            CGPoint(x: 60, y: -30), CGPoint(x: 80, y: 0), CGPoint(x: 100, y: 30),
            CGPoint(x: 120, y: 0), CGPoint(x: 140, y: -30), CGPoint(x: 160, y: 0)
        ],
        layout: TemplateLayout(
            baseline: Line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 160, y: 0)),
            noGoRects: [],
            targetGaps: []
        ),
        tolerance: 14,
        timeMs: 9000
    )

    static let all: [TemplateDef] = [curvesArc01, linesLong01, loops01]

    static func byId(_ id: String) -> TemplateDef {
        return all.first(where: { $0.id == id }) ?? curvesArc01
    }
}
