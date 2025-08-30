import SwiftUI
import PencilKit

struct ContentView: View {
    @StateObject private var strokeStore = StrokeStore()
    private let scorer: ScoringEngine = DefaultScoring()
    private let recommender: Recommender = HeuristicRecommender()
    @State private var lastMetrics: Metrics? = nil
    @State private var selectedTemplateId: String = DemoTemplates.curvesArc01.id
    @State private var lastRecommendation: Recommendation? = nil
    @State private var debugInfo: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var debugDetails: String = ""
    @State private var canvasKey = UUID()
    @State private var canvasSize: CGSize = .zero
    @State private var isAutoEvaluating = false

    var body: some View {
        VStack(spacing: 12) {
            // Template selector
            Picker("Exercício", selection: $selectedTemplateId) {
                ForEach(DemoTemplates.all, id: \.id) { tpl in
                    Text(tpl.id).tag(tpl.id)
                }
            }
            .pickerStyle(.segmented)

            // Canvas area - sem sobreposição
            GeometryReader { geo in
                ZStack {
                    // Canvas principal
                    CaptureView(store: strokeStore, template: DemoTemplates.byId(selectedTemplateId))
                        .id(canvasKey) // recria a view quando a key muda
                        .background(Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                    
                    // Template overlay como overlay separado
                    TemplateOverlay(template: DemoTemplates.byId(selectedTemplateId))
                        .allowsHitTesting(false) // Não interfere com o input
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
            }
            .frame(minHeight: 420)
            
            // ✅ NOVO: Indicador de % de conclusão
            if strokeStore.completionPercentage > 0 {
                HStack {
                    Text("Conclusão: \(Int(strokeStore.completionPercentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: strokeStore.completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 100)
                    
                    if strokeStore.completionPercentage > 0.95 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                Button("Limpar") { 
                    clearCanvas()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Spacer()
                
                Button("Avaliar") {
                    evaluateDrawing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(strokeStore.current.isEmpty)
                
                // ✅ NOVO: Indicador de avaliação automática
                if isAutoEvaluating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Avaliando...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            // Debug info
            if !debugInfo.isEmpty {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Debug details
            if !debugDetails.isEmpty {
                Text(debugDetails)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .multilineTextAlignment(.leading)
            }
            
            if let m = lastMetrics {
                MetricsView(m: m)
            }
            
            if let rec = lastRecommendation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sugestões: ") + Text(rec.nextTemplateIds.joined(separator: ", ")).font(.callout)
                    Text("Racional: ") + Text(rec.rationale).font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
            }
        }
        .padding()
        .onChange(of: selectedTemplateId) { _, newTemplateId in
            // Limpa automaticamente o canvas quando muda de template
            clearCanvas()
            debugInfo = "Mudou para: \(newTemplateId)"
        }
        .onAppear {
            // ✅ NOVO: Configura callback para avaliação automática
            setupAutoEvaluation()
        }
        .alert("Erro", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // ✅ NOVO: Configura callback para avaliação automática
    private func setupAutoEvaluation() {
        strokeStore.onAutoEvaluate = { [weak self] in
            self?.autoEvaluateDrawing()
        }
    }
    
    // ✅ NOVO: Função de avaliação automática
    private func autoEvaluateDrawing() {
        guard !strokeStore.current.isEmpty else { return }
        
        isAutoEvaluating = true
        debugInfo = "🔄 Avaliação automática ativada!"
        
        // Pequeno delay para feedback visual
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.evaluateDrawing()
            self.isAutoEvaluating = false
        }
    }
    
    private func clearCanvas() {
        strokeStore.reset()
        canvasKey = UUID() // força recriação do PKCanvasView para evitar artefatos
        lastMetrics = nil
        lastRecommendation = nil
        debugInfo = "Canvas limpo"
        debugDetails = ""
    }
    
    private func evaluateDrawing() {
        do {
            let tpl = DemoTemplates.byId(selectedTemplateId)
            
            // Validações de segurança
            guard !strokeStore.current.isEmpty else {
                throw ScoringError.noStrokes
            }
            
            guard strokeStore.current.count <= 10 else {
                throw ScoringError.tooManyStrokes
            }
            
            let m = scorer.computeMetrics(strokes: strokeStore.current, template: tpl, canvasSize: canvasSize)
            lastMetrics = m
            lastRecommendation = recommender.nextPlan(history: [], last: m)
            
            // Debug info básica
            let totalPoints = strokeStore.current.flatMap { $0.path }.count
            let completion = Int(strokeStore.completionPercentage * 100)
            debugInfo = "Strokes: \(strokeStore.current.count), Pontos: \(totalPoints), Conclusão: \(completion)%"
            
        } catch ScoringError.noStrokes {
            errorMessage = "Desenhe algo antes de avaliar"
            showingError = true
        } catch ScoringError.tooManyStrokes {
            errorMessage = "Muitos traços separados. Tente fazer um traço contínuo."
            showingError = true
        } catch {
            errorMessage = "Erro ao avaliar: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func calculateTemplateSize(_ polyline: [CGPoint]) -> CGFloat {
        guard polyline.count > 1 else { return 1.0 }
        
        var totalDistance: CGFloat = 0
        for i in 1..<polyline.count {
            totalDistance += hypot(polyline[i].x - polyline[i-1].x, polyline[i].y - polyline[i-1].y)
        }
        
        return max(10.0, totalDistance)
    }
}

// Erros personalizados para scoring
enum ScoringError: Error, LocalizedError {
    case noStrokes
    case tooManyStrokes
    
    var errorDescription: String? {
        switch self {
        case .noStrokes:
            return "Nenhum traço para avaliar"
        case .tooManyStrokes:
            return "Muitos traços separados"
        }
    }
}

struct MetricsView: View {
    let m: Metrics
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Precisão: \(m.precision, specifier: "%.3f")")
                .foregroundColor(m.precision > 0.7 ? .green : m.precision > 0.4 ? .orange : .red)
            Text("Velocidade média: \(m.speedMean, specifier: "%.2f")")
            Text("CV velocidade: \(m.speedCV, specifier: "%.2f")")
            Text("Fluência jerk: \(m.fluencyJerk, specifier: "%.2f")")
            Text("Micro-paradas: \(m.microstops)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
        .background(Color(white: 0.98))
    }
}

