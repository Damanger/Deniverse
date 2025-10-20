import SwiftUI
import Combine

// Date-based seasonal themes and lightweight overlays

enum SeasonalEffect: CaseIterable {
    case spiderWeb, spider, lightning, love

    static func random() -> SeasonalEffect { allCases.randomElement() ?? .spiderWeb }
}

enum SeasonalCalendarTheme {
    // Día de muertos: Oct 20 – Nov 5 (cualquier año)
    static func isDiaDeMuertosActive(on date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let oct21 = cal.date(from: DateComponents(year: y, month: 10, day: 21))!
        let nov05 = cal.date(from: DateComponents(year: y, month: 11, day: 5))!
        return (date >= oct21 && date <= nov05)
    }

    // Amor: día 20 de cada mes
    static func isLoveDay(on date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: date)
        return comps.day == 20
    }
}

final class SeasonalEffectPicker {
    static var chosenForSession: SeasonalEffect?
    static func pick(for date: Date = Date()) -> SeasonalEffect? {
        // 1) Amor el día 20 de cada mes (siempre)
        if SeasonalCalendarTheme.isLoveDay(on: date) {
            return .love
        }
        // 2) Efectos temáticos (ej: Día de Muertos) en ventana específica
        if SeasonalCalendarTheme.isDiaDeMuertosActive(on: date) {
            if let c = chosenForSession, c != .love { return c }
            let pool: [SeasonalEffect] = [.spiderWeb, .spider, .lightning]
            let c = pool.randomElement() ?? .spiderWeb
            chosenForSession = c
            return c
        }
        // 3) Nada fuera de las fechas especiales
        return nil
    }
}

struct SeasonalOverlay: View {
    let effect: SeasonalEffect
    var body: some View {
        ZStack {
            switch effect {
            case .spiderWeb: SpiderWebOverlay() // telaraña clásica en esquinas
            case .spider:
                ZStack { // araña con telaraña clásica de fondo
                    SpiderWebOverlay()
                    SpiderSceneOverlay()
                }
            case .lightning: LightningOverlay()
            case .love: LoveOverlay() // corazones y emojis románticos el día 20
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rain (always visible)
final class RainModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    
    struct Drop { var x: CGFloat; var y: CGFloat; var vx: CGFloat; var vy: CGFloat; var len: CGFloat; var op: Double }
    @Published var drops: [Drop] = []
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    private var size: CGSize = .zero
    func configure(size: CGSize, count: Int = 140) {
        self.size = size
        if drops.isEmpty {
            drops = (0..<count).map { _ in
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let vy = CGFloat.random(in: 8...16)
                let vx = CGFloat.random(in: -2...(-0.5))
                let len = CGFloat.random(in: 10...22)
                let op = Double.random(in: 0.18...0.35)
                return Drop(x: x, y: y, vx: vx, vy: vy, len: len, op: op)
            }
            start()
        } else {
            // resize
            drops.indices.forEach { i in drops[i].x = min(drops[i].x, size.width); drops[i].y = min(drops[i].y, size.height) }
        }
    }
    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in self?.tick() }
    }
    private func tick() {
        guard size != .zero else { return }
        let w = size.width, h = size.height
        for i in drops.indices {
            drops[i].x += drops[i].vx
            drops[i].y += drops[i].vy
            if drops[i].y - drops[i].len > h || drops[i].x < -20 {
                drops[i].x = CGFloat.random(in: 0...w)
                drops[i].y = -CGFloat.random(in: 0...100)
            }
        }
    }
}

struct RainOverlay: View {
    @StateObject private var model = RainModel()
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for d in model.drops {
                    var path = Path()
                    let start = CGPoint(x: d.x, y: d.y)
                    let end = CGPoint(x: d.x + d.vx * d.len, y: d.y + d.vy * d.len)
                    path.move(to: start)
                    path.addLine(to: end)
                    ctx.stroke(path, with: .color(Color.white.opacity(d.op)), lineWidth: 1)
                }
            }
            .onAppear { model.configure(size: geo.size) }
            .onChange(of: geo.size) { _, new in model.configure(size: new) }
        }
        .allowsHitTesting(false)
        .opacity(0.65)
        .blendMode(.plusLighter)
    }
}

// MARK: - Individual effects

private struct SpiderWebOverlay: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let anchors = [CGPoint(x: 12, y: 12), CGPoint(x: w - 12, y: 12)]
            ZStack {
                ForEach(0..<anchors.count, id: \.self) { idx in
                    let a = anchors[idx]
                    // Rings (quarter arcs)
                    ForEach(1..<7, id: \.self) { r in
                        Path { p in
                            let radius = CGFloat(r) * min(w, h) * 0.12
                            let start: Angle = (idx == 0) ? .degrees(0) : .degrees(90)
                            let end: Angle = (idx == 0) ? .degrees(90) : .degrees(180)
                            p.addArc(center: a, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                        }
                        .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 0.7, dash: [6,4], dashPhase: phase))
                    }
                    // Radials
                    ForEach(0..<6, id: \.self) { i in
                        Path { p in
                            let ang = (idx == 0) ? (Double(i) * 15.0) : (90.0 + Double(i) * 15.0)
                            let rad = ang * .pi / 180.0
                            let len = min(w, h) * 0.6
                            p.move(to: a)
                            p.addLine(to: CGPoint(x: a.x + CGFloat(cos(rad)) * len, y: a.y + CGFloat(sin(rad)) * len))
                        }
                        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.6, lineCap: .round, dash: [8,6], dashPhase: phase))
                    }
                }
            }
            .blendMode(.plusLighter)
            .onAppear { withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { phase = 20 } }
        }
    }
}

private struct SpiderOverlay: View {
    @State private var y: CGFloat = -40
    @State private var sway: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width * 0.18
            let anchorX = centerX + sway
            let anchorY = max(0, y)
            ZStack(alignment: .topLeading) {
                // Hilo
                Path { p in
                    p.move(to: CGPoint(x: anchorX, y: 0))
                    p.addLine(to: CGPoint(x: anchorX, y: anchorY))
                }
                .stroke(Color.white.opacity(0.45), lineWidth: 0.9)

                // Grupo de araña que se mueve en conjunto
                SpiderBody()
                    .frame(width: 44, height: 44)
                    .offset(x: anchorX - 22, y: anchorY - 22)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    y = geo.size.height * 0.42
                }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    sway = 8
                }
            }
        }
        .blendMode(.multiply)
        .opacity(0.95)
    }
}

// Web + Spider cohesivos (la telaraña sigue el ancla de la araña)
private struct SpiderSceneOverlay: View {
    @State private var y: CGFloat = -40
    @State private var sway: CGFloat = 0
    @State private var phase: CGFloat = 0
    @State private var anchorXF: CGFloat = .random(in: 0.12...0.3)

    var body: some View {
        GeometryReader { geo in
            let anchorX = geo.size.width * anchorXF + sway
            let anchorY = max(0, y)
            ZStack(alignment: .topLeading) {
                // Telaraña local bajo el punto de anclaje
                LocalWeb(center: CGPoint(x: anchorX, y: 0), depth: 5, width: geo.size.width, phase: phase)
                    .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 0.7, dash: [6,4], dashPhase: phase))
                // Hilo
                Path { p in
                    p.move(to: CGPoint(x: anchorX, y: 0))
                    p.addLine(to: CGPoint(x: anchorX, y: anchorY))
                }
                .stroke(Color.white.opacity(0.45), lineWidth: 0.9)

                // Araña completa
                SpiderBody()
                    .frame(width: 44, height: 44)
                    .offset(x: anchorX - 22, y: anchorY - 22)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { y = geo.size.height * 0.42 }
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { sway = 8 }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { phase = 24 }
            }
        }
        .opacity(0.95)
        .blendMode(.multiply)
    }
}

private struct LocalWeb: Shape {
    let center: CGPoint
    let depth: Int
    let width: CGFloat
    var phase: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let base = center
        // Curvas horizontales en abanico bajo el ancla
        for i in 1...depth {
            let y = CGFloat(i) * 14
            let span = CGFloat(i) * 26
            let left = CGPoint(x: base.x - span, y: y)
            let right = CGPoint(x: base.x + span, y: y)
            let ctrl = CGPoint(x: base.x, y: max(2, y - 8))
            p.move(to: left)
            p.addQuadCurve(to: right, control: ctrl)
        }
        // Radiales finas
        for i in 0..<6 {
            let ang = -CGFloat.pi/2 + CGFloat(i) * (.pi/12)
            let len = min(width * 0.45, 160)
            p.move(to: base)
            p.addLine(to: CGPoint(x: base.x + cos(ang) * len, y: base.y + sin(ang) * len))
        }
        return p
    }
}

private struct SpiderBody: View {
    var body: some View {
        GeometryReader { geo in
            let cx: CGFloat = geo.size.width / 2
            let cy: CGFloat = geo.size.height / 2
            ZStack {
                // Abdomen y cabeza posicionados desde el centro
                Circle()
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .position(x: cx, y: cy + 6)
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .position(x: cx, y: cy - 6)
                // Patas (simétricas) relativas al centro
                ForEach(0..<4, id: \.self) { i in
                    let ly = cy - 2 + CGFloat(i) * 6
                    Path { p in
                        p.move(to: CGPoint(x: cx - 10, y: ly))
                        p.addQuadCurve(to: CGPoint(x: cx - 22, y: ly - 4), control: CGPoint(x: cx - 16, y: ly - 2))
                        p.addQuadCurve(to: CGPoint(x: cx - 32, y: ly + 4), control: CGPoint(x: cx - 24, y: ly + 2))
                    }.stroke(Color.black.opacity(0.85), lineWidth: 1)
                    Path { p in
                        p.move(to: CGPoint(x: cx + 10, y: ly))
                        p.addQuadCurve(to: CGPoint(x: cx + 22, y: ly - 4), control: CGPoint(x: cx + 16, y: ly - 2))
                        p.addQuadCurve(to: CGPoint(x: cx + 32, y: ly + 4), control: CGPoint(x: cx + 24, y: ly + 2))
                    }.stroke(Color.black.opacity(0.85), lineWidth: 1)
                }
            }
        }
    }
}

private struct LightningOverlay: View {
    struct Bolt: Identifiable { let id = UUID(); let points: [CGPoint]; let width: CGFloat }
    @State private var flash = false
    @State private var darkOpacity: Double = 0
    @State private var whiteOpacity: Double = 0
    @State private var bolts: [Bolt] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    guard flash else { return }
                    for bolt in bolts {
                        var path = Path()
                        if let first = bolt.points.first {
                            path.move(to: first)
                            for pt in bolt.points.dropFirst() { path.addLine(to: pt) }
                        }
                        // Glow layer
                        context.stroke(path, with: .color(.white.opacity(0.20)), lineWidth: bolt.width + 10)
                        context.stroke(path, with: .color(.yellow.opacity(0.35)), lineWidth: bolt.width + 6)
                        // Core
                        let grad = Gradient(colors: [Color.yellow.opacity(0.95), .white])
                        let shading = GraphicsContext.Shading.linearGradient(
                            grad,
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                        context.stroke(path, with: shading, lineWidth: bolt.width)
                    }
                }
                .drawingGroup()
                // Screen dim/flash
                Color.black.opacity(darkOpacity).ignoresSafeArea()
                Color.white.opacity(whiteOpacity).ignoresSafeArea()
            }
            .onAppear { scheduleNextFlash(size: geo.size) }
        }
    }

    private func scheduleNextFlash(size: CGSize) {
        let delay = Double(Int.random(in: 2...6))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            bolts = generateBolts(size: size)
            withAnimation(.easeIn(duration: 0.08)) { darkOpacity = 0.18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.easeOut(duration: 0.12)) { whiteOpacity = 0.08; flash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    withAnimation(.easeIn(duration: 0.18)) { whiteOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.easeIn(duration: 0.22)) { darkOpacity = 0; flash = false }
                        scheduleNextFlash(size: size)
                    }
                }
            }
        }
    }

    private func generateBolts(size: CGSize) -> [Bolt] {
        let count = Int.random(in: 1...3)
        var out: [Bolt] = []
        for _ in 0..<count {
            let startX = CGFloat.random(in: size.width * 0.15 ... size.width * 0.85)
            let startY = CGFloat.random(in: 0 ... size.height * 0.15)
            let segs = Int.random(in: 12...18)
            let xr = size.width * 0.06
            let yr = size.height * 0.05
            var pts: [CGPoint] = [CGPoint(x: startX, y: startY)]
            for _ in 0..<segs {
                var last = pts.last!
                last.x += CGFloat.random(in: -xr...xr)
                last.y += CGFloat.random(in: yr*0.6...yr)
                last.x = min(max(0, last.x), size.width)
                if last.y > size.height { break }
                pts.append(last)
            }
            let width = CGFloat.random(in: 2.5...4.5)
            out.append(Bolt(points: pts, width: width))
        }
        return out
    }
}

// MARK: - Love day (20th of each month) hearts + emojis
final class LoveConfettiModel: ObservableObject {
    struct Item: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var vx: CGFloat; var vy: CGFloat; var size: CGFloat; var rot: CGFloat }
    @Published var items: [Item] = []
    private var timer: Timer?
    private var area: CGSize = .zero
    private let symbols: [String] = {
        // Predominantly hearts; sprinkle in a few romance emojis
        let hearts = Array(repeating: ["💖","💕","💗","💘","💞","💓","💝","💟"], count: 6).flatMap { $0 }
        let extras = ["💌","😍","😘","🥰","✨"]
        return hearts + extras
    }()

    deinit { timer?.invalidate() }

    func configure(size: CGSize, count: Int = 68) {
        area = size
        if items.isEmpty {
            let w = size.width, h = size.height
            items = (0..<count).map { _ in
                let x = CGFloat.random(in: 0...w)
                let y = CGFloat.random(in: 0...h)
                let vy = -CGFloat.random(in: 12...28) / 30.0 // upward px/frame
                let vx = CGFloat.random(in: -6...6) / 30.0
                let s = CGFloat.random(in: 18...36)
                return Item(x: x, y: y, vx: vx, vy: vy, size: s, rot: CGFloat.random(in: -(.pi)...(.pi)))
            }
            start()
        } else {
            // Clamp to new size on rotation/resize
            items.indices.forEach { i in
                items[i].x = min(max(0, items[i].x), size.width)
                items[i].y = min(max(0, items[i].y), size.height)
            }
        }
    }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let w = area.width, h = area.height
        guard w > 0 && h > 0 else { return }
        for i in items.indices {
            items[i].x += items[i].vx
            items[i].y += items[i].vy
            items[i].rot += 0.01 * (items[i].vx >= 0 ? 1 : -1)
            // Gentle sway
            items[i].x += sin(items[i].y * 0.03) * 0.3
            // Re-spawn at bottom when floating past top or off-sides
            if items[i].y < -40 || items[i].x < -40 || items[i].x > w + 40 {
                items[i].x = CGFloat.random(in: 0...w)
                items[i].y = h + CGFloat.random(in: 10...80)
                items[i].vx = CGFloat.random(in: -6...6) / 30.0
                items[i].vy = -CGFloat.random(in: 12...28) / 30.0
                items[i].size = CGFloat.random(in: 18...36)
            }
        }
    }

    func symbol(for index: Int) -> String { symbols[index % symbols.count] }
}

private struct LoveOverlay: View {
    @StateObject private var model = LoveConfettiModel()
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Subtle bloom layer
                ctx.addFilter(.blur(radius: 0))
                for (idx, item) in model.items.enumerated() {
                    let sym = model.symbol(for: idx)
                    let t = Text(sym).font(.system(size: item.size))
                    ctx.draw(t, at: CGPoint(x: item.x, y: item.y), anchor: .center)
                }
            }
            .onAppear { model.configure(size: geo.size) }
            .onChange(of: geo.size) { _, new in model.configure(size: new) }
        }
        .allowsHitTesting(false)
        .opacity(0.9)
        .blendMode(.plusLighter)
    }
}
