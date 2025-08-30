import SwiftUI
import PencilKit

final class StrokeStore: ObservableObject {
    @Published var current: [PKStroke] = []
    @Published var completionPercentage: CGFloat = 0.0
    private var canvasView: PKCanvasView?
    var onAutoEvaluate: (() -> Void)?
    
    func setCanvasView(_ view: PKCanvasView) {
        self.canvasView = view
    }
    
    func reset() { 
        // ✅ CORRIGIDO: Atualiza as propriedades primeiro, depois limpa o canvas
        DispatchQueue.main.async {
            self.current = []
            self.completionPercentage = 0.0
            // Limpa diretamente o canvas na main thread para garantir atualização visual imediata
            self.canvasView?.drawing = PKDrawing()
        }
    }
    
    // ✅ NOVO: Calcula % de conclusão e verifica se deve avaliar automaticamente
    func updateCompletionPercentage(template: TemplateDef, canvasSize: CGSize) {
        guard !current.isEmpty else { 
            DispatchQueue.main.async { self.completionPercentage = 0.0 }
            return 
        }
        
        let userPoints = current.flatMap { stroke in
            stroke.path.map { $0.location }
        }
        
        let completion = ScoringMath.completionPercentage(userPoints, template.polyline, canvasSize: canvasSize)
        
        // Atualiza na main e sinaliza auto-avaliação quando apropriado
        DispatchQueue.main.async {
            self.completionPercentage = completion
            if completion > 0.95 { self.onAutoEvaluate?() }
        }
    }
}

struct CaptureView: UIViewRepresentable {
    @ObservedObject var store: StrokeStore
    let template: TemplateDef
    let canvasSize: CGSize
    
    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.drawingPolicy = .anyInput
        v.tool = PKInkingTool(.pen, color: .label, width: 3)
        v.delegate = context.coordinator
        v.backgroundColor = .clear // Importante: fundo transparente
        
        // Registra o canvas no store
        store.setCanvasView(v)
        
        return v
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Se o store foi limpo mas a view ainda tem traços, force limpar
        if store.current.isEmpty && !uiView.drawing.strokes.isEmpty {
            uiView.drawing = PKDrawing()
        }
    }
    
    func makeCoordinator() -> Coord { 
        Coord(store: store, template: template, canvasSize: canvasSize) 
    }
    
    final class Coord: NSObject, PKCanvasViewDelegate {
        let store: StrokeStore
        let template: TemplateDef
        var canvasSize: CGSize
        
        init(store: StrokeStore, template: TemplateDef, canvasSize: CGSize) { 
            self.store = store 
            self.template = template
            self.canvasSize = canvasSize
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Sincroniza os strokes com o store
            store.current = canvasView.drawing.strokes
            
            // Atualiza % de conclusão sempre que o desenho muda
            store.updateCompletionPercentage(template: template, canvasSize: canvasSize)
        }
        
        // Detecta quando o pencil é levantado da tela
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // Pequeno delay para garantir que o último stroke foi processado
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.store.updateCompletionPercentage(template: self.template, canvasSize: self.canvasSize)
            }
        }
    }
}

