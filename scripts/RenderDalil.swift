// RenderDalil.swift — standalone renderer of Dalil's looks (choice bench)
// Compile + run via: bash scripts/render-dalil.sh <output dir>
// Output: <dir>/<look>-planche.png (states, main + mini) and <dir>/<look>-f<NN>.png (animation frames)

import Foundation
import SwiftUI
import AppKit

// MARK: - Stubs (substitutes for app-only types)

@MainActor
final class SoundEngine {
    static let shared = SoundEngine()
    var enabled: Bool = false
    func play(_ name: String) {}
}

extension Notification.Name {
    static let botDizzy          = Notification.Name("notchBuddy.botDizzy")
    static let botGreet          = Notification.Name("notchBuddy.botGreet")
    static let botBlink          = Notification.Name("notchBuddy.botBlink")
    static let botSetTgEs        = Notification.Name("notchBuddy.botSetTgEs")
    static let botGulp           = Notification.Name("notchBuddy.botGulp")
    static let botMorphTo        = Notification.Name("notchBuddy.botMorphTo")
    static let triggerEmote      = Notification.Name("notchBuddy.triggerEmote")
    static let triggerSlap       = Notification.Name("notchBuddy.triggerSlap")
    static let greetComplete     = Notification.Name("notchBuddy.greetComplete")
    static let greetingHover     = Notification.Name("notchBuddy.greetingHover")
    static let greetingInterrupt = Notification.Name("notchBuddy.greetingInterrupt")
    static let islandAction      = Notification.Name("notchBuddy.islandAction")
    static let islandCollapse    = Notification.Name("notchBuddy.islandCollapse")
    static let hookReveal        = Notification.Name("notchBuddy.hookReveal")
    static let musicReveal       = Notification.Name("notchBuddy.musicReveal")
    static let openFullSettings  = Notification.Name("notchBuddy.openFullSettings")
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let val = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((val >> 16) & 0xFF) / 255, green: Double((val >> 8) & 0xFF) / 255, blue: Double(val & 0xFF) / 255)
    }
}

// MARK: - One frame of the engine

@MainActor
func settledEngine(state: BotState, seconds: Double, mini: Bool = false, miniColor: CGColor? = nil) -> BotEngine {
    let e = BotEngine()
    e.isMini = mini
    e.bodyColor = miniColor
    e.setState(state, force: true)
    let dt = 1.0 / 60
    var t = 0.0
    while t < seconds { e.update(dt: dt); t += dt }
    return e
}

struct EngineCell: View {
    let engine: BotEngine
    let size: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            engine.drawHandsBehind(context: ctx, size: sz)
            engine.drawOutfitBehind(context: ctx, size: sz)
            engine.draw(context: ctx, size: sz)
            engine.drawOutfitFront(context: ctx, size: sz)
            engine.drawHandsAndExtras(context: ctx, size: sz)
        }
        .frame(width: size, height: size)
    }
}

private let states: [(String, BotState)] = [
    ("repos", .idle), ("travaille", .working), ("réfléchit", .thinking), ("cherche", .searching),
    ("approbation", .approval), ("question", .question), ("fini", .finished), ("erreur", .error),
    ("limite", .ratelimit), ("dort", .sleeping), ("étourdi", .dizzy),
]

struct Planche: View {
    let look: DalilLook
    func row(_ size: CGFloat, label: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 10)).foregroundColor(.gray).frame(width: 110, alignment: .trailing)
            ForEach(states.indices, id: \.self) { i in
                EngineCell(engine: settledEngine(state: states[i].1, seconds: 1.4), size: size)
                    .frame(width: 112, alignment: .center)
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dalil — \(look.rawValue)").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            HStack(spacing: 8) {
                Spacer().frame(width: 110)
                ForEach(states.indices, id: \.self) { i in
                    Text(states[i].0).font(.system(size: 10)).foregroundColor(.gray).frame(width: 112)
                }
            }
            row(112, label: "île ouverte (58 pt ×2)")
            row(58, label: "île ouverte (58 pt)")
            row(20, label: "encoche fermée (20 pt)")
            HStack(spacing: 8) {
                Text("mini sur pastille (16 pt)").font(.system(size: 10)).foregroundColor(.gray).frame(width: 110, alignment: .trailing)
                ForEach(["#D97757", "#4285F4", "#22C55E", "#A855F7", "#E5E7EB"], id: \.self) { hex in
                    EngineCell(engine: settledEngine(state: .idle, seconds: 0.4, mini: true,
                                                     miniColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)), size: 16)
                        .padding(4).background(Color(hex: hex)).cornerRadius(7)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }
}

@MainActor
func savePNG<V: View>(_ view: V, to path: String, scale: CGFloat = 2) {
    let r = ImageRenderer(content: view)
    r.scale = scale
    guard let img = r.nsImage, let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
        print("rendu impossible: \(path)"); return
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

@main
struct Main {
    @MainActor static func main() {
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dalil-looks"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for look in DalilLook.allCases {
            DalilLook.current = look
            savePNG(Planche(look: look), to: "\(dir)/\(look.rawValue)-planche.png")
            // Animation: idle, then a greet, 12 frames per second over 4 s
            let e = BotEngine()
            e.setState(.idle, force: true)
            let dt = 1.0 / 60
            var t = 0.0, frame = 0
            while t < 4.0 {
                if abs(t - 0.5) < dt / 2 { e.greet() }
                if abs(t - 2.6) < dt / 2 { e.setState(.working) }
                e.update(dt: dt)
                if Int(round(t / dt)) % 5 == 0 {
                    let cell = EngineCell(engine: e, size: 116).background(Color(red: 0.07, green: 0.07, blue: 0.08))
                    savePNG(cell, to: String(format: "%@/%@-f%03d.png", dir, look.rawValue, frame), scale: 1)
                    frame += 1
                }
                t += dt
            }
            print("\(look.rawValue): planche + \(frame) images")
        }
    }
}
