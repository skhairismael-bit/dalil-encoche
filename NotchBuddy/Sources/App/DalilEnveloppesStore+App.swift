import Foundation

extension DalilEnveloppesStore {
    /// La boîte de l'app : fichier NotchBuddy/dalil-enveloppes.json, erreurs dans nb.log.
    static let shared = DalilEnveloppesStore(journal: { appendAppLog("nb.log", $0) })

    /// Clic sur la pastille dalil (ou bouton « marquer vues ») : le seul geste qui marque les enveloppes vues.
    static func acquitter(pill: String) {
        guard pill == pillId else { return }
        shared.marquerToutesVues()
        HookServer.shared.rafraichirBadgeDalil()
    }
}
