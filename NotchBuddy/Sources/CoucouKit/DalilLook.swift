import SwiftUI

/// The look of Dalil's character: silhouette, body colours, eyes and a mark.
/// The animation (BotEngine) is the same for every look; only the drawing
/// parameters change. Picked once at launch from UserDefaults `dalilLook`
/// (`defaults write fr.louisraille.NotchBuddy dalilLook lanterne`).
enum DalilLook: String, CaseIterable, Sendable {
    /// Pebble: soft ivory oval, dark warm eyes. Calm, close to a stone one keeps in a pocket.
    case galet
    /// Lantern: taller deep-green body, light eyes, a gold flame on top.
    case lanterne
    /// Compass: near-circle, pale blue-grey, a thin ring and a gold needle at the top.
    case boussole

    @MainActor static var current: DalilLook = .galet

    @MainActor static func load(from defaults: UserDefaults = .standard) {
        if let raw = defaults.string(forKey: "dalilLook"), let look = DalilLook(rawValue: raw) {
            current = look
        }
    }

    /// Superellipse exponent (2/2.7 was the original; 1 is a true ellipse, lower is boxier).
    var expN: CGFloat {
        switch self {
        case .galet:    return 2.0 / 2.3
        case .lanterne: return 2.0 / 3.2
        case .boussole: return 1.0
        }
    }
    /// Half-width and half-height, as multiples of R.
    var rxK: CGFloat {
        switch self {
        case .galet:    return 1.12
        case .lanterne: return 1.00
        case .boussole: return 1.04
        }
    }
    var ryK: CGFloat {
        switch self {
        case .galet:    return 0.92
        case .lanterne: return 1.02
        case .boussole: return 1.04
        }
    }
    var bodyTop: Color {
        switch self {
        case .galet:    return Color(red: 0.969, green: 0.949, blue: 0.910)   // #F7F2E8
        case .lanterne: return Color(red: 0.235, green: 0.545, blue: 0.467)   // #3C8B77
        case .boussole: return Color(red: 0.953, green: 0.965, blue: 0.973)   // #F3F6F8
        }
    }
    var bodyBottom: Color {
        switch self {
        case .galet:    return Color(red: 0.831, green: 0.788, blue: 0.710)   // #D4C9B5
        case .lanterne: return Color(red: 0.086, green: 0.318, blue: 0.263)   // #165143
        case .boussole: return Color(red: 0.753, green: 0.800, blue: 0.839)   // #C0CCD6
        }
    }
    /// Eye colour on the main body.
    var ink: CGColor {
        switch self {
        case .galet:    return CGColor(red: 0.165, green: 0.110, blue: 0.078, alpha: 1)  // #2A1C14
        case .lanterne: return CGColor(red: 0.973, green: 0.957, blue: 0.890, alpha: 1)  // #F8F4E3
        case .boussole: return CGColor(red: 0.090, green: 0.125, blue: 0.180, alpha: 1)  // #17202E
        }
    }
    /// Eye size multiplier against Mochi's.
    var eyeMult: CGFloat {
        switch self {
        case .galet:    return 1.18
        case .lanterne: return 1.00
        case .boussole: return 1.08
        }
    }
    /// Gold used by the marks.
    static let gold = Color(red: 0.839, green: 0.659, blue: 0.282)   // #D6A848

    /// Mark drawn on the body after the eyes, in body coordinates (origin at the body centre).
    func drawMark(ctx: inout GraphicsContext, R: CGFloat, rx: CGFloat, ry: CGFloat, isMini: Bool) {
        switch self {
        case .galet:
            return
        case .lanterne:
            // A small flame above the body: a teardrop, gold with a lighter heart.
            guard !isMini else { return }
            let h = R * 0.36, w = h * 0.66
            let top = CGPoint(x: 0, y: -ry - h * 0.85)
            var flame = Path()
            flame.move(to: top)
            flame.addQuadCurve(to: CGPoint(x: w / 2, y: -ry + h * 0.05), control: CGPoint(x: w * 0.7, y: -ry - h * 0.35))
            flame.addQuadCurve(to: CGPoint(x: -w / 2, y: -ry + h * 0.05), control: CGPoint(x: 0, y: -ry + h * 0.35))
            flame.addQuadCurve(to: top, control: CGPoint(x: -w * 0.7, y: -ry - h * 0.35))
            flame.closeSubpath()
            ctx.fill(flame, with: .color(Self.gold))
            var heart = Path()
            heart.addEllipse(in: CGRect(x: -w * 0.16, y: -ry - h * 0.35, width: w * 0.32, height: h * 0.4))
            ctx.fill(heart, with: .color(Color(red: 1, green: 0.925, blue: 0.75)))
        case .boussole:
            // A thin ring inside the rim, and a gold needle at the top like a compass north.
            guard !isMini else { return }
            var ring = Path()
            ring.addEllipse(in: CGRect(x: -rx * 0.86, y: -ry * 0.86, width: rx * 1.72, height: ry * 1.72))
            ctx.stroke(ring, with: .color(Color(cgColor: ink).opacity(0.22)), style: StrokeStyle(lineWidth: max(1, R * 0.04)))
            let k = R * 0.26
            var needle = Path()
            needle.move(to: CGPoint(x: 0, y: -ry * 0.98))
            needle.addLine(to: CGPoint(x: k * 0.45, y: -ry * 0.98 + k * 1.1))
            needle.addLine(to: CGPoint(x: 0, y: -ry * 0.98 + k * 0.8))
            needle.addLine(to: CGPoint(x: -k * 0.45, y: -ry * 0.98 + k * 1.1))
            needle.closeSubpath()
            ctx.fill(needle, with: .color(Self.gold))
        }
    }
}
