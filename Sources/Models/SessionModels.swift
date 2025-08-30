import Foundation
import CoreGraphics

public struct DifficultyParams: Codable, Equatable {
    public var difficulty: CGFloat
    public var tolerance: CGFloat
    public var timeMs: Int
    public init(difficulty: CGFloat = 0.5, tolerance: CGFloat = 12, timeMs: Int = 8000) {
        self.difficulty = difficulty
        self.tolerance = tolerance
        self.timeMs = timeMs
    }
}

public struct Session: Codable {
    public var attempts: [Attempt]
    public var metricsAgg: Metrics
    
    public init(attempts: [Attempt], metricsAgg: Metrics) {
        self.attempts = attempts
        self.metricsAgg = metricsAgg
    }
}

public struct Recommendation: Codable {
    public let nextTemplateIds: [String]
    public let rationale: String
    public let params: DifficultyParams
    
    public init(nextTemplateIds: [String], rationale: String, params: DifficultyParams) {
        self.nextTemplateIds = nextTemplateIds
        self.rationale = rationale
        self.params = params
    }
}

public struct Metrics: Codable, Equatable {
    public var precision: CGFloat
    public var speedMean: CGFloat
    public var speedCV: CGFloat
    public var consistency: CGFloat
    public var spacing: CGFloat
    public var baseline: CGFloat
    public var planning: CGFloat
    public var fluencyJerk: CGFloat
    public var microstops: Int
    
    public init(
        precision: CGFloat,
        speedMean: CGFloat,
        speedCV: CGFloat,
        consistency: CGFloat,
        spacing: CGFloat,
        baseline: CGFloat,
        planning: CGFloat,
        fluencyJerk: CGFloat,
        microstops: Int
    ) {
        self.precision = precision
        self.speedMean = speedMean
        self.speedCV = speedCV
        self.consistency = consistency
        self.spacing = spacing
        self.baseline = baseline
        self.planning = planning
        self.fluencyJerk = fluencyJerk
        self.microstops = microstops
    }
}

