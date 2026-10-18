#if !APPSTORE
import Foundation

/// Le pont unique de Dalil vers Claude Code (abonnement de l'utilisateur) et mcp-annour :
/// un processus `claude -p` en stream-json par conversation, gardé ouvert entre les questions
/// (2e réponse en 2,4 s au lieu de 5 à 7 s par relance, mesuré le 18/10/2026), fermé à la
/// nouvelle conversation. Le chat de l'encoche l'appelle ; la voix « OK Dalil » le réutilisera.
///
/// Une seule conversation à la fois, une seule question en cours. Une sortie d'un processus
/// déjà remplacé est jetée. Tout l'état vit sur `file` : jamais sur le fil principal.
final class DalilPont: @unchecked Sendable {
    static let shared = DalilPont()

    static let introuvable = "Claude Code est introuvable sur ce Mac."
    static let occupe = "Dalil répond déjà à une question."
    static let muet = "Claude Code ne répond plus. Pose ta question à nouveau."

    private let executable: @Sendable () -> String?
    private let jeton: @Sendable () -> String?
    private let dossier: URL
    private let journal: URL
    private let delai: TimeInterval
    private let file = DispatchQueue(label: "dalil.pont")

    // Ne vit que sur `file`.
    private final class Conversation: @unchecked Sendable {
        let id: UUID
        let process: Process
        let entree: FileHandle
        var flux = DalilPontFlux()
        var suite: AsyncStream<DalilPontEvenement>.Continuation?
        var garde: DispatchWorkItem?

        init(id: UUID, process: Process, entree: FileHandle) {
            self.id = id
            self.process = process
            self.entree = entree
        }
    }

    private var conversation: Conversation?

    init(executable: @escaping @Sendable () -> String? = { ClaudeCLI.executable() },
         jeton: @escaping @Sendable () -> String? = { DalilPont.jetonDuTrousseau() },
         dossier: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchBuddy/DalilPont"),
         journal: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/NotchBuddy/dalil-pont.log"),
         delai: TimeInterval = 120) {
        self.executable = executable
        self.jeton = jeton
        self.dossier = dossier
        self.journal = journal
        self.delai = delai
    }

    deinit {
        guard let c = conversation else { return }
        c.suite?.finish()
        try? c.entree.close()
        if c.process.isRunning { c.process.terminate() }
    }

    /// Pose une question dans la conversation `id` (ouverte au besoin). Le flux rend le texte
    /// au fil de l'eau, puis `.fin` ou `.erreur` ; il se termine sans rien rendre de plus si la
    /// conversation est fermée entre-temps.
    func question(_ texte: String, conversation id: UUID, modele: String, consigne: String)
        -> AsyncStream<DalilPontEvenement> {
        AsyncStream { suite in
            file.async { [self] in
                if let c = conversation, c.id == id, c.suite != nil {
                    suite.yield(.erreur(Self.occupe))
                    suite.finish()
                    return
                }
                if conversation?.id != id {
                    fermerSurFile()
                    switch ouvrir(id: id, modele: modele, consigne: consigne) {
                    case .success(let c): conversation = c
                    case .failure(let message):
                        suite.yield(.erreur(message.texte))
                        suite.finish()
                        return
                    }
                }
                guard let c = conversation else { return }
                c.suite = suite
                armerGarde(c)
                do {
                    try c.entree.write(contentsOf: DalilPontCommande.ligneQuestion(texte))
                } catch {
                    terminer(c, avec: .erreur(Self.muet))
                    fermerSurFile()
                }
            }
        }
    }

    /// Ferme la conversation `id` (ou celle en cours) : la question en attente se termine
    /// en silence, ce n'est pas une erreur.
    func fermer(conversation id: UUID? = nil) {
        file.async { [self] in
            guard id == nil || conversation?.id == id else { return }
            fermerSurFile()
        }
    }

    // MARK: - Sur la file

    private struct Echec: Error { let texte: String }

    private func ouvrir(id: UUID, modele: String, consigne: String) -> Result<Conversation, Echec> {
        guard let claude = executable() else { return .failure(Echec(texte: Self.introuvable)) }
        guard let jeton = jeton() else { return .failure(Echec(texte: DalilPontFlux.sansAcces)) }
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: journal.path, contents: Data("claude : \(claude)\n".utf8))
        let erreurs = try? FileHandle(forWritingTo: journal)
        _ = try? erreurs?.seekToEnd()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claude)
        process.arguments = DalilPontCommande.arguments(modele: modele, consigne: consigne)
        process.currentDirectoryURL = dossier
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ClaudeCLI.path(for: claude, inherited: env["PATH"])
        env[DalilPontCommande.variableJeton] = jeton
        process.environment = env
        let entree = Pipe()
        let sortie = Pipe()
        process.standardInput = entree
        process.standardOutput = sortie
        // Dans un fichier : un tuyau plein bloquerait claude.
        process.standardError = erreurs ?? FileHandle.nullDevice

        let c = Conversation(id: id, process: process, entree: entree.fileHandleForWriting)
        sortie.fileHandleForReading.readabilityHandler = { [weak self, weak c] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            guard let self, let c else { return }
            self.file.async {
                guard self.conversation === c else { return }
                self.lire(data, dans: c)
            }
        }
        process.terminationHandler = { [weak self, weak c] _ in
            try? erreurs?.close()
            guard let self, let c else { return }
            // Laisse passer la fin de la sortie avant de conclure à un arrêt sans réponse.
            self.file.asyncAfter(deadline: .now() + 0.3) {
                guard self.conversation === c else { return }
                self.terminer(c, avec: .erreur(self.dernierMot() ?? Self.muet))
                self.conversation = nil
            }
        }
        do {
            try process.run()
        } catch {
            return .failure(Echec(texte: Self.introuvable))
        }
        return .success(c)
    }

    private func lire(_ data: Data, dans c: Conversation) {
        for evenement in c.flux.lire(data) {
            switch evenement {
            case .texte:
                armerGarde(c)
                c.suite?.yield(evenement)
            case .fin, .erreur:
                terminer(c, avec: evenement)
            }
        }
        // Serveur refusé (jeton expiré) : la prochaine question rouvre avec un jeton neuf.
        if c.flux.serveurConnecte == false { fermerSurFile() }
    }

    private func terminer(_ c: Conversation, avec evenement: DalilPontEvenement) {
        c.garde?.cancel()
        c.garde = nil
        c.suite?.yield(evenement)
        c.suite?.finish()
        c.suite = nil
    }

    private func armerGarde(_ c: Conversation) {
        c.garde?.cancel()
        let garde = DispatchWorkItem { [weak self, weak c] in
            guard let self, let c, self.conversation === c, c.suite != nil else { return }
            self.terminer(c, avec: .erreur(Self.muet))
            self.fermerSurFile()
        }
        c.garde = garde
        file.asyncAfter(deadline: .now() + delai, execute: garde)
    }

    private func fermerSurFile() {
        guard let c = conversation else { return }
        conversation = nil
        c.garde?.cancel()
        c.suite?.finish()
        c.suite = nil
        try? c.entree.close()
        if c.process.isRunning {
            c.process.terminate()
            let pid = c.process.processIdentifier
            file.asyncAfter(deadline: .now() + 2) {
                if c.process.isRunning { kill(pid, SIGKILL) }
            }
        }
    }

    /// La dernière ligne du journal d'erreurs, quand claude s'arrête avant de répondre.
    private func dernierMot() -> String? {
        guard let data = try? Data(contentsOf: journal) else { return nil }
        let lignes = String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("claude : ") }
        return lignes.last.map { String($0.prefix(200)) }
    }

    /// Le jeton que le démon d'Annour tient à jour dans le trousseau. Lu par `security`,
    /// qui a créé l'entrée : l'app ne déclenche pas de demande d'accès au trousseau.
    static func jetonDuTrousseau() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "annour-dalil-encoche", "-a", "jetons", "-w"]
        let sortie = Pipe()
        process.standardOutput = sortie
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = sortie.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return DalilPontCommande.jeton(trousseau: data)
    }
}
#endif
