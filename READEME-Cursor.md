

# Caligraphy – Bootstrap no Cursor

> Cola este conteúdo em `README-Cursor.md` ou mantenha aqui mesmo. Siga os passos na ordem. O projeto usa SwiftUI + PencilKit. iOS/iPadOS 17+.

## Passo 0 — Ferramentas rápidas
1. Xcode atualizado.
2. `brew install xcodegen swiftlint`

## Passo 1 — Estrutura do projeto (XcodeGen)
Crie um arquivo `project.yml` na raiz com o conteúdo abaixo e rode `xcodegen generate`.

```yaml
name: Caligraphy
options:
  minimumXcodeGenVersion: 2.38.0
settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: 17.0
    SWIFT_VERSION: 5.9
packages: {}
targets:
  Caligraphy:
    type: application
    platform: iOS
    sources:
      - path: Sources
    resources:
      - path: Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.julio.Caligraphy
        DEVELOPMENT_TEAM: YOUR_TEAM_ID
        CODE_SIGN_STYLE: Automatic
        INFOPLIST_FILE: Sources/Info.plist
    postbuildScripts:
      - name: SwiftLint
        script: |
          if which swiftlint >/dev/null; then swiftlint; else echo "SwiftLint not installed"; fi
```

Crie as pastas:
```
Sources/
  App/
  UI/
  HandwritingKit/
  ScoringEngine/
  Recommender/
  Models/
Resources/
  Templates/
```

## Passo 2 — Arquivos fonte mínimos
Crie os arquivos conforme os blocos a seguir.

### `Sources/Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>Caligraphy</string>
  <key>UIApplicationSceneManifest</key><dict>
    <key>UIApplicationSupportsMultipleScenes</key><true/>
  </dict>
  <key>UISupportedInterfaceOrientations~ipad</key>
  <array><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationPortraitUpsideDown</string></array>
</dict></plist>
```

### `Sources/App/CaligraphyApp.swift`
```swift
import SwiftUI

@main
struct CaligraphyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### `Sources/Models/StrokeModels.swift`
```swift
import Foundation

public struct StrokeSample: Codable, Hashable {
    public let x: CGFloat
    public let y: CGFloat
    public let t: TimeInterval
    public let pressure: CGFloat
}

public struct Stroke: Codable, Hashable {
    public var samples: [StrokeSample]
}

public struct Attempt: Identifiable, Codable {
    public var id = UUID()
    public var templateId: String
    public var strokes: [Stroke]
    public var durationMs: Int
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
}
```

### `Sources/Models/TemplateModel.swift`
```swift
import Foundation
import CoreGraphics

public struct TemplateLayout: Codable {
    public var baseline: (CGPoint, CGPoint)?
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
```

### `Sources/HandwritingKit/CaptureView.swift`
```swift
import SwiftUI
import PencilKit

final class StrokeStore: ObservableObject {
    @Published var current: [PKStroke] = []
    func reset() { current = [] }
}

struct CaptureView: UIViewRepresentable {
    @ObservedObject var store: StrokeStore
    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.drawingPolicy = .anyInput
        v.tool = PKInkingTool(.pen, color: .label, width: 3)
        v.delegate = context.coordinator
        return v
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
    func makeCoordinator() -> Coord { Coord(store: store) }
    final class Coord: NSObject, PKCanvasViewDelegate {
        let store: StrokeStore
        init(store: StrokeStore) { self.store = store }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.current = canvasView.drawing.strokes
        }
    }
}
```

### `Sources/ScoringEngine/ScoringEngine.swift`
```swift
import CoreGraphics
import PencilKit

protocol ScoringEngine {
    func computeMetrics(strokes: [PKStroke], template: TemplateDef) -> Metrics
}

struct DefaultScoring: ScoringEngine {
    func computeMetrics(strokes: [PKStroke], template: TemplateDef) -> Metrics {
        let pts = flatten(strokes)
        let tpl = template.polyline
        let dtw = dtwDistance(pts, tpl)
        let frechet = frechetDistance(pts, tpl)
        let v = velocities(pts)
        let vMean = mean(v.map { abs($0) })
        let vCV = coeffVar(v.map { abs($0) })
        let micro = microStops(v)
        let jerk = meanJerk(v)
        // Placeholders simples 0..1 (menor distância = melhor)
        let precision = normalize(inv(dtw + frechet))
        let spacing: CGFloat = 0.5 // calcular quando houver palavras
        let baseline: CGFloat = 0.5 // idem
        let planning: CGFloat = 0.5 // idem
        let consistency: CGFloat = 0.5 // séries futuras
        return Metrics(
            precision: precision,
            speedMean: vMean,
            speedCV: vCV,
            consistency: consistency,
            spacing: spacing,
            baseline: baseline,
            planning: planning,
            fluencyJerk: jerk,
            microstops: micro
        )
    }
}

// Helpers numéricos minimalistas
private func flatten(_ strokes: [PKStroke]) -> [CGPoint] {
    strokes.flatMap { stroke in
        stroke.path.interpolatedPoints(by: .distance(2)).map { CGPoint(x: $0.location.x, y: $0.location.y) }
    }
}

private func velocities(_ pts: [CGPoint]) -> [CGFloat] {
    guard pts.count > 1 else { return [] }
    var v: [CGFloat] = []
    for i in 1..<pts.count {
        let d = hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
        v.append(d) // sem tempo real, usa passo espacial
    }
    return v
}

private func mean(_ x: [CGFloat]) -> CGFloat { x.isEmpty ? 0 : x.reduce(0,+)/CGFloat(x.count) }
private func std(_ x: [CGFloat]) -> CGFloat {
    let m = mean(x); let v = x.reduce(0) { $0 + (pow($1-m,2)) } / CGFloat(max(1, x.count-1)); return sqrt(v)
}
private func coeffVar(_ x: [CGFloat]) -> CGFloat { let m = mean(x); return m == 0 ? 0 : std(x)/m }
private func microStops(_ v: [CGFloat], thresh: CGFloat = 0.5, len: Int = 3) -> Int {
    var c = 0; var run = 0
    for s in v { if s < thresh { run += 1; if run == len { c += 1; run = 0 } } else { run = 0 } }
    return c
}
private func meanJerk(_ v: [CGFloat]) -> CGFloat {
    guard v.count > 2 else { return 0 }
    var j: [CGFloat] = []
    for i in 2..<v.count { j.append(abs((v[i]-v[i-1]) - (v[i-1]-v[i-2]))) }
    return mean(j)
}
private func inv(_ x: CGFloat) -> CGFloat { 1.0 / max(0.0001, x) }
private func normalize(_ x: CGFloat) -> CGFloat { min(1, max(0, x/(1+x))) }

// DTW discreto simples
private func dtwDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
    let n = a.count, m = b.count
    guard n>0 && m>0 else { return .infinity }
    var dp = Array(repeating: Array(repeating: CGFloat.infinity, count: m+1), count: n+1)
    dp[0][0] = 0
    for i in 1...n {
        for j in 1...m {
            let cost = hypot(a[i-1].x - b[j-1].x, a[i-1].y - b[j-1].y)
            dp[i][j] = cost + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
        }
    }
    return dp[n][m] / CGFloat(n+m)
}

// Fréchet discreto simples
private func frechetDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
    let n = a.count, m = b.count
    guard n>0 && m>0 else { return .infinity }
    var ca = Array(repeating: Array(repeating: CGFloat(-1), count: m), count: n)
    func c(_ i: Int, _ j: Int) -> CGFloat {
        if ca[i][j] > -1 { return ca[i][j] }
        let d = hypot(a[i].x - b[j].x, a[i].y - b[j].y)
        if i == 0 && j == 0 { ca[i][j] = d }
        else if i > 0 && j == 0 { ca[i][j] = max(c(i-1,0), d) }
        else if i == 0 && j > 0 { ca[i][j] = max(c(0,j-1), d) }
        else { ca[i][j] = max(min(c(i-1,j), c(i-1,j-1), c(i,j-1)), d) }
        return ca[i][j]
    }
    return c(n-1, m-1)
}
```

### `Sources/Recommender/Recommender.swift`
```swift
import Foundation

struct Recommendation { let templateIds: [String]; let rationale: String }

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
        return Recommendation(templateIds: ids, rationale: "Foco em: \(top.joined(separator: ", "))")
    }
}
```

### `Sources/UI/ContentView.swift`
```swift
import SwiftUI
import PencilKit

struct ContentView: View {
    @StateObject private var strokeStore = StrokeStore()
    private let scorer: ScoringEngine = DefaultScoring()
    private let recommender: Recommender = HeuristicRecommender()
    @State private var lastMetrics: Metrics? = nil

    var body: some View {
        VStack(spacing: 12) {
            CaptureView(store: strokeStore)
                .frame(minHeight: 400)
                .background(Color(white: 0.95))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
            HStack {
                Button("Limpar") { strokeStore.reset() }
                Spacer()
                Button("Avaliar") {
                    let tpl = DemoTemplates.curvesArc01
                    let m = scorer.computeMetrics(strokes: strokeStore.current, template: tpl)
                    lastMetrics = m
                }
            }
            .padding(.horizontal)
            if let m = lastMetrics {
                MetricsView(m: m)
            }
        }
        .padding()
    }
}

struct MetricsView: View {
    let m: Metrics
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Precisão: \(m.precision, specifier: "%.2f")")
            Text("Velocidade média: \(m.speedMean, specifier: "%.2f")")
            Text("CV velocidade: \(m.speedCV, specifier: "%.2f")")
            Text("Fluência jerk: \(m.fluencyJerk, specifier: "%.2f")")
            Text("Micro-paradas: \(m.microstops)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
    }
}
```

### `Sources/Models/DemoTemplates.swift`
```swift
import CoreGraphics

enum DemoTemplates {
    static let curvesArc01 = TemplateDef(
        id: "pattern/curves.arc.01",
        type: "pattern",
        polyline: [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 20), CGPoint(x: 80, y: 0), CGPoint(x: 120, y: -20), CGPoint(x: 160, y: 0)],
        layout: TemplateLayout(baseline: (CGPoint(x: 0, y: 0), CGPoint(x: 160, y: 0)), noGoRects: [], targetGaps: []),
        tolerance: 12,
        timeMs: 8000
    )
}
```

## Passo 3 — Rodar
1. `xcodegen generate`
2. Abra o `.xcodeproj` e selecione iPad como destino.
3. Build & Run. Use o botão **Avaliar** para obter métricas básicas.

## Passo 4 — Próximos incrementos no Cursor
- Implementar métricas de baseline, spacing e planning no `DefaultScoring`.
- Criar overlay de heatmap de erro por ponto.
- Adicionar persistência de `Attempt` com `FileManager` simples.
- Conectar `Recommender` após cada **Avaliar** para listar próximos exercícios.

## .cursor/rules (cole em `.cursor/rules`)
```
Você é um assistente de engenharia iOS. Gere código SwiftUI idiomático (Swift 5.9).
- Módulos: HandwritingKit, ScoringEngine, Recommender, Models, UI.
- Sem dependências externas sem aprovação. Use Foundation e PencilKit.
- Siga SOLID/DRY/KISS. Exponha APIs pequenas.
- Crie testes unitários quando solicitado.
```

## Notas
- Métricas atuais usam aproximações espaciais sem timestamp real. Quando possível, derive tempo por amostra via `PKStrokePoint` (`timeOffset`) para velocidade real.
- Para produção: normalizar e filtrar o traço (reamostragem por arco, low-pass), e persistir sessões.

