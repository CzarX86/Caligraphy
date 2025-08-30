import CoreGraphics
import Foundation
import PencilKit

struct ScoringMath {
    static func flatten(_ strokes: [PKStroke]) -> [CGPoint] {
        strokes.flatMap { stroke in
            stroke.path.map { $0.location }
        }
    }
    
    // ✅ CORRIGIDO: Agora calcula velocidade real (distância/tempo)
    static func velocities(_ pts: [CGPoint], _ timestamps: [TimeInterval]) -> [CGFloat] {
        guard pts.count > 1 && timestamps.count == pts.count else { return [] }
        var v: [CGFloat] = []
        v.reserveCapacity(pts.count - 1)
        for i in 1..<pts.count {
            let distance = hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
            let timeDelta = timestamps[i] - timestamps[i-1]
            let velocity = timeDelta > 0 ? distance / CGFloat(timeDelta) : 0
            v.append(velocity)
        }
        return v
    }
    
    // ✅ CORRIGIDO: Fallback para quando não há timestamps (usa distância espacial)
    static func velocities(_ pts: [CGPoint]) -> [CGFloat] {
        guard pts.count > 1 else { return [] }
        var v: [CGFloat] = []
        v.reserveCapacity(pts.count - 1)
        for i in 1..<pts.count {
            let distance = hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
            v.append(distance)
        }
        return v
    }
    
    static func mean(_ x: [CGFloat]) -> CGFloat { 
        x.isEmpty ? 0 : x.reduce(0,+)/CGFloat(x.count) 
    }
    
    static func std(_ x: [CGFloat]) -> CGFloat {
        let m = mean(x)
        guard x.count > 1 else { return 0 }
        let v = x.reduce(0) { $0 + pow($1 - m, 2) } / CGFloat(x.count - 1)
        return sqrt(v)
    }
    
    static func coeffVar(_ x: [CGFloat]) -> CGFloat { 
        let m = mean(x); return m == 0 ? 0 : std(x)/m 
    }
    
    static func microStops(_ v: [CGFloat], thresh: CGFloat = 0.5, len: Int = 3) -> Int {
        var count = 0, run = 0
        for speed in v { 
            if speed < thresh { 
                run += 1; 
                if run == len { count += 1; run = 0 } 
            } else { 
                run = 0 
            } 
        }
        return count
    }
    
    // ✅ CORRIGIDO: Fórmula correta para jerk (terceira derivada da posição)
    static func meanJerk(_ v: [CGFloat]) -> CGFloat {
        guard v.count > 2 else { return 0 }
        var jerk: [CGFloat] = []
        jerk.reserveCapacity(v.count - 2)
        for i in 2..<v.count { 
            // Jerk = aceleração[i] - aceleração[i-1]
            let accelerationI = v[i] - v[i-1]
            let accelerationIm1 = v[i-1] - v[i-2]
            jerk.append(abs(accelerationI - accelerationIm1))
        }
        return mean(jerk)
    }
    
    // ✅ NOVO: Sistema de scoring mais rigoroso e preciso
    static func calculatePrecision(_ userPoints: [CGPoint], _ templatePoints: [CGPoint], canvasSize: CGSize) -> CGFloat {
        guard !userPoints.isEmpty, !templatePoints.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return 0.0 }
        
        // 1. VALIDAÇÃO DE FORMA (sem normalização que "estica")
        let shapeScore = calculateShapeSimilarity(userPoints, templatePoints)
        
        // 2. VALIDAÇÃO DE POSIÇÃO (onde está no canvas)
        let positionScore = calculatePositionAccuracy(userPoints, templatePoints, canvasSize)
        
        // 3. VALIDAÇÃO DE PROPORÇÃO (tamanho relativo)
        let proportionScore = calculateProportionAccuracy(userPoints, templatePoints)
        
        // 4. VALIDAÇÃO DE ORIENTAÇÃO (direção geral)
        let orientationScore = calculateOrientationAccuracy(userPoints, templatePoints)
        
        // Combinação ponderada com pesos mais rigorosos
        let finalPrecision = (shapeScore * 0.4) + (positionScore * 0.3) + (proportionScore * 0.2) + (orientationScore * 0.1)
        
        return max(0.0, min(1.0, finalPrecision))
    }
    
    // ✅ NOVO: Similaridade de forma sem normalização
    private static func calculateShapeSimilarity(_ user: [CGPoint], _ template: [CGPoint]) -> CGFloat {
        // Usa DTW e Fréchet diretamente nos pontos originais
        let dtw = dtwDistance(user, template)
        let frechet = frechetDistance(user, template)
        
        // Thresholds mais rigorosos
        let maxAcceptableDTW = 20.0 // Era 50.0
        let maxAcceptableFrechet = 25.0 // Era 50.0
        
        let dtwScore = max(0.0, 1.0 - (dtw / maxAcceptableDTW))
        let frechetScore = max(0.0, 1.0 - (frechet / maxAcceptableFrechet))
        
        // Penalização severa para formas muito diferentes
        if dtw > maxAcceptableDTW * 1.5 || frechet > maxAcceptableFrechet * 1.5 {
            return 0.0
        }
        
        return (dtwScore * 0.6) + (frechetScore * 0.4)
    }
    
    // ✅ NOVO: Precisão de posição no canvas
    private static func calculatePositionAccuracy(_ user: [CGPoint], _ template: [CGPoint], _ canvasSize: CGSize) -> CGFloat {
        // Mapeia template para canvas
        let mappedTemplate = mapPolylineToCanvas(template, canvasSize: canvasSize, inset: 16)
        
        // Calcula centro dos traços
        let userCenter = calculateCenter(user)
        let templateCenter = calculateCenter(mappedTemplate)
        
        // Distância entre centros
        let centerDistance = hypot(userCenter.x - templateCenter.x, userCenter.y - templateCenter.y)
        let maxAcceptableDistance = min(canvasSize.width, canvasSize.height) * 0.15 // 15% do menor lado
        
        if centerDistance > maxAcceptableDistance * 2.0 {
            return 0.0 // Penalização severa
        }
        
        return max(0.0, 1.0 - (centerDistance / maxAcceptableDistance))
    }
    
    // ✅ NOVO: Precisão de proporção (tamanho relativo)
    private static func calculateProportionAccuracy(_ user: [CGPoint], _ template: [CGPoint]) -> CGFloat {
        let userBounds = calculateBoundingBox(user)
        let templateBounds = calculateBoundingBox(template)
        
        let userAspectRatio = userBounds.width / max(userBounds.height, 1.0)
        let templateAspectRatio = templateBounds.width / max(templateBounds.height, 1.0)
        
        let aspectRatioDiff = abs(userAspectRatio - templateAspectRatio)
        let maxAcceptableDiff = 0.5 // Diferença máxima de 50%
        
        if aspectRatioDiff > maxAcceptableDiff * 2.0 {
            return 0.0 // Penalização severa
        }
        
        return max(0.0, 1.0 - (aspectRatioDiff / maxAcceptableDiff))
    }
    
    // ✅ NOVO: Precisão de orientação (direção geral)
    private static func calculateOrientationAccuracy(_ user: [CGPoint], _ template: [CGPoint]) -> CGFloat {
        guard user.count > 1, template.count > 1 else { return 0.5 }
        
        // Calcula direção geral dos traços
        let userDirection = calculateMainDirection(user)
        let templateDirection = calculateMainDirection(template)
        
        let angleDiff = abs(userDirection - templateDirection)
        let maxAcceptableAngle = CGFloat.pi / 4 // 45 graus
        
        if angleDiff > maxAcceptableAngle * 2.0 {
            return 0.0 // Penalização severa
        }
        
        return max(0.0, 1.0 - (angleDiff / maxAcceptableAngle))
    }
    
    // ✅ NOVO: Helpers para cálculos de precisão
    private static func calculateCenter(_ points: [CGPoint]) -> CGPoint {
        let avgX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let avgY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: avgX, y: avgY)
    }
    
    private static func calculateBoundingBox(_ points: [CGPoint]) -> CGRect {
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private static func calculateMainDirection(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        
        var totalDX: CGFloat = 0
        var totalDY: CGFloat = 0
        
        for i in 1..<points.count {
            totalDX += points[i].x - points[i-1].x
            totalDY += points[i].y - points[i-1].y
        }
        
        return atan2(totalDY, totalDX)
    }
    
    // ✅ CORRIGIDO: Inicialização correta da matriz DP
    static func dtwDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let n = a.count, m = b.count
        guard n > 0 && m > 0 else { return 50.0 }
        
        var dp = Array(repeating: Array(repeating: CGFloat.infinity, count: m+1), count: n+1)
        dp[0][0] = 0
        for i in 1...n { dp[i][0] = .infinity }
        for j in 1...m { dp[0][j] = .infinity }
        for i in 1...n {
            for j in 1...m {
                let cost = hypot(a[i-1].x - b[j-1].x, a[i-1].y - b[j-1].y)
                dp[i][j] = cost + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
            }
        }
        let result = dp[n][m] / CGFloat(n+m)
        return result.isNaN || result.isInfinite ? 50.0 : result
    }
    
    // ✅ CORRIGIDO: Inicialização correta da matriz de cache
    static func frechetDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let n = a.count, m = b.count
        guard n > 0 && m > 0 else { return 50.0 }
        
        var ca = Array(repeating: Array(repeating: CGFloat(-1), count: m), count: n)
        
        func c(_ i: Int, _ j: Int) -> CGFloat {
            if ca[i][j] > -1 { return ca[i][j] }
            let d = hypot(a[i].x - b[j].x, a[i].y - b[j].y)
            if i == 0 && j == 0 { 
                ca[i][j] = d 
            } else if i > 0 && j == 0 { 
                ca[i][j] = max(c(i-1,0), d) 
            } else if i == 0 && j > 0 { 
                ca[i][j] = max(c(0,j-1), d) 
            } else { 
                ca[i][j] = max(min(c(i-1,j), c(i-1,j-1), c(i,j-1)), d) 
            }
            return ca[i][j]
        }
        let result = c(n-1, m-1)
        return result.isNaN || result.isInfinite ? 50.0 : result
    }
    
    // MARK: - Helpers de forma e mapeamento
    static func pathLength(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<pts.count { total += hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y) }
        return total
    }
    
    static func mapPolylineToCanvas(_ polyline: [CGPoint], canvasSize: CGSize, inset: CGFloat = 16) -> [CGPoint] {
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
    
    // ✅ NOVO: Conclusão baseada em cobertura de comprimento e aderência espacial
    static func completionPercentage(_ userPoints: [CGPoint], _ templatePoints: [CGPoint], canvasSize: CGSize) -> CGFloat {
        guard !userPoints.isEmpty, !templatePoints.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return 0.0 }
        
        // Mapeia template para o canvas (mesma lógica visual)
        let mappedTemplate = mapPolylineToCanvas(templatePoints, canvasSize: canvasSize, inset: 16)
        let userLength = pathLength(userPoints)
        let templateLength = max(1.0, pathLength(mappedTemplate))
        let coverage = min(1.0, userLength / templateLength)
        
        // Aderência: fração de pontos do usuário próximos ao template
        let tolerance = max(2.0, min(canvasSize.width, canvasSize.height) * 0.03) // ~3% do menor lado
        var nearCount = 0
        for p in userPoints {
            var best = CGFloat.infinity
            for q in mappedTemplate { // aproximação simples
                let d = hypot(p.x - q.x, p.y - q.y)
                if d < best { best = d }
                if best <= tolerance { break }
            }
            if best <= tolerance { nearCount += 1 }
        }
        let adherence = CGFloat(nearCount) / CGFloat(max(1, userPoints.count))
        
        // Combinação conservadora
        let completion = max(0.0, min(1.0, coverage * 0.6 + adherence * 0.4))
        return completion
    }
}
