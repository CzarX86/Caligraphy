# App iPad – Treino de Caligrafia Adaptativo (TDAH-friendly)

## Objetivo
Treinar precisão, velocidade, organização espacial e fluidez da escrita com Apple Pencil. O app mede progresso e recomenda exercícios para atacar fraquezas.

## Métricas‑chave
- Precisão do traço vs template.
- Velocidade e estabilidade do traço.
- Consistência entre repetições.
- Organização espacial: margens, baseline, espaçamento intra/inter‑palavra.
- Fluidez: continuidade do traço, número de microparadas.

## Requisitos
- iPadOS 17+. Apple Pencil. SwiftUI + PencilKit.
- Offline‑first. Sincronização opcional via iCloud.
- Exportação de relatório em PDF.
- Acessibilidade: fontes maiores, alto contraste, feedback auditivo opcional.

## Arquitetura (módulos)
- HandwritingKit: captura, normalização e features do traço.
- TemplateKit: templates (letras, palavras, padrões, layouts espaciais).
- ScoringEngine: algoritmos de distância e métricas.
- Recommender: regras e ML leve para plano adaptativo.
- Content: pacotes de exercícios por nível.
- Storage: CoreData/SQLite + Files para assets SVG/TTF.
- UI: SwiftUI + overlays Metal para heatmaps.

## Modelo de dados (resumo)
- StrokeSample { x:Float, y:Float, t:Time, pressure:Float, altitude:Float, azimuth:Float }
- Stroke { samples:[StrokeSample] }
- Attempt { id, templateId, strokes:[Stroke], durationMs:Int, device:String }
- Metrics { precision:Float, speed:Float, consistency:Float, spacing:Float, baseline:Float, planning:Float, fluency:Float }
- Session { attempts:[Attempt], metricsAgg:Metrics }
- Recommendation { nextTemplateIds:[String], rationale:String, params:{ difficulty:Float, tolerances:{...} } }

Obs.: No código, usamos CGFloat onde apropriado (CoreGraphics).

## Normalização do traço (pseudocódigo)
```
function preprocess(strokes):
  points = merge(strokes)
  points = removeOutliers(points, z=3)
  points = resampleByArcLength(points, step=1.0px)
  points = lowpassFilter(points, alpha=0.2)
  velocities = diff(points)/diff(time)
  return {points, velocities}
```

## Métrica de precisão vs template
Representação do template em polilinhas (templatePts). Distância: DTW euclidiana + distância Fréchet para robustez.
```
function precision(points, templatePts):
  d_dtw = DTW(points, templatePts, cost=L2)
  d_frechet = discreteFrechet(points, templatePts)
  return normalize( w1*d_dtw + w2*d_frechet )
```

## Velocidade e fluidez
```
function speedMetrics(vel):
  v_mean = mean(|vel|)
  v_cv = stdev(|vel|)/v_mean
  microstops = countSegments(|vel|<τ_v for > τ_t)
  jerk = mean(|diff(vel)/diff(t)|)
  return {v_mean, v_cv, microstops, jerk}
```

## Consistência entre repetições
```
function consistency(reps):
  pairwise = [precision(rep_i, rep_j) for all i<j]
  return 1 - stdev(pairwise)/mean(pairwise)
```

## Organização espacial
- Baseline: regressão da linha média do template; distância média assinada do traço à baseline.
- Margens: interseção do traço com áreas proibidas.
- Espaçamento: distância entre bounding boxes de letras/palavras alvo vs real.
```
function spatialMetrics(points, layout):
  baseline_dev = meanSignedDistanceToLine(points, layout.baseline)
  margin_viol = areaCrossed(points, layout.noGoAreas) / totalLen(points)
  spacing_err = mse(realGaps, targetGaps(layout))
  return {baseline: f1(baseline_dev), planning: f2(margin_viol), spacing: f3(spacing_err)}
```

## Score composto
```
function finalScore(m):
  // todos normalizados 0..1, maior é melhor
  return clamp(
    wP*m.precision +
    wS*inv(m.speed.cv) +
    wC*m.consistency +
    wB*inv(m.baseline) +
    wG*inv(m.spacing) +
    wL*inv(m.planning) +
    wF*inv(m.fluency.jerk+microstops), 0, 1)
```

## Recomendador adaptativo
Heurístico + ML leve (opcional gradient boosting).
```
function recommend(history, lastMetrics):
  deficits = rankDesc({
    "curves": inv(lastMetrics.precision on curvedSegments),
    "spacing": inv(lastMetrics.spacing),
    "baseline": inv(lastMetrics.baseline),
    "planning": inv(lastMetrics.planning),
    "fluency": inv(lastMetrics.fluency),
    "speed_stability": inv(lastMetrics.speed.cv),
    "consistency": inv(lastMetrics.consistency)
  })
  plan = []
  for d in top(deficits, k=2..3):
    plan += library.match(d, level=adaptiveLevel(history))
  // Ajustar tolerâncias e tempo
  params = tuneDifficulty(history, targetSuccess=0.75)
  return {nextTemplates: plan, params}
```

### Regras de mapeamento (exemplos)
- Déficit “curves” → arcos, círculos, espirais, letras “m n s e o”.
- “spacing” → caixas inter‑letras e inter‑palavras com “metrônomo de espaço”.
- “baseline” → linha fantasma com fade + penalidade por deriva.
- “planning” → blocos e margens com metas de ocupação do parágrafo.
- “fluency” → traços contínuos longos e redução de microstops.
- “speed_stability” → tarefas com tempo alvo e variação controlada.
- “consistency” → séries “3×” do mesmo padrão e intervalos espaçados.

## Geração de templates
- Fonte TTF/SVG livre → contorno → simplificação → polilinhas.
- Alternativa: templates desenhados à mão (SVG).
```
function glyphToTemplate(ttfGlyph):
  path = outline(ttfGlyph)
  path = simplifyDouglasPeucker(path, ε)
  poly = samplePath(path, step=1px)
  metadata = {baseline, xHeight, ascender, descender}
  return Template(poly, metadata)
```

## Feedback visual
- Heatmap de erro: intensidade = distância local ao template.
- Cores: verde baixo erro, vermelho alto.
- Overlays: baseline, margens, caixas de espaçamento.

## Fluxo do usuário
- Selecionar objetivo do dia ou aceitar sugestão do app.
- Treino curto 3–5 min com 2–3 exercícios.
- Feedback instantâneo + tela “Meta‑Plano‑Fazer‑Checar”.
- Plano seguinte gerado automaticamente.

## Níveis e progressão
- Nível 0: traços básicos e controle de tamanho.
- Nível 1: letras isoladas.
- Nível 2: sílabas/palavras curtas.
- Nível 3: frases dentro de caixa alvo.
- Nível 4: ditado cronometrado com layout de página.

## Conteúdo TDAH (espacial)
- Pautas dinâmicas com fade.
- Caixas de ocupação de linha/parágrafo.
- Exercícios de margens e alinhamento.
- Sessões curtas e metas objetivas.

## Persistência
- CoreData para Attempt, Metrics, Session.
- Arquivos JSON para templates; SVG/TTF em bundle.

## Telemetria (opt‑in)
- Evento de início/fim de tentativa.
- Métricas agregadas por sessão.
- Latência de render e crash logs.

## Privacidade
- Dados no dispositivo por padrão. iCloud opcional.
- Sem coleta de conteúdo escrito por padrão.

## Acessibilidade
- VoiceOver labels nos botões.
- Feedback háptico leve ao ultrapassar margem.
- Modo alto contraste.

## Riscos e mitigação
- Frustração ao comparar com fontes tipográficas → usar templates humanos e tolerâncias progressivas.
- Ruído de captura → filtros e reamostragem.
- Overfitting ao template → alternar variações e jitter controlado.

## Esqueleto Swift (assinaturas)
```swift
protocol StrokeCapture {
  func start()
  func stop() -> [Stroke]
}

struct Metrics {
  var precision: Float
  var speedCV: Float
  var consistency: Float
  var spacing: Float
  var baseline: Float
  var planning: Float
  var fluencyJerk: Float
  var microstops: Int
}

protocol ScoringEngine {
  func computeMetrics(strokes: [Stroke], template: Template, layout: Layout) -> Metrics
  func finalScore(_ m: Metrics) -> Float
}

protocol Recommender {
  func nextPlan(history: [Session], last: Metrics) -> Recommendation
}

struct Recommendation {
  let nextTemplateIds: [String]
  let rationale: String
  let params: DifficultyParams
}
```

## Algoritmos essenciais (pseudocódigo)
DTW
```
function DTW(A,B):
  n=|A|; m=|B|
  dp = matrix(n+1,m+1, +INF)
  dp[0][0]=0
  for i in 1..n:
    for j in 1..m:
      cost = L2(A[i], B[j])
      dp[i][j] = cost + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
  return dp[n][m]/(n+m)
```
Fréchet discreto
```
function discreteFrechet(A,B):
  ca = matrix(|A|,|B|, -1)
  return c(|A|-1, |B|-1)
function c(i,j):
  if ca[i][j] > -1 return ca[i][j]
  d = L2(A[i],B[j])
  if i==0 and j==0: ca[i][j]=d
  else if i>0 and j==0: ca[i][j]=max(c(i-1,0), d)
  else if i==0 and j>0: ca[i][j]=max(c(0,j-1), d)
  else: ca[i][j]=max(min(c(i-1,j), c(i-1,j-1), c(i,j-1)), d)
  return ca[i][j]
```
Baseline e espaçamento
```
function meanSignedDistanceToLine(points, line):
  return mean( signedDistance(p, line) for p in points )

function spacingErrors(bboxes, targetGaps):
  realGaps = gapsBetween(bboxes)
  return mse(realGaps, targetGaps)
```
Tuning de dificuldade
```
function tuneDifficulty(history, targetSuccess):
  p = movingAverage(successRate(last 5 sessions))
  if p > targetSuccess:
    decreaseTolerance(5-10%)
    increaseTimePressure(5%)
  else:
    increaseTolerance(10-15%)
    holdTimePressure()
  return params
```

## Templates de exercícios (exemplos JSON)
```json
{
  "id": "curves.arc.01",
  "type": "pattern",
  "polyline": [[0,0],[10,5],[20,0],[30,-5],[40,0]],
  "layout": {"baseline":[[0,0],[40,0]], "noGoAreas":[], "targetGaps":[]},
  "difficulty": {"tolerance": 12, "timeMs": 8000}
}
```
```json
{
  "id": "word.mim",
  "type": "word",
  "glyphs": ["m","i","m"],
  "layout": {"baseline":[[0,0],[180,0]], "xHeight": 24, "noGoAreas":[["leftMargin",0,0,10,200]]},
  "difficulty": {"tolerance": 10, "timeMs": 12000}
}
```

## Fluxo UI (rápido)
- Home: “Treino do dia” + botão “Escolher”.
- Exercício: canvas PencilKit + overlay heatmap + cronômetro.
- Feedback: métricas, heatmap, CO‑OP (Meta/Plano/Fazer/Checar).
- Progresso: gráfico por métrica e por nível.
- Config: fontes/templates, tolerâncias, acessibilidade, iCloud.

## Instrumentação mínima
- attempt_started, attempt_finished {templateId, durationMs, metrics}
- recommendation_accepted/overridden
- crash, latency_render_ms

## Licenças e conteúdo
- Usar fontes livres (Google Fonts, SIL OFL). Salvar metadados de licença.
- Para templates humanos, coletar consentimento e direitos.

## Testes
- Unit: DTW/Fréchet com formas sintéticas; baseline/spacing em casos de borda.
- Snapshot UI: overlays e heatmaps.
- Integração: pipeline completo em 10 templates.
- Performance: ≥ 60 fps em iPad de entrada.

## Roadmap (fases)
1. MVP: captura, métricas básicas, heurística de recomendação, 50 templates.
2. Espaço/TDAH: margens, baseline avançada, caixas e relatórios.
3. Fluidez: microstops, jerk, drills de continuidade.
4. ML leve: regressão para previsão de sucesso e ajuste dinâmico.
5. Conteúdo premium e relatórios para pais/professores.

## Arquitetura de pastas (sugestão)
```
/App
  /Sources
    /UI
    /HandwritingKit
    /TemplateKit
    /ScoringEngine
    /Recommender
    /Storage
    /Content
  /Resources
    /Templates/*.json
    /Fonts/*.ttf
    /SVG/*.svg
  /Tests
    /Unit
    /Integration
```

## Regras para o Cursor (.cursor/rules – resumo)
- Estilo: SOLID, DRY, KISS. Swift 5.9, SwiftUI, async/await.
- Não usar dependências externas sem aprovação. Priorizar Foundation/SwiftAlgorithms.
- Cobertura de testes mínima 80% nos engines.
- Documentar public APIs com docstrings concisas.

## Prompt base sugerido para gerar componentes
Você é um assistente de engenharia iOS. Gere código SwiftUI idiomático.
- Módulos: HandwritingKit, TemplateKit, ScoringEngine, Recommender, Storage.
- Exponha interfaces minimalistas e puras, sem dependência circular.
- Forneça testes unitários significativos.
- Não use tabelas. Prefira listas e gráficos simples.
- Siga as assinaturas fornecidas neste documento.

## Tarefas iniciais no Cursor
1. Implementar StrokeCapture com PencilKit e exportar Stroke.
2. Implementar ScoringEngine.computeMetrics com DTW, Fréchet, baseline e espaçamento.
3. Implementar Recommender.nextPlan com regras e tuneDifficulty.
4. Criar 20 templates iniciais (JSON) e dois layouts espaciais.
5. Construir tela de exercício com overlay de heatmap.

## Critérios de aceite
- Uma sessão completa roda offline.
- Métricas exibidas após cada tentativa.
- Recomendação muda conforme déficit dominante.

Pronto para desenvolvimento.
