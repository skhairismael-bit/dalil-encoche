import SwiftUI
import QuartzCore

/// Dalil's figure in the notch. Nothing of Mochi's blob: each look draws its whole
/// figure from the engine's live values (BotEngine keeps the tweens, the states,
/// the badges and the particles). Picked at launch from UserDefaults `dalilLook`
/// (`defaults write fr.louisraille.NotchBuddy dalilLook balise`); an unknown
/// value falls back to the default.
enum DalilLook: String, CaseIterable, Sendable {
    /// Bookmark ribbon: a vertical band with a dovetail tail and a fold that breathes.
    case signet
    /// Path marker: two nested chevrons whose gap breathes and that lean where he looks.
    case balise
    /// Asymmetric crystal crossed by a ray of light that pulses and points.
    case prisme

    static let fallback: DalilLook = .balise
    @MainActor static var current: DalilLook = fallback

    @MainActor static func load(from defaults: UserDefaults = .standard) {
        current = defaults.string(forKey: "dalilLook").flatMap(DalilLook.init(rawValue:)) ?? fallback
    }

    // The upload mailbox still morphs from Mochi's superellipse: these keep its geometry.
    var expN: CGFloat { 2.0 / 2.7 }
    var rxK: CGFloat { 1.14 }
    var ryK: CGFloat { 0.88 }
    var bodyTop: Color { Color(red: 0.929, green: 0.929, blue: 0.937) }
    var bodyBottom: Color { Color(red: 0.769, green: 0.773, blue: 0.792) }
    var ink: CGColor { CGColor(red: 0.102, green: 0.082, blue: 0.071, alpha: 1) }
    var eyeMult: CGFloat { 1 }
    func drawMark(ctx: inout GraphicsContext, R: CGFloat, rx: CGFloat, ry: CGFloat, isMini: Bool) {}

    /// Every look here draws its whole figure.
    var ownsDrawing: Bool { true }

    // MARK: - Palette

    /// Identity colours: ivory body, dark slate line, amber light.
    static let ivory: (CGFloat, CGFloat, CGFloat) = (0.953, 0.937, 0.890)   // #F3EFE3
    static let slate = Color(red: 0.141, green: 0.165, blue: 0.200)         // #242A33
    static let amber = Color(red: 0.882, green: 0.690, blue: 0.302)         // #E1B04D

    // MARK: - Expression, from the engine's eye shape

    /// What the figure "feels", read from the state's eye shape (and the emotes).
    struct Mood {
        var lift: CGFloat = 0      // -1 sagging … +1 lifted
        var spread: CGFloat = 1    // 0 shut … 1 open … 1.3 wide
        var shake: CGFloat = 0     // 0 … 1 trembling
        var twist: CGFloat = 0     // 0 … 1 spinning (dizzy)
        var dim: CGFloat = 0       // 0 … 1 light fading (sleep)
        var broken: CGFloat = 0    // 0 … 1 the line breaks (error)
    }

    @MainActor static func mood(of engine: BotEngine) -> Mood {
        let shape = engine.eyeOverride ?? engine.cfg.eye
        var m = Mood()
        switch shape {
        case .happy, .heart, .star: m.lift = 1; m.spread = 1.15
        case .wide:                 m.spread = 1.3; m.lift = 0.4
        case .flat, .line:          m.broken = 1; m.lift = -0.5; m.spread = 0.6
        case .closed:               m.spread = 0.15; m.dim = 1; m.lift = -0.7
        case .tired:                m.lift = -0.8; m.spread = 0.5; m.dim = 0.4; m.shake = 0.5
        case .spiral:               m.twist = 1
        case .wink:                 m.lift = 0.6; m.spread = 0.8
        case .cup, .dot, .pill:     break
        }
        // Blink / squint of the engine becomes a short narrowing.
        m.spread *= 0.4 + 0.6 * engine.open
        return m
    }

    /// Body colour: identity mixed with the state's colour by its tint; minis keep the flat agent colour.
    @MainActor static func bodyColor(_ engine: BotEngine, base: (CGFloat, CGFloat, CGFloat)) -> Color {
        if let bc = engine.bodyColor { return Color(cgColor: bc) }
        let t = engine.tint * 0.75
        let c = engine.col
        return Color(red: base.0 + (c.0 - base.0) * t, green: base.1 + (c.1 - base.1) * t, blue: base.2 + (c.2 - base.2) * t)
    }

    // MARK: - Drawing

    @MainActor
    func drawFigure(engine: BotEngine, ctx: inout GraphicsContext, R: CGFloat) {
        let m = Self.mood(of: engine)
        let now = CGFloat(CACurrentMediaTime())
        switch self {
        case .signet: drawSignet(engine, &ctx, R, m, now)
        case .balise: drawBalise(engine, &ctx, R, m, now)
        case .prisme: drawPrisme(engine, &ctx, R, m, now)
        }
    }

    // Signet: ribbon 1.1R wide, 2.1R tall, dovetail at the bottom, fold on the top right.
    @MainActor
    private func drawSignet(_ e: BotEngine, _ ctx: inout GraphicsContext, _ R: CGFloat, _ m: Mood, _ now: CGFloat) {
        let w = R * 1.1, h = R * 2.1
        let sway = e.yaw * R * 0.35                     // the tail follows where he looks
        let twist = m.twist * sin(now * 9) * R * 0.25
        let notch = R * 0.36 * (1 - 0.5 * m.dim)
        var band = Path()
        band.move(to: CGPoint(x: -w / 2, y: -h / 2))
        band.addLine(to: CGPoint(x: w / 2, y: -h / 2))
        band.addLine(to: CGPoint(x: w / 2 + sway + twist, y: h / 2))
        band.addLine(to: CGPoint(x: sway, y: h / 2 - notch))
        band.addLine(to: CGPoint(x: -w / 2 + sway - twist, y: h / 2))
        band.closeSubpath()
        let fill = Self.bodyColor(e, base: Self.ivory)
        ctx.fill(band, with: .color(fill))
        if e.isMini { return }

        // Shadow along the left edge: a ribbon has a thickness.
        var edge = ctx
        edge.clip(to: band)
        edge.fill(band, with: .linearGradient(Gradient(colors: [Color.black.opacity(0.16), .clear]),
                                              startPoint: CGPoint(x: -w / 2, y: 0), endPoint: CGPoint(x: -w / 2 + R * 0.5, y: 0)))

        // The fold: a corner turned over at the top right, opening with the breath and the mood.
        let breath = 0.5 + 0.5 * sin(now * 1.6 + CGFloat(e.t0.truncatingRemainder(dividingBy: 10)))
        let openAmt = max(0.08, min(1, m.spread * (0.55 + 0.45 * breath)))
        let f = R * (0.42 + 0.38 * openAmt) * (1 + 0.25 * m.lift)
        var fold = Path()
        fold.move(to: CGPoint(x: w / 2, y: -h / 2))
        fold.addLine(to: CGPoint(x: w / 2 - f, y: -h / 2))
        fold.addLine(to: CGPoint(x: w / 2, y: -h / 2 + f))
        fold.closeSubpath()
        ctx.fill(fold, with: .color(Self.slate.opacity(0.85 - 0.5 * Double(m.dim))))

        // A thin amber line down the band: the thread. Broken on error, trembling on fear.
        let tremble = (m.shake + m.broken * 0.6) * sin(now * 40) * R * 0.05
        let x0 = -w * 0.18 + tremble
        var thread = Path()
        if m.broken > 0.5 {
            thread.move(to: CGPoint(x: x0, y: -h * 0.36)); thread.addLine(to: CGPoint(x: x0, y: -h * 0.05))
            thread.move(to: CGPoint(x: x0 + R * 0.12, y: h * 0.05)); thread.addLine(to: CGPoint(x: x0 + R * 0.12 + sway * 0.5, y: h * 0.32))
        } else {
            thread.move(to: CGPoint(x: x0, y: -h * 0.36))
            thread.addQuadCurve(to: CGPoint(x: x0 + sway * 0.6, y: h * 0.34), control: CGPoint(x: x0 + m.lift * R * 0.2, y: 0))
        }
        ctx.stroke(thread, with: .color(Self.amber.opacity(1 - 0.7 * Double(m.dim))),
                   style: StrokeStyle(lineWidth: max(1, R * 0.07), lineCap: .round))
    }

    // Balise: two chevrons pointing up, nested, like a path marker. Lean = yaw, gap = breath.
    @MainActor
    private func drawBalise(_ e: BotEngine, _ ctx: inout GraphicsContext, _ R: CGFloat, _ m: Mood, _ now: CGFloat) {
        let fill = Self.bodyColor(e, base: Self.ivory)
        let breath = 0.5 + 0.5 * sin(now * 1.7 + CGFloat(e.t0.truncatingRemainder(dividingBy: 10)))
        let lean = e.yaw * 0.55 + m.twist * sin(now * 7) * 0.8
        let half = R * 0.95
        // Height of the point above the arms: flattens on error/sleep, rises when happy.
        let peak = R * (0.62 + 0.35 * m.lift) * max(0.12, m.spread) * (1 - 0.6 * m.broken)
        let thick = R * (e.isMini ? 0.46 : 0.40)
        let gap = R * (0.34 + 0.14 * breath) * (0.3 + 0.7 * m.spread)
        let tremble = (m.shake + m.broken) * sin(now * 38) * R * 0.04

        func chevron(_ y: CGFloat, _ k: CGFloat, _ jitter: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: -half * k + jitter, y: y))
            p.addLine(to: CGPoint(x: lean * R * 0.5 + jitter, y: y - peak * k))
            p.addLine(to: CGPoint(x: half * k + jitter, y: y))
            return p
        }
        let style = StrokeStyle(lineWidth: thick, lineCap: .round, lineJoin: .round)
        var c = ctx
        if m.twist > 0.5 { c.rotate(by: .radians(Double(sin(now * 7) * 0.5))) }
        c.stroke(chevron(R * 0.78, 1.0, -tremble), with: .color(fill), style: style)
        let upperY = R * 0.78 - gap - thick * 0.9
        c.stroke(chevron(upperY, 0.78, tremble), with: .color(fill), style: style)
        if e.isMini { return }

        // The amber light at the point of the upper chevron: it breathes, dims when sleeping,
        // goes out on error and doubles when finished.
        let tip = CGPoint(x: lean * R * 0.5 + tremble, y: upperY - peak * 0.78)
        let glow = (0.75 + 0.25 * breath) * (1 - 0.8 * m.dim) * (1 - m.broken)
        if glow > 0.05 {
            let r = R * 0.17 * glow * (1 + 0.3 * m.lift)
            var dot = Path(); dot.addEllipse(in: CGRect(x: tip.x - r, y: tip.y - r, width: 2 * r, height: 2 * r))
            c.fill(dot, with: .color(Self.amber))
            if m.lift > 0.8 {
                var halo = Path(); halo.addEllipse(in: CGRect(x: tip.x - r * 2, y: tip.y - r * 2, width: 4 * r, height: 4 * r))
                c.stroke(halo, with: .color(Self.amber.opacity(0.6)), style: StrokeStyle(lineWidth: max(1, R * 0.05)))
            }
        } else if m.broken > 0.5 {
            // Error: the light is out, a short dark dash crosses the point.
            var dash = Path()
            dash.move(to: CGPoint(x: tip.x - R * 0.2, y: tip.y + R * 0.1)); dash.addLine(to: CGPoint(x: tip.x + R * 0.2, y: tip.y - R * 0.1))
            c.stroke(dash, with: .color(Self.slate.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, R * 0.07), lineCap: .round))
        }
    }

    // Prisme: an asymmetric crystal (irregular pentagon) with a ray of light through it.
    @MainActor
    private func drawPrisme(_ e: BotEngine, _ ctx: inout GraphicsContext, _ R: CGFloat, _ m: Mood, _ now: CGFloat) {
        let fill = Self.bodyColor(e, base: Self.ivory)
        let breath = 0.5 + 0.5 * sin(now * 1.5 + CGFloat(e.t0.truncatingRemainder(dividingBy: 10)))
        let tremble = (m.shake + m.broken) * sin(now * 36) * R * 0.04
        let sag = -m.lift * R * 0.12 + m.dim * R * 0.15
        let pts = [
            CGPoint(x: -R * 0.55 + tremble, y: -R * 0.95 + sag),
            CGPoint(x: R * 0.75, y: -R * 0.65 + sag * 0.5),
            CGPoint(x: R * 0.95 + tremble, y: R * 0.45),
            CGPoint(x: R * 0.10, y: R * 0.98),
            CGPoint(x: -R * 0.95 - tremble, y: R * 0.30),
        ]
        var crystal = Path(); crystal.move(to: pts[0]); for p in pts.dropFirst() { crystal.addLine(to: p) }; crystal.closeSubpath()
        var c = ctx
        if m.twist > 0.5 { c.rotate(by: .radians(Double(now * 4))) }
        c.fill(crystal, with: .color(fill))
        if e.isMini { return }

        // Facets: two darker triangles give the volume.
        var facet = Path(); facet.move(to: pts[0]); facet.addLine(to: pts[3]); facet.addLine(to: pts[4]); facet.closeSubpath()
        c.fill(facet, with: .color(Color.black.opacity(0.10)))
        var facet2 = Path(); facet2.move(to: pts[1]); facet2.addLine(to: pts[2]); facet2.addLine(to: pts[3]); facet2.closeSubpath()
        c.fill(facet2, with: .color(Color.black.opacity(0.05)))
        var rim = c; rim.clip(to: crystal)

        // The ray: enters on the left, bends inside, points where he looks. Pulses, dims, breaks.
        let bright = (0.7 + 0.3 * breath) * (1 - 0.85 * m.dim) * (0.35 + 0.65 * m.spread)
        let aim = CGPoint(x: R * 0.95, y: -R * 0.1 - e.yaw * R * 0.6 - e.pitch * R * 0.4 - m.lift * R * 0.25)
        let entry = CGPoint(x: -R * 0.95, y: R * 0.15)
        let bend = CGPoint(x: -R * 0.1, y: R * 0.1 + m.lift * R * 0.1)
        var ray = Path()
        if m.broken > 0.5 {
            ray.move(to: entry); ray.addLine(to: CGPoint(x: bend.x - R * 0.12, y: bend.y))
            ray.move(to: CGPoint(x: bend.x + R * 0.12, y: bend.y - R * 0.18 + tremble)); ray.addLine(to: aim)
        } else {
            ray.move(to: entry); ray.addLine(to: bend); ray.addLine(to: aim)
        }
        rim.stroke(ray, with: .color(Self.amber.opacity(Double(bright))),
                   style: StrokeStyle(lineWidth: max(1, R * 0.11), lineCap: .round, lineJoin: .round))
        rim.stroke(ray, with: .color(Color.white.opacity(Double(bright) * 0.5)),
                   style: StrokeStyle(lineWidth: max(0.5, R * 0.035), lineCap: .round, lineJoin: .round))
        if m.lift > 0.8 {
            // Finished: the ray splits into a small fan at the exit.
            for k in [-1.0, 1.0] as [CGFloat] {
                var f = Path(); f.move(to: bend); f.addLine(to: CGPoint(x: aim.x, y: aim.y + k * R * 0.3))
                rim.stroke(f, with: .color(Self.amber.opacity(Double(bright) * 0.45)), style: StrokeStyle(lineWidth: max(1, R * 0.06), lineCap: .round))
            }
        }
    }
}
