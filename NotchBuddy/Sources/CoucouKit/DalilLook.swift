import SwiftUI
import QuartzCore

/// Dalil's figure in the notch: a lighthouse. Dalil means "guide"; the light is his
/// gaze. Chosen by Ismael on 18/10/2026 after the CSS preview (dalil-phare.html).
/// The engine (BotEngine) keeps the tweens, states, badges and particles; this file
/// draws the whole figure from the engine's live values. `dalilLook` in UserDefaults
/// is kept for a future second look; any unknown value falls back to the lighthouse.
enum DalilLook: String, CaseIterable, Sendable {
    case phare

    static let fallback: DalilLook = .phare
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

    /// The look draws its whole figure (no Mochi body, hands or outfits).
    var ownsDrawing: Bool { true }

    // MARK: - Palette (same as the preview)

    static let ivory: (CGFloat, CGFloat, CGFloat) = (0.953, 0.937, 0.890)   // #F3EFE3
    static let shade: (CGFloat, CGFloat, CGFloat) = (0.812, 0.784, 0.722)   // #CFC8B8
    static let slate = Color(red: 0.141, green: 0.165, blue: 0.200)         // #242A33
    static let amber = Color(red: 0.839, green: 0.659, blue: 0.282)         // #D6A848
    static let warm  = Color(red: 1.0,   green: 0.914, blue: 0.690)         // #FFE9B0
    static let red   = Color(red: 0.961, green: 0.314, blue: 0.369)         // #F5505E

    /// Identity colour mixed with the state's colour by its tint; minis keep the flat agent colour.
    @MainActor static func mixed(_ engine: BotEngine, base: (CGFloat, CGFloat, CGFloat)) -> Color {
        if let bc = engine.bodyColor { return Color(cgColor: bc) }
        let t = engine.tint * 0.75
        let c = engine.col
        return Color(red: base.0 + (c.0 - base.0) * t, green: base.1 + (c.1 - base.1) * t, blue: base.2 + (c.2 - base.2) * t)
    }

    // MARK: - The light's programme, per state

    /// What the beam does: its turning speed (rad/s), a fixed heading, a pitch, how bright,
    /// whether it rolls, and whether the lamp itself is out, red or a mere ember.
    struct Light {
        var speed: CGFloat = 0.70      // 2π / 9 s at rest
        var heading: CGFloat? = nil    // fixed yaw instead of turning
        var pitch: CGFloat = 0.10      // slightly down, towards the pills
        var bright: CGFloat = 1
        var roll: Bool = false
        var sweep: CGFloat = 0         // > 0: oscillate ±sweep instead of turning
        var pulse: Bool = false
        var lamp: LampMode = .lit
        enum LampMode { case lit, ember, red, off }
    }

    @MainActor static func light(for engine: BotEngine) -> Light {
        var l = Light()
        switch engine.state {
        case .idle:      break
        case .working:   l.speed = 2.4; l.bright = 1
        case .thinking:  l.speed = 1.0; l.bright = 0.8; l.pitch = -0.25
        case .searching: l.sweep = 0.9; l.speed = 2.6
        case .approval:  l.heading = -0.35; l.pulse = true; l.pitch = 0.18
        case .question:  l.heading = 0.25; l.pulse = true; l.pitch = -0.55
        case .finished:  l.speed = 1.5; l.bright = 0.95
        case .error:     l.bright = 0; l.lamp = .red
        case .ratelimit: l.speed = 0.45; l.bright = 0.35
        case .sleeping:  l.bright = 0; l.lamp = .ember
        case .dizzy:     l.speed = 7; l.roll = true; l.bright = 0.8
        }
        if let e = engine.eyeOverride {
            switch e {
            case .closed: l.bright *= 0.3                  // a blink: the light dips
            case .happy, .heart, .star: l.bright = 1; l.pulse = true
            case .flat, .line: l.bright = 0; l.lamp = .red
            case .spiral: l.speed = 7; l.roll = true
            default: break
            }
        }
        return l
    }

    // MARK: - Drawing

    @MainActor
    func drawFigure(engine: BotEngine, ctx: inout GraphicsContext, R: CGFloat) {
        let now = CGFloat(CACurrentMediaTime())
        let mini = engine.isMini
        let body = Self.mixed(engine, base: Self.ivory)
        let shade = Self.mixed(engine, base: Self.shade)
        let l = Self.light(for: engine)

        // Geometry, in body coordinates (origin at the body centre). The figure spans
        // about ±1.05R vertically, like Mochi, so badges and particles keep their places.
        let baseY = R * 1.00, galleryY = -R * 0.62, lanternTop = -R * 0.90, lampY = -R * 0.76
        let baseHalf = R * (mini ? 0.42 : 0.36), topHalf = R * (mini ? 0.26 : 0.20)
        let lanternHalf = R * (mini ? 0.26 : 0.18)

        // Beam direction: yaw turns with time (or sits on a heading), the engine's own yaw
        // (where he looks) and pitch add to it; roll tilts the cone when dizzy.
        let turn: CGFloat
        if let h = l.heading { turn = h }
        else if l.sweep > 0 { turn = sin(now * l.speed) * l.sweep }
        else { turn = (now * l.speed).truncatingRemainder(dividingBy: .pi * 2) }
        let yaw = turn + engine.yaw * 1.2
        let pitch = l.pitch - engine.pitch * 0.8
        let roll = l.roll ? now * 6 : engine.roll
        let dir = (x: sin(yaw) * cos(pitch), y: -sin(pitch), z: cos(yaw) * cos(pitch))   // z > 0: towards the viewer
        let behind = dir.z < 0
        let breath = 0.5 + 0.5 * sin(now * 1.8 + CGFloat(engine.t0.truncatingRemainder(dividingBy: 10)))
        var bright = l.bright * (0.78 + 0.22 * breath)
        if l.pulse { bright *= 0.6 + 0.4 * (0.5 + 0.5 * sin(now * 6)) }
        if behind { bright *= 0.55 }

        func beam(into c: inout GraphicsContext) {
            guard bright > 0.03, !mini else { return }
            let len = R * 2.1 * (0.5 + 0.5 * sqrt(dir.x * dir.x + dir.y * dir.y) + 0.25 * max(0, dir.z))
            let spread = R * 0.34 * (0.35 + 0.65 * (dir.z + 1) / 2)   // wider when it comes towards the viewer
            let o = CGPoint(x: 0, y: lampY)
            let far = CGPoint(x: dir.x * len, y: lampY + dir.y * len)
            // Perpendicular to the beam on screen, tilted by the roll.
            let ang = atan2(far.y - o.y, far.x - o.x)
            let px = -sin(ang) * spread * abs(cos(roll)) , py = cos(ang) * spread * abs(cos(roll))
            var p = Path()
            p.move(to: o)
            p.addLine(to: CGPoint(x: far.x + px, y: far.y + py))
            p.addLine(to: CGPoint(x: far.x - px, y: far.y - py))
            p.closeSubpath()
            c.fill(p, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Self.warm.opacity(Double(0.95 * bright)), location: 0),
                    .init(color: Self.amber.opacity(Double(0.6 * bright)), location: 0.35),
                    .init(color: Self.amber.opacity(0), location: 1),
                ]),
                startPoint: o, endPoint: far))
        }

        // 1. Beam behind the tower when it points away.
        if behind { beam(into: &ctx) }

        // 2. Rock and base.
        if !mini {
            var rock = Path()
            rock.move(to: CGPoint(x: -R * 0.62, y: baseY + R * 0.10))
            rock.addQuadCurve(to: CGPoint(x: R * 0.62, y: baseY + R * 0.10), control: CGPoint(x: 0, y: baseY - R * 0.16))
            rock.closeSubpath()
            ctx.fill(rock, with: .color(Self.slate.opacity(0.9)))
            var plinth = Path()
            plinth.move(to: CGPoint(x: -R * 0.46, y: baseY))
            plinth.addQuadCurve(to: CGPoint(x: R * 0.46, y: baseY), control: CGPoint(x: 0, y: baseY - R * 0.2))
            plinth.closeSubpath()
            ctx.fill(plinth, with: .color(shade))
        }

        // 3. Tower, with its shadow side and two slate bands.
        var tower = Path()
        tower.move(to: CGPoint(x: -baseHalf, y: baseY))
        tower.addLine(to: CGPoint(x: -topHalf, y: galleryY))
        tower.addLine(to: CGPoint(x: topHalf, y: galleryY))
        tower.addLine(to: CGPoint(x: baseHalf, y: baseY))
        tower.closeSubpath()
        if mini {
            ctx.fill(tower, with: .color(body))
        } else {
            ctx.fill(tower, with: .linearGradient(Gradient(stops: [
                .init(color: body, location: 0), .init(color: body, location: 0.55), .init(color: shade, location: 1),
            ]), startPoint: CGPoint(x: -baseHalf, y: 0), endPoint: CGPoint(x: baseHalf, y: 0)))
            var bands = ctx
            bands.clip(to: tower)
            for y in [R * 0.05, R * 0.50] {
                var band = Path()
                band.addRoundedRect(in: CGRect(x: -baseHalf, y: y - R * 0.035, width: baseHalf * 2, height: R * 0.07), cornerSize: CGSize(width: R * 0.03, height: R * 0.03))
                bands.fill(band, with: .color(Self.slate.opacity(0.55)))
            }
            // Gallery: a rail with balusters.
            var rail = Path()
            rail.addRoundedRect(in: CGRect(x: -topHalf - R * 0.06, y: galleryY - R * 0.05, width: (topHalf + R * 0.06) * 2, height: R * 0.07), cornerSize: CGSize(width: R * 0.035, height: R * 0.035))
            ctx.fill(rail, with: .color(body))
            var bal = Path()
            for k in [-0.7, -0.35, 0.35, 0.7] as [CGFloat] {
                bal.move(to: CGPoint(x: topHalf * k, y: galleryY - R * 0.05))
                bal.addLine(to: CGPoint(x: topHalf * k, y: galleryY - R * 0.14))
            }
            ctx.stroke(bal, with: .color(Self.slate.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.8, R * 0.025), lineCap: .round))
        }

        // 4. Lantern room, dome, finial.
        var lantern = Path()
        lantern.addRoundedRect(in: CGRect(x: -lanternHalf, y: lanternTop, width: lanternHalf * 2, height: galleryY - R * 0.05 - lanternTop), cornerSize: CGSize(width: R * 0.03, height: R * 0.03))
        ctx.fill(lantern, with: .color(mini ? body : Self.slate.opacity(0.88)))
        if !mini {
            var glass = Path()
            glass.addRect(CGRect(x: -lanternHalf + R * 0.02, y: lanternTop + R * 0.02, width: lanternHalf * 2 - R * 0.04, height: galleryY - R * 0.09 - lanternTop))
            ctx.fill(glass, with: .color(Color.white.opacity(0.10)))
            var mullions = Path()
            for k in [-0.55, 0, 0.55] as [CGFloat] {
                mullions.move(to: CGPoint(x: lanternHalf * k, y: lanternTop + R * 0.02))
                mullions.addLine(to: CGPoint(x: lanternHalf * k, y: galleryY - R * 0.07))
            }
            ctx.stroke(mullions, with: .color(body.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.6, R * 0.02)))
        }
        var dome = Path()
        dome.move(to: CGPoint(x: -lanternHalf, y: lanternTop))
        dome.addQuadCurve(to: CGPoint(x: lanternHalf, y: lanternTop), control: CGPoint(x: 0, y: lanternTop - R * 0.22))
        dome.closeSubpath()
        ctx.fill(dome, with: .color(body))
        var finial = Path()
        finial.addEllipse(in: CGRect(x: -R * 0.03, y: lanternTop - R * 0.16, width: R * 0.06, height: R * 0.06))
        ctx.fill(finial, with: .color(mini ? body : Self.amber))

        // 5. The lamp: glow, lamp, and the beam in front.
        if !mini {
            let glowR = R * 0.30
            var glowA: Double
            var lampColor = Self.warm
            switch l.lamp {
            case .lit:   glowA = Double(0.35 + 0.25 * breath) * max(0.5, Double(l.bright))
            case .ember: glowA = Double(0.12 + 0.10 * breath); lampColor = Self.amber.opacity(0.7)
            case .red:   let on = sin(now * 7) > 0; glowA = on ? 0.45 : 0.05; lampColor = on ? Self.red : Self.red.opacity(0.4)
            case .off:   glowA = 0; lampColor = Self.slate
            }
            if glowA > 0.01 {
                var glow = Path()
                glow.addEllipse(in: CGRect(x: -glowR, y: lampY - glowR, width: glowR * 2, height: glowR * 2))
                ctx.fill(glow, with: .radialGradient(Gradient(stops: [
                    .init(color: (l.lamp == .red ? Self.red : Self.warm).opacity(glowA), location: 0),
                    .init(color: Self.amber.opacity(glowA * 0.4), location: 0.45),
                    .init(color: Self.amber.opacity(0), location: 1),
                ]), center: CGPoint(x: 0, y: lampY), startRadius: 0, endRadius: glowR))
            }
            var lamp = Path()
            lamp.addEllipse(in: CGRect(x: -R * 0.075, y: lampY - R * 0.075, width: R * 0.15, height: R * 0.15))
            ctx.fill(lamp, with: .color(lampColor))
            // Finished / happy: a ring around the lamp.
            if engine.state == .finished || engine.eyeOverride == .happy {
                var ring = Path()
                ring.addEllipse(in: CGRect(x: -R * 0.26, y: lampY - R * 0.26, width: R * 0.52, height: R * 0.52))
                ctx.stroke(ring, with: .color(Self.amber.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, R * 0.045)))
            }
        }
        if !behind { beam(into: &ctx) }
    }
}
