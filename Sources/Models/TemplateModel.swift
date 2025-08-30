import Foundation
import CoreGraphics

public struct Line: Codable, Equatable {
    public var start: CGPoint
    public var end: CGPoint
    public init(start: CGPoint, end: CGPoint) { self.start = start; self.end = end }
}

public struct TemplateLayout: Codable {
    public var baseline: Line?
    public var noGoRects: [CGRect]
    public var targetGaps: [CGFloat]
}

public struct TemplateDef: Codable, Identifiable {
    public var id: String
    public var type: String // pattern | glyph | word
    public var polyline: [CGPoint]
    public var layout: TemplateLayout
    public var tolerance: CGFloat
    public var timeMs: Int
}
