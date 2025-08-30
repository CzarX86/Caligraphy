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
            let acceleration_i = v[i] - v[i-1]
            let acceleration_im1 = v[i-1] - v[i-2]
            jerk.append(abs(acceleration_i - acceleration_im1))
        }
        return mean(jerk)
    }
    
    // ✅ CORRIGIDO: Valores mais seguros para evitar overflow
    static func inv(_ x: CGFloat) -> CGFloat { 
        // Para distâncias muito pequenas, retorna um valor alto (boa precisão)
        // Para distâncias grandes, retorna um valor baixo (baixa precisão)
        if x <= 0.001 {
            return 100.0 // ✅ Reduzido de 1000.0 para 100.0
        } else if x >= 100.0 {
            return 0.01 // Distância muito grande = baixa precisão
        } else {
            return 1.0 / x
        }
    }
    
    // ✅ CORRIGIDO: Normalização baseada em estatísticas reais
    static func normalize(_ x: CGFloat) -> CGFloat { 
        // Garante que sempre retorne um valor entre 0 e 1
        // Evita NaN e valores infinitos
        if x.isNaN || x.isInfinite {
            return 0.5
        }
        
        // Normalização baseada em percentis estatísticos
        if x >= 100.0 {
            return 0.95 // Alta precisão
        } else if x >= 50.0 {
            return 0.85 // Muito boa precisão
        } else if x >= 25.0 {
            return 0.75 // Boa precisão
        } else if x >= 10.0 {
            return 0.60 // Precisão média
        } else if x >= 5.0 {
            return 0.40 // Baixa precisão
        } else if x >= 1.0 {
            return 0.25 // Muito baixa precisão
        } else {
            return 0.10 // Extremamente baixa precisão
        }
    }
    
    // ✅ CORRIGIDO: Inicialização correta da matriz DP
    static func dtwDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let n = a.count, m = b.count
        guard n > 0 && m > 0 else { return 50.0 }
        
        var dp = Array(repeating: Array(repeating: CGFloat.infinity, count: m+1), count: n+1)
        dp[0][0] = 0
        
        // ✅ CORRIGIDO: Inicializar primeira linha e coluna
        for i in 1...n { dp[i][0] = CGFloat.infinity }
        for j in 1...m { dp[0][j] = CGFloat.infinity }
        
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
    
    // ✅ NOVO: Função para calcular % de conclusão do template
    static func completionPercentage(_ userPoints: [CGPoint], _ templatePoints: [CGPoint]) -> CGFloat {
        guard !userPoints.isEmpty && !templatePoints.isEmpty else { return 0.0 }
        
        // Calcula bounding box do template
        let tMinX = templatePoints.map { $0.x }.min() ?? 0
        let tMaxX = templatePoints.map { $0.x }.max() ?? 1
        let tMinY = templatePoints.map { $0.y }.min() ?? 0
        let tMaxY = templatePoints.map { $0.y }.max() ?? 1
        
        let templateWidth = tMaxX - tMinX
        let templateHeight = tMaxY - tMinY
        let templateArea = templateWidth * templateHeight
        
        guard templateArea > 0 else { return 0.0 }
        
        // Calcula bounding box do usuário
        let uMinX = userPoints.map { $0.x }.min() ?? 0
        let uMaxX = userPoints.map { $0.x }.max() ?? 0
        let uMinY = userPoints.map { $0.y }.min() ?? 0
        let uMaxY = userPoints.map { $0.y }.max() ?? 0
        
        let userWidth = uMaxX - uMinX
        let userHeight = uMaxY - uMinY
        let userArea = userWidth * userHeight
        
        // Calcula % de conclusão baseado na área coberta
        let completion = min(1.0, userArea / templateArea)
        
        return completion.isNaN || completion.isInfinite ? 0.0 : completion
    }
}

