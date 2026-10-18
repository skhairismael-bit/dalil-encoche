import Foundation
import Combine

/// La boîte aux enveloppes de Dalil sur disque : ~/Library/Application Support/NotchBuddy/dalil-enveloppes.json.
/// Lue au lancement, écrite à chaque changement (atomique). Rien ici ne touche Annour.
@MainActor
final class DalilEnveloppesStore: ObservableObject {
    static let pillId = "agent_dalil"

    @Published private(set) var boite: DalilBoite

    let url: URL
    private let journal: (String) -> Void

    /// `url` nil = le fichier de l'app ; `journal` reçoit les erreurs de disque (nb.log dans l'app).
    init(url: URL? = nil, journal: @escaping (String) -> Void = { _ in }) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? support.appendingPathComponent("NotchBuddy/dalil-enveloppes.json")
        self.journal = journal
        if let data = try? Data(contentsOf: self.url) {
            if let lue = DalilBoite.decoder(data) {
                boite = lue
            } else {
                // Illisible : on le garde à côté plutôt que de l'écraser à la prochaine enveloppe.
                boite = DalilBoite()
                let garde = self.url.deletingPathExtension().appendingPathExtension("corrompu-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: self.url, to: garde)
                journal("dalil-enveloppes : fichier illisible, gardé sous \(garde.lastPathComponent)")
            }
        } else {
            boite = DalilBoite()
        }
    }


    var nonVues: Int { boite.nonVues }
    var enveloppes: [DalilEnveloppe] { boite.enveloppes }

    func ajouter(_ texte: String) {
        guard boite.ajouter(texte) else { return }
        ecrire()
    }

    func marquerToutesVues() {
        guard boite.nonVues > 0 else { return }
        boite.marquerToutesVues()
        ecrire()
    }

    private func ecrire() {
        guard let data = boite.encoder() else { journal("dalil-enveloppes : encodage impossible"); return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            journal("dalil-enveloppes : écriture refusée (\(error.localizedDescription))")
        }
    }
}
