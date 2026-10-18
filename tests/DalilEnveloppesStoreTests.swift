import Foundation

@main
enum DalilEnveloppesStoreTests {
    @MainActor
    static func main() {
        var echecs = 0
        func verifier(_ ok: Bool, _ nom: String) {
            if ok { print("ok  \(nom)") } else { echecs += 1; print("ÉCHEC \(nom)") }
        }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("dalil-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("sous/dalil-enveloppes.json")
        var journal: [String] = []

        // Écrit, puis relu par une nouvelle instance (le redémarrage de l'app).
        let a = DalilEnveloppesStore(url: fichier, journal: { journal.append($0) })
        a.ajouter("1 nouveauté dans Annour : 1 vol modifié · 09:00")
        a.ajouter("2 nouveautés dans Annour : 2 billets lus · 09:05")
        verifier(FileManager.default.fileExists(atPath: fichier.path), "fichier écrit, dossier créé")
        let b = DalilEnveloppesStore(url: fichier, journal: { journal.append($0) })
        verifier(b.enveloppes.count == 2 && b.nonVues == 2, "relu au redémarrage, non vues gardées")
        b.marquerToutesVues()
        let c = DalilEnveloppesStore(url: fichier, journal: { journal.append($0) })
        verifier(c.nonVues == 0 && c.enveloppes.count == 2, "le « vu » survit au redémarrage")
        verifier(journal.isEmpty, "aucune erreur journalisée en fonctionnement normal")

        // Fichier illisible : gardé à côté, boîte vide, erreur journalisée, puis écriture possible.
        try? Data("{pas du json".utf8).write(to: fichier)
        let d = DalilEnveloppesStore(url: fichier, journal: { journal.append($0) })
        verifier(d.enveloppes.isEmpty, "fichier illisible = boîte vide")
        let gardes = (try? FileManager.default.contentsOfDirectory(atPath: fichier.deletingLastPathComponent().path))?.filter { $0.contains("corrompu") } ?? []
        verifier(gardes.count == 1, "fichier illisible gardé à côté")
        verifier(journal.contains { $0.contains("illisible") }, "erreur journalisée")
        d.ajouter("après")
        verifier(DalilEnveloppesStore(url: fichier).enveloppes.first?.texte == "après", "réécrit proprement après")

        // Écriture impossible : journalisée, pas de plantage.
        let interdit = URL(fileURLWithPath: "/dalil-enveloppes-impossible/x.json")
        let e = DalilEnveloppesStore(url: interdit, journal: { journal.append($0) })
        e.ajouter("x")
        verifier(journal.contains { $0.contains("écriture refusée") }, "écriture refusée journalisée")

        print(echecs == 0 ? "DalilEnveloppesStore : tout passe" : "DalilEnveloppesStore : \(echecs) échec(s)")
        exit(echecs == 0 ? 0 : 1)
    }
}
