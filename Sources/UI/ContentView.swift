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
    @State private var lockedCanvasHeight: CGFloat = 0
    @State private var showTutorial = true
    @State private var tutorialStep = 0

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            Group {
                if isLandscape {
                    // ✅ NOVO: Layout horizontal otimizado
                    HStack(spacing: 16) {
                        // Coluna esquerda: Controles e navegação
                        VStack(spacing: 16) {
                            // Barra de conclusão
                            if strokeStore.completionPercentage > 0 {
                                CompletionProgressBar(percentage: strokeStore.completionPercentage)
                                    .frame(height: 60)
                                    .background(Color(white: 0.98))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                            }
                            
                            // Navegação de templates
                            VStack(spacing: 12) {
                                HStack {
                                    Button(action: previousTemplate) {
                                        Image(systemName: "chevron.left.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(selectedTemplateId == DemoTemplates.all.first?.id)
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        Text("Template Atual")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(templateDisplayName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: nextTemplate) {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(selectedTemplateId == DemoTemplates.all.last?.id)
                                }
                                
                                // Botões de ação
                                HStack {
                                    Button("Limpar") { 
                                        clearCanvas()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    
                                    Button("Avaliar") {
                                        evaluateDrawing()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(strokeStore.current.isEmpty)
                                }
                            }
                            .padding()
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))
                            
                            Spacer()
                            
                            // Métricas e recomendações
                            VStack(spacing: 12) {
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
                        }
                        .frame(width: 280)
                        
                        // Coluna direita: Canvas principal
                        VStack(spacing: 12) {
                            // Debug info
                            if !debugInfo.isEmpty {
                                Text(debugInfo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            if !debugDetails.isEmpty {
                                Text(debugDetails)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            // Canvas area
                            GeometryReader { geo in
                                ZStack {
                                    // Canvas principal
                                    CaptureView(store: strokeStore, template: DemoTemplates.byId(selectedTemplateId), canvasSize: geo.size)
                                        .id(canvasKey)
                                        .background(Color(white: 0.95))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                                    
                                    // Template overlay
                                    TemplateOverlay(template: DemoTemplates.byId(selectedTemplateId))
                                        .allowsHitTesting(false)
                                    
                                    // Tutorial overlay
                                    if showTutorial {
                                        TutorialOverlay(
                                            step: tutorialStep,
                                            onComplete: { showTutorial = false }
                                        )
                                    }
                                }
                                .onAppear {
                                    if lockedCanvasHeight == 0 {
                                        lockedCanvasHeight = geo.size.height
                                    }
                                    canvasSize = geo.size
                                }
                                .onChange(of: geo.size) { _, newSize in
                                    if lockedCanvasHeight == 0 { canvasSize = newSize }
                                }
                                // ✅ NOVO: Swipe com 2 dedos diretamente sobre o canvas
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 50)
                                        .onEnded { value in
                                            // Só ativa se for um gesto rápido (indicando múltiplos dedos)
                                            let velocity = abs(value.velocity.width)
                                            if velocity > 300 { // Velocidade alta indica múltiplos dedos
                                                if value.translation.width > 0 {
                                                    // Swipe direita com 2 dedos -> template anterior
                                                    previousTemplate()
                                                } else if value.translation.width < 0 {
                                                    // Swipe esquerda com 2 dedos -> próximo template
                                                    nextTemplate()
                                                }
                                            }
                                            }
                                        )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding()
                    
                } else {
                    // ✅ NOVO: Layout vertical otimizado
                    VStack(spacing: 0) {
                        // Barra de conclusão
                        if strokeStore.completionPercentage > 0 {
                            CompletionProgressBar(percentage: strokeStore.completionPercentage)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .background(Color(white: 0.98))
                                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                        }
                        
                        VStack(spacing: 12) {
                            // Navegação de templates
                            HStack {
                                Button(action: previousTemplate) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .disabled(selectedTemplateId == DemoTemplates.all.first?.id)
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text("Template Atual")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(templateDisplayName)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Button(action: nextTemplate) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .disabled(selectedTemplateId == DemoTemplates.all.last?.id)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))
                            
                            // Canvas area
                            GeometryReader { geo in
                                ZStack {
                                    CaptureView(store: strokeStore, template: DemoTemplates.byId(selectedTemplateId), canvasSize: geo.size)
                                        .id(canvasKey)
                                        .background(Color(white: 0.95))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                                    
                                    TemplateOverlay(template: DemoTemplates.byId(selectedTemplateId))
                                        .allowsHitTesting(false)
                                    
                                    if showTutorial {
                                        TutorialOverlay(
                                            step: tutorialStep,
                                            onComplete: { showTutorial = false }
                                        )
                                    }
                                }
                                .onAppear {
                                    if lockedCanvasHeight == 0 {
                                        lockedCanvasHeight = geo.size.height
                                    }
                                    canvasSize = geo.size
                                }
                                .onChange(of: geo.size) { _, newSize in
                                    if lockedCanvasHeight == 0 { canvasSize = newSize }
                                }
                                // ✅ NOVO: Swipe com 2 dedos diretamente sobre o canvas
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 50)
                                        .onEnded { value in
                                            // Só ativa se for um gesto rápido (indicando múltiplos dedos)
                                            let velocity = abs(value.velocity.width)
                                            if velocity > 300 { // Velocidade alta indica múltiplos dedos
                                                if value.translation.width > 0 {
                                                    // Swipe direita com 2 dedos -> template anterior
                                                    previousTemplate()
                                                } else if value.translation.width < 0 {
                                                    // Swipe esquerda com 2 dedos -> próximo template
                                                    nextTemplate()
                                                }
                                            }
                                        }
                                )
                            }
                            .frame(height: max(lockedCanvasHeight, 420))
                            
                            // Botões de ação
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
                            
                            if !debugDetails.isEmpty {
                                Text(debugDetails)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            // Métricas e recomendações
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
                    }
                }
            }
        }
        

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
    
    // ✅ NOVO: Nome de exibição amigável para o template atual
    private var templateDisplayName: String {
        switch selectedTemplateId {
        case DemoTemplates.curvesArc01.id:
            return "Curvas em Arco"
        case DemoTemplates.linesLong01.id:
            return "Linha Reta"
        case DemoTemplates.loops01.id:
            return "Padrão de Loops"
        default:
            return "Exercício"
        }
    }
    
    // ✅ NOVO: Navegação para template anterior
    private func previousTemplate() {
        guard let currentIndex = DemoTemplates.all.firstIndex(where: { $0.id == selectedTemplateId }),
              currentIndex > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTemplateId = DemoTemplates.all[currentIndex - 1].id
        }
    }
    
    // ✅ NOVO: Navegação para próximo template
    private func nextTemplate() {
        guard let currentIndex = DemoTemplates.all.firstIndex(where: { $0.id == selectedTemplateId }),
              currentIndex < DemoTemplates.all.count - 1 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTemplateId = DemoTemplates.all[currentIndex + 1].id
        }
    }
    
    // ✅ NOVO: Configura callback para avaliação automática
    private func setupAutoEvaluation() {
        strokeStore.onAutoEvaluate = {
            self.autoEvaluateDrawing()
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

// ✅ NOVO: Componente de barra de progresso dinâmica
struct CompletionProgressBar: View {
    let percentage: CGFloat
    @State private var animatedPercentage: CGFloat = 0
    @State private var isAnimating = false
    @State private var showCelebration = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Conclusão do Template")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(Int(percentage * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(progressColor)
                    
                    // ✅ NOVO: Ícone de status dinâmico
                    Image(systemName: statusIcon)
                        .foregroundColor(progressColor)
                        .scaleEffect(showCelebration ? 1.3 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)
                }
            }
            
            ZStack(alignment: .leading) {
                // Barra de fundo com gradiente sutil
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.9), Color(white: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Barra de progresso com gradiente animado
                RoundedRectangle(cornerRadius: 12)
                    .fill(progressGradient)
                    .frame(width: max(0, animatedPercentage) * UIScreen.main.bounds.width * 0.9, height: 16)
                    .animation(.easeInOut(duration: 0.4), value: animatedPercentage)
                    .overlay(
                        // ✅ NOVO: Efeito de brilho quando > 95%
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, animatedPercentage) * UIScreen.main.bounds.width * 0.9, height: 16)
                            .opacity(percentage >= 0.95 ? 0.8 : 0.0)
                            .animation(.easeInOut(duration: 0.6), value: percentage)
                    )
                
                // Indicador de status (bolinha) com animações
                Circle()
                    .fill(progressColor)
                    .frame(width: 20, height: 20)
                    .offset(x: max(0, animatedPercentage) * UIScreen.main.bounds.width * 0.9 - 10)
                    .animation(.easeInOut(duration: 0.4), value: animatedPercentage)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .scaleEffect(isAnimating ? 1.4 : 1.0)
                            .opacity(isAnimating ? 0.6 : 0.0)
                    )
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // ✅ NOVO: Partículas de celebração quando > 95%
                if showCelebration {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(progressColor)
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat.random(in: -20...20),
                                y: CGFloat.random(in: -10...10)
                            )
                            .opacity(0.8)
                            .scaleEffect(0.5)
                            .animation(
                                .easeOut(duration: 1.0)
                                .delay(Double(index) * 0.1),
                                value: showCelebration
                            )
                    }
                }
            }
            
            // ✅ NOVO: Texto de status dinâmico
            Text(statusText)
                .font(.caption)
                .foregroundColor(progressColor)
                .fontWeight(.medium)
                .opacity(0.8)
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .onAppear {
            animateProgress()
        }
        .onChange(of: percentage) { _, newPercentage in
            animateProgress()
        }
    }
    
    private var progressColor: Color {
        if percentage >= 0.95 {
            return .green
        } else if percentage >= 0.7 {
            return .yellow
        } else if percentage >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusIcon: String {
        if percentage >= 0.95 {
            return "checkmark.circle.fill"
        } else if percentage >= 0.7 {
            return "arrow.up.circle.fill"
        } else if percentage >= 0.4 {
            return "minus.circle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusText: String {
        if percentage >= 0.95 {
            return "Perfeito! 🎉 Avaliação automática ativada"
        } else if percentage >= 0.7 {
            return "Quase lá! Continue desenhando"
        } else if percentage >= 0.4 {
            return "Em progresso... Você está no caminho certo"
        } else {
            return "Iniciando... Comece a desenhar o template"
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                progressColor.opacity(0.6),
                progressColor,
                progressColor.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func animateProgress() {
        withAnimation(.easeInOut(duration: 0.6)) {
            animatedPercentage = percentage
        }
        
        // Ativa animação da bolinha quando > 95%
        if percentage >= 0.95 {
            isAnimating = true
            // ✅ NOVO: Ativa celebração com delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showCelebration = true
                }
            }
        } else {
            isAnimating = false
            showCelebration = false
        }
    }
}

// ✅ NOVO: Overlay de tutorial com animações
struct TutorialOverlay: View {
    let step: Int
    let onComplete: () -> Void
    @State private var showArrows = false
    @State private var showTouchPoints = false
    @State private var pulseOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Fundo semi-transparente
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Título do tutorial
                Text("Bem-vindo ao Caligraphy! ✨")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Instruções
                VStack(spacing: 20) {
                    Text("Aprenda a navegar entre os exercícios:")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // ✅ NOVO: Demonstração de gestos
                    HStack(spacing: 40) {
                        // Swipe esquerda
                        VStack(spacing: 12) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(showArrows ? -15 : 0))
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showArrows)
                            
                            Text("Swipe ←")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Próximo exercício")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Swipe direita
                        VStack(spacing: 12) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                                .rotationEffect(.degrees(showArrows ? 15 : 0))
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showArrows)
                            
                            Text("Swipe →")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Exercício anterior")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // ✅ NOVO: Pontos de toque animados
                    HStack(spacing: 20) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                                .scaleEffect(showTouchPoints ? 1.5 : 1.0)
                                .opacity(pulseOpacity)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: showTouchPoints
                                )
                        }
                    }
                    .padding(.top, 20)
                }
                
                // Botão para começar
                Button("Começar a Treinar! 🚀") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        onComplete()
                    }
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                .scaleEffect(pulseOpacity > 0.5 ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseOpacity)
            }
            .padding(40)
        }
        .onAppear {
            startTutorialAnimation()
        }
    }
    
    private func startTutorialAnimation() {
        // Sequência de animações
        withAnimation(.easeInOut(duration: 0.8)) {
            showArrows = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                showTouchPoints = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                pulseOpacity = 1.0
            }
        }
    }
}

