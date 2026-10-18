import Foundation

// Le pont de Dalil : lecture de vraies sorties de `claude -p` (enregistrées le 18/10/2026,
// contenu des outils retiré), arguments de confinement, puis le processus avec un faux claude.

@main
enum DalilPontTests {
    nonisolated(unsafe) static var echecs = 0
    static func verifier(_ ok: Bool, _ nom: String) {
        if ok { print("ok  \(nom)") } else { echecs += 1; print("ÉCHEC \(nom)") }
    }

    static func main() async {
        setvbuf(stdout, nil, _IOLBF, 0)
        signal(SIGPIPE, SIG_IGN)
        let racine = URL(fileURLWithPath: CommandLine.arguments[1])
        let fixtures = racine.appendingPathComponent("tests/fixtures/dalil-pont")
        let fauxClaude = CommandLine.arguments[2]
        func fixture(_ nom: String) -> Data {
            (try? Data(contentsOf: fixtures.appendingPathComponent(nom))) ?? Data()
        }

        // 1. Flux réel : texte au fil de l'eau, puis la réponse finale.
        var flux = DalilPontFlux()
        let bonjour = flux.lire(fixture("bonjour.jsonl"))
        verifier(bonjour.first == .texte("Bonjour c"), "premier morceau rendu tel quel")
        verifier(bonjour.contains(.texte("Bonjour cher toi !")), "le texte s'accumule")
        verifier(bonjour.last == .fin("Bonjour cher toi !"), "fin = résultat")
        verifier(flux.serveurConnecte == true, "serveur dalil connecté")

        // 2. Lignes coupées n'importe où : mêmes événements.
        var coupe = DalilPontFlux()
        var morceaux: [DalilPontEvenement] = []
        let brut = fixture("bonjour.jsonl")
        var i = 0
        while i < brut.count {
            morceaux += coupe.lire(brut.subdata(in: i..<min(i + 7, brut.count)))
            i += 7
        }
        verifier(morceaux == bonjour, "lignes coupées recollées")

        // 3. Appel d'outil : la réponse vient après le résultat de l'outil.
        var outil = DalilPontFlux()
        let o = outil.lire(fixture("outil.jsonl"))
        verifier(o.last == .fin("18"), "réponse après un appel d'outil")
        verifier(!o.contains { if case .erreur = $0 { return true }; return false }, "pas d'erreur sur un appel d'outil")

        // 4. Serveur refusé (jeton faux) : erreur d'accès dès l'ouverture du tour.
        var refuse = DalilPontFlux()
        let r = refuse.lire(fixture("mcp-refuse.jsonl"))
        verifier(r.first == .erreur(DalilPontFlux.sansAcces), "jeton refusé → « plus accès »")
        verifier(refuse.serveurConnecte == false, "serveur noté non connecté")

        // 5. Résultat en erreur.
        var enErreur = DalilPontFlux()
        let e = enErreur.lire(Data(#"{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Not logged in"}"#.utf8 + [0x0A]))
        verifier(e == [.erreur("Not logged in")], "résultat en erreur rendu")
        verifier(enErreur.lire(Data("pas du json\n".utf8)).isEmpty, "ligne illisible ignorée")

        // 6. Confinement.
        let args = DalilPontCommande.arguments(modele: "sonnet", consigne: "c")
        func suit(_ a: String, _ b: String) -> Bool {
            guard let i = args.firstIndex(of: a), i + 1 < args.count else { return false }
            return args[i + 1] == b
        }
        verifier(suit("--tools", ""), "aucun outil intégré")
        verifier(args.contains("--strict-mcp-config"), "seul le serveur dalil")
        verifier(suit("--setting-sources", "project"), "ni CLAUDE.md ni hooks de l'utilisateur")
        verifier(args.contains("--no-session-persistence"), "rien gardé par la CLI")
        verifier(DalilPontCommande.ecritures.allSatisfy { args.contains($0) }, "écritures Dalil interdites")
        let permis = args.drop { $0 != "--allowedTools" }.dropFirst().prefix { !$0.hasPrefix("--") }
        verifier(Set(permis) == Set(DalilPontCommande.lectures), "seules les lectures permises")
        verifier(DalilPontCommande.configMCP.contains("Bearer ${DALIL_JETON}"), "jeton par variable d'environnement")
        verifier(!args.joined().contains("secret"), "jeton absent des arguments")

        let maison = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        verifier(!DalilPont.dossierParDefaut.resolvingSymlinksInPath().path.hasPrefix(maison + "/"),
                 "dossier de travail hors du dossier personnel (pas de CLAUDE.md remonté)")

        // 7. Le processus, avec un faux claude.
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("dalil-pont-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        setenv("FAUX_DOSSIER", dossier.path, 1)
        setenv("FAUX_FIXTURE", fixtures.appendingPathComponent("bonjour.jsonl").path, 1)
        func pont(executable: String? = fauxClaude, jeton: String? = "secret", delai: TimeInterval = 5) -> DalilPont {
            DalilPont(executable: { executable }, jeton: { jeton },
                      dossier: dossier.appendingPathComponent("cwd"),
                      journal: dossier.appendingPathComponent("journal.log"), delai: delai)
        }
        func tout(_ s: AsyncStream<DalilPontEvenement>) async -> [DalilPontEvenement] {
            var r: [DalilPontEvenement] = []
            for await e in s { r.append(e) }
            return r
        }
        func lu(_ nom: String) -> String {
            (try? String(contentsOf: dossier.appendingPathComponent(nom), encoding: .utf8)) ?? ""
        }

        setenv("FAUX_MODE", "normal", 1)
        let p = pont()
        let id = UUID()
        let un = await tout(p.question("Bonjour", conversation: id, modele: "sonnet", consigne: "c"))
        verifier(un.last == .fin("Bonjour cher toi !"), "première question répondue")
        let deux = await tout(p.question("Encore", conversation: id, modele: "sonnet", consigne: "c"))
        verifier(deux.last == .fin("Bonjour cher toi !"), "deuxième question répondue")
        verifier(lu("lancements").split(separator: "\n").count == 1, "même processus pour la conversation")
        verifier(lu("questions").contains("Encore"), "question reçue en stream-json")
        verifier(lu("jeton").trimmingCharacters(in: .whitespacesAndNewlines) == "secret", "jeton reçu par l'environnement")
        verifier(!lu("args").contains("secret"), "jeton absent de la ligne de commande")

        let autre = await tout(p.question("Neuve", conversation: UUID(), modele: "sonnet", consigne: "c"))
        verifier(autre.last == .fin("Bonjour cher toi !"), "nouvelle conversation répondue")
        verifier(lu("lancements").split(separator: "\n").count == 2, "nouvelle conversation = nouveau processus")

        // Préparer au mot d'appel : le processus part avant la question, puis la sert.
        let voix = UUID()
        p.preparer(conversation: voix, modele: "sonnet", consigne: "c")
        try? await Task.sleep(nanoseconds: 300_000_000)
        verifier(lu("lancements").split(separator: "\n").count == 3, "préparer lance le processus")
        let preparee = await tout(p.question("Quoi de neuf", conversation: voix, modele: "sonnet", consigne: "c"))
        verifier(preparee.last == .fin("Bonjour cher toi !"), "question servie par le processus préparé")
        p.preparer(conversation: voix, modele: "sonnet", consigne: "c")
        try? await Task.sleep(nanoseconds: 300_000_000)
        verifier(lu("lancements").split(separator: "\n").count == 3, "préparer deux fois ne relance pas")

        // Une seule question à la fois ; fermer termine en silence.
        setenv("FAUX_MODE", "muet", 1)
        let lente = UUID()
        let enCours = p.question("Longue", conversation: lente, modele: "sonnet", consigne: "c")
        try? await Task.sleep(nanoseconds: 500_000_000)
        let refusee = await tout(p.question("Pressée", conversation: lente, modele: "sonnet", consigne: "c"))
        verifier(refusee == [.erreur(DalilPont.occupe)], "deuxième question refusée pendant la première")
        p.fermer(conversation: lente)
        let fermee = await tout(enCours)
        verifier(fermee.isEmpty, "fermer termine sans erreur")

        // Silence trop long : erreur, processus fermé.
        let presse = pont(delai: 1)
        let muette = await tout(presse.question("Rien", conversation: UUID(), modele: "sonnet", consigne: "c"))
        verifier(muette == [.erreur(DalilPont.muet)], "délai dépassé → « ne répond plus »")

        // claude s'arrête avant de répondre : sa dernière ligne d'erreur.
        setenv("FAUX_MODE", "meurt", 1)
        let mourant = pont()
        let morte = await tout(mourant.question("x", conversation: UUID(), modele: "sonnet", consigne: "c"))
        verifier(morte == [.erreur("Not logged in")], "arrêt de claude → son message")

        let sansClaude = await tout(pont(executable: nil).question("x", conversation: UUID(), modele: "sonnet", consigne: "c"))
        verifier(sansClaude == [.erreur(DalilPont.introuvable)], "claude absent")
        let sansJeton = await tout(pont(jeton: nil).question("x", conversation: UUID(), modele: "sonnet", consigne: "c"))
        verifier(sansJeton == [.erreur(DalilPontFlux.sansAcces)], "jeton absent → « plus accès »")

        print(echecs == 0 ? "tous les tests passent" : "\(echecs) échec(s)")
        exit(echecs == 0 ? 0 : 1)
    }
}
