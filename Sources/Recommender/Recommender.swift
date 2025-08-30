import Foundation
import CoreGraphics

protocol Recommender { func nextPlan(history: [Metrics], last: Metrics) -> Recommendation }

struct HeuristicRecommender: Recommender {
    func nextPlan(history: [Metrics], last: Metrics) -> Recommendation {
        var deficits: [(String, CGFloat)] = []
        deficits.append(("curves", 1 - last.precision))
        deficits.append(("speed_stability", last.speedCV))
        deficits.append(("fluency", last.fluencyJerk))
        deficits.append(("spacing", 1 - last.spacing))
        deficits.append(("baseline", 1 - last.baseline))
        deficits.sort { $0.1 > $1.1 }
        let top = deficits.prefix(3).map { $0.0 }
        let mapping: [String:[String]] = [
            "curves": ["pattern/curves.arc.01"],
            "speed_stability": ["pattern/lines.long.01"],
            "fluency": ["pattern/loops.01"],
            "spacing": ["word/mim"],
            "baseline": ["pattern/baseline.fade.01"]
        ]
        let ids = top.flatMap { mapping[$0] ?? [] }
        let params = DifficultyParams(difficulty: 0.5, tolerance: 12, timeMs: 8000)
        return Recommendation(nextTemplateIds: ids, rationale: "Foco em: \(top.joined(separator: ", "))", params: params)
    }
}
