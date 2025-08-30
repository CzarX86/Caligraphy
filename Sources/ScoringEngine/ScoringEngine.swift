import CoreGraphics
import PencilKit

protocol ScoringEngine {
    func computeMetrics(strokes: [PKStroke], template: TemplateDef, canvasSize: CGSize) -> Metrics
}

struct DefaultScoring: ScoringEngine {
    func computeMetrics(strokes: [PKStroke], template: TemplateDef, canvasSize: CGSize) -> Metrics {
        // Validações de entrada
        guard !strokes.isEmpty else {
            return createDefaultMetrics()
        }
        
        // Combina todos os strokes em uma única sequência de pontos (espaço do canvas)
        let rawPoints = strokes.flatMap { stroke in
            stroke.path.map { $0.location }
        }
        
        guard !rawPoints.isEmpty else {
            return createDefaultMetrics()
        }
        
        let tpl = template.polyline
        

        

        
        // ✅ NOVO: Métricas de velocidade usando pontos originais (sem normalização)
        let velocities = ScoringMath.velocities(rawPoints)
        let vMean = ScoringMath.mean(velocities.map { abs($0) })
        let vCV = ScoringMath.coeffVar(velocities.map { abs($0) })
        let micro = ScoringMath.microStops(velocities)
        let jerk = ScoringMath.meanJerk(velocities)
        
        // ✅ NOVO: Sistema de precisão mais rigoroso e preciso
        let finalPrecision = ScoringMath.calculatePrecision(rawPoints, tpl, canvasSize: canvasSize)
        
        // ✅ CORRIGIDO: Validação robusta de valores
        let safeSpeedMean = vMean.isNaN || vMean.isInfinite ? 0.0 : vMean
        let safeSpeedCV = vCV.isNaN || vCV.isInfinite ? 0.0 : vCV
        let safeJerk = jerk.isNaN || jerk.isInfinite ? 0.0 : jerk
        
        return Metrics(
            precision: finalPrecision,
            speedMean: safeSpeedMean,
            speedCV: safeSpeedCV,
            consistency: 0.5,
            spacing: 0.5,
            baseline: 0.5,
            planning: 0.5,
            fluencyJerk: safeJerk,
            microstops: micro
        )
    }
    

    

    

    
    private func createDefaultMetrics() -> Metrics {
        return Metrics(
            precision: 0.0,
            speedMean: 0.0,
            speedCV: 0.0,
            consistency: 0.5,
            spacing: 0.5,
            baseline: 0.5,
            planning: 0.5,
            fluencyJerk: 0.0,
            microstops: 0
        )
    }
}
