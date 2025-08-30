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
        
        // 1) Penalidade por posição absoluta (não normalizada): mapeia template -> canvas
        let mappedTemplate = mapTemplateToCanvas(tpl, canvasSize: canvasSize, inset: 16)
        let offsetPenalty = centerOffsetPenalty(user: rawPoints, templateCanvas: mappedTemplate, canvasSize: canvasSize)
        let avgNearestCanvasDist = averageNearestDistance(user: rawPoints, templateCanvas: mappedTemplate)
        
        // 2) Similaridade de forma (normalizada): normaliza user -> espaço do template
        let normalizedUser = normalizeUserPoints(rawPoints, toMatch: tpl)
        let dtw = ScoringMath.dtwDistance(normalizedUser, tpl)
        let frechet = ScoringMath.frechetDistance(normalizedUser, tpl)
        
        // ✅ CORRIGIDO: Métricas de velocidade usando pontos normalizados (robustas a escala)
        let velocities = ScoringMath.velocities(normalizedUser)
        let vMean = ScoringMath.mean(velocities.map { abs($0) })
        let vCV = ScoringMath.coeffVar(velocities.map { abs($0) })
        let micro = ScoringMath.microStops(velocities)
        let jerk = ScoringMath.meanJerk(velocities)
        
        // ✅ CORRIGIDO: Precisão combinada: forma (DTW/Fréchet) e posição (offset/nearest)
        let precisionShape = precisionFromDistances(dtw: dtw, frechet: frechet, template: tpl)
        let precisionPosition = precisionFromPosition(offsetPenalty: offsetPenalty, avgNearest: avgNearestCanvasDist, canvasSize: canvasSize)
        
        // Peso maior para posição quando muito fora; caso contrário prioriza forma
        let finalPrecision = max(0.0, min(1.0, (precisionShape * 0.6) + (precisionPosition * 0.4)))
        
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
    
    // MARK: - Canvas-space helpers
    private func mapTemplateToCanvas(_ polyline: [CGPoint], canvasSize: CGSize, inset: CGFloat) -> [CGPoint] {
        guard !polyline.isEmpty else { return [] }
        let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset, dy: inset)
        let minX = polyline.map { $0.x }.min() ?? 0
        let maxX = polyline.map { $0.x }.max() ?? 1
        let minY = polyline.map { $0.y }.min() ?? 0
        let maxY = polyline.map { $0.y }.max() ?? 1
        let w = maxX - minX
        let h = maxY - minY
        let scale = min(rect.width / max(w, 1), rect.height / max(h, 1))
        let offsetX = rect.midX - (minX + w/2) * scale
        let offsetY = rect.midY - (minY + h/2) * scale
        return polyline.map { p in CGPoint(x: p.x * scale + offsetX, y: p.y * scale + offsetY) }
    }
    
    private func centerOffsetPenalty(user: [CGPoint], templateCanvas: [CGPoint], canvasSize: CGSize) -> CGFloat {
        guard !user.isEmpty, !templateCanvas.isEmpty else { return 1.0 }
        let uMinX = user.map { $0.x }.min() ?? 0
        let uMaxX = user.map { $0.x }.max() ?? 0
        let uMinY = user.map { $0.y }.min() ?? 0
        let uMaxY = user.map { $0.y }.max() ?? 0
        let tMinX = templateCanvas.map { $0.x }.min() ?? 0
        let tMaxX = templateCanvas.map { $0.x }.max() ?? 0
        let tMinY = templateCanvas.map { $0.y }.min() ?? 0
        let tMaxY = templateCanvas.map { $0.y }.max() ?? 0
        let uCenter = CGPoint(x: (uMinX + uMaxX)/2, y: (uMinY + uMaxY)/2)
        let tCenter = CGPoint(x: (tMinX + tMaxX)/2, y: (tMinY + tMaxY)/2)
        let dx = uCenter.x - tCenter.x
        let dy = uCenter.y - tCenter.y
        let dist = hypot(dx, dy)
        let diag = hypot(canvasSize.width, canvasSize.height)
        // Normaliza: 0 = alinhado, 1 = muito longe (>= 1/3 do diagonal)
        return min(1.0, dist / max(1.0, diag / 3.0))
    }
    
    private func averageNearestDistance(user: [CGPoint], templateCanvas: [CGPoint]) -> CGFloat {
        guard !user.isEmpty, !templateCanvas.isEmpty else { return .infinity }
        var total: CGFloat = 0
        for p in user {
            var best = CGFloat.infinity
            // Aproximação simples: menor distância para pontos do template
            for q in templateCanvas {
                let d = hypot(p.x - q.x, p.y - q.y)
                if d < best { best = d }
            }
            total += best
        }
        return total / CGFloat(user.count)
    }
    
    // MARK: - Template-space helpers (forma)
    private func normalizeUserPoints(_ user: [CGPoint], toMatch template: [CGPoint]) -> [CGPoint] {
        guard let uMinX = user.map({ $0.x }).min(),
              let uMaxX = user.map({ $0.x }).max(),
              let uMinY = user.map({ $0.y }).min(),
              let uMaxY = user.map({ $0.y }).max(),
              let tMinX = template.map({ $0.x }).min(),
              let tMaxX = template.map({ $0.x }).max(),
              let tMinY = template.map({ $0.y }).min(),
              let tMaxY = template.map({ $0.y }).max() else { return user }
        
        let uW = max(1, uMaxX - uMinX)
        let uH = max(1, uMaxY - uMinY)
        let tW = max(1, tMaxX - tMinX)
        let tH = max(1, tMaxY - tMinY)
        
        let scale = min(tW / uW, tH / uH)
        let uCenter = CGPoint(x: uMinX + uW/2, y: uMinY + uH/2)
        let tCenter = CGPoint(x: tMinX + tW/2, y: tMinY + tH/2)
        
        return user.map { p in
            let px = (p.x - uCenter.x) * scale + tCenter.x
            let py = (p.y - uCenter.y) * scale + tCenter.y
            return CGPoint(x: px, y: py)
        }
    }
    
    // ✅ CORRIGIDO: Função de precisão baseada em distâncias normalizadas
    private func precisionFromDistances(dtw: CGFloat, frechet: CGFloat, template: [CGPoint]) -> CGFloat {
        let templateSize = calculateTemplateSize(template)
        let normalizedDTW = min(1.0, dtw / templateSize)
        let normalizedFrechet = min(1.0, frechet / templateSize)
        let combinedDistance = (normalizedDTW * 0.7) + (normalizedFrechet * 0.3)
        let precision = max(0.0, 1.0 - combinedDistance)
        return precision.isNaN || precision.isInfinite ? 0.5 : precision
    }
    
    private func precisionFromPosition(offsetPenalty: CGFloat, avgNearest: CGFloat, canvasSize: CGSize) -> CGFloat {
        // avgNearest normalizado pelo menor lado do canvas
        let normNearest = min(1.0, avgNearest / max(1.0, min(canvasSize.width, canvasSize.height) / 4.0))
        // Combina penalidades: maior das duas impacta mais
        let combinedPenalty = max(offsetPenalty, normNearest)
        // Converte penalidade (0..1) para precisão (1..0)
        return max(0.0, 1.0 - combinedPenalty)
    }
    
    // ✅ CORRIGIDO: Cálculo de tamanho do template mais robusto
    private func calculateTemplateSize(_ polyline: [CGPoint]) -> CGFloat {
        guard polyline.count > 1 else { return 1.0 }
        var totalDistance: CGFloat = 0
        for i in 1..<polyline.count {
            totalDistance += hypot(polyline[i].x - polyline[i-1].x, polyline[i].y - polyline[i-1].y)
        }
        return max(10.0, totalDistance)
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
