import Foundation
import CoreGraphics

public struct StrokeSample: Codable, Hashable {
    public let x: CGFloat
    public let y: CGFloat
    public let t: TimeInterval
    public let pressure: CGFloat
    public let altitude: CGFloat?
    public let azimuth: CGFloat?
}

public struct Stroke: Codable, Hashable {
    public var samples: [StrokeSample]
}

public struct Attempt: Identifiable, Codable {
    public var id = UUID()
    public var templateId: String
    public var strokes: [Stroke]
    public var durationMs: Int
    public var device: String?
}
