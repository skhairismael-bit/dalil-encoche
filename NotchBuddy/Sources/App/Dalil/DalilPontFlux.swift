import Foundation

// Le pont de Dalil vers Claude Code : la partie sans processus (arguments, lecture du flux
// stream-json), testable seule par scripts/test-dalil-pont.sh.

/// Ce que le pont rend pour une question.
enum DalilPontEvenement: Equatable, Sendable {
    /// Tout le texte visible de la réponse jusqu'ici (pas seulement le dernier morceau).
    case texte(String)
    /// La réponse finale.
    case fin(String)
    case erreur(String)
}

enum DalilPontCommande {
    /// Les seuls outils permis : les lectures de mcp-annour. Les écritures sont interdites
    /// en plus d'être absentes, et `--tools ''` retire tous les outils intégrés (Bash, Read,
    /// WebSearch…) : `--allowedTools` seul ne ferme rien (prouvé le 18/10/2026).
    static let lectures = [
        "procedures_annour", "lieu_annour", "consignes_annour", "fiches_retenues",
        "quoi_de_neuf", "brief", "constats_voix",
    ].map { "mcp__dalil__\($0)" }
    static let ecritures = ["retenir_dans_annour", "constats_lus"].map { "mcp__dalil__\($0)" }

    static let modeles: [(id: String, label: String)] = [
        ("sonnet", "Sonnet"), ("opus", "Opus"), ("haiku", "Haiku"),
    ]

    static let urlServeur = "https://komjheaaezinwxslbfvs.supabase.co/functions/v1/mcp-annour"

    /// Le jeton passe par cette variable d'environnement du processus, que Claude Code
    /// remplace dans la configuration : ni sur le disque, ni dans les arguments (visibles par ps).
    static let variableJeton = "DALIL_JETON"

    static var configMCP: String {
        let config: [String: Any] = ["mcpServers": ["dalil": [
            "type": "http",
            "url": urlServeur,
            "headers": ["Authorization": "Bearer ${\(variableJeton)}"],
        ]]]
        let data = (try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func arguments(modele: String, consigne: String) -> [String] {
        [
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--model", modele,
            "--tools", "",
            "--permission-prompts", "none",
            "--strict-mcp-config",
            "--mcp-config", configMCP,
            // Sans ceci, le CLAUDE.md et les hooks de l'utilisateur entrent dans le chat.
            // `--bare`, `--safe-mode` et `--setting-sources ''` coupent la connexion ou le MCP.
            "--setting-sources", "project",
            "--no-session-persistence",
            "--system-prompt", consigne,
            "--allowedTools",
        ] + lectures + ["--disallowedTools"] + ecritures
    }

    /// Le jeton d'accès dans le JSON du trousseau (`{access_token, refresh_token}`).
    static func jeton(trousseau: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: trousseau) as? [String: Any],
              let jeton = json["access_token"] as? String, !jeton.isEmpty else { return nil }
        return jeton
    }

    /// Une question, au format stream-json attendu sur l'entrée standard.
    static func ligneQuestion(_ texte: String) -> Data {
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": texte]]
        var data = (try? JSONSerialization.data(withJSONObject: message)) ?? Data()
        data.append(0x0A)
        return data
    }
}

/// Lit la sortie stream-json de `claude -p`, morceau par morceau. Les lignes coupées entre
/// deux lectures sont recollées ; une ligne illisible est ignorée.
struct DalilPontFlux {
    private var reste = Data()
    private var texte = ""
    /// Le serveur dalil a répondu « connected » à l'ouverture de ce tour.
    private(set) var serveurConnecte: Bool?

    static let sansAcces = "Dalil n'a plus accès à Annour."

    mutating func lire(_ data: Data) -> [DalilPontEvenement] {
        reste.append(data)
        var evenements: [DalilPontEvenement] = []
        while let fin = reste.firstIndex(of: 0x0A) {
            let ligne = reste[reste.startIndex..<fin]
            reste.removeSubrange(reste.startIndex...fin)
            if let e = lireLigne(Data(ligne)) { evenements.append(e) }
        }
        return evenements
    }

    private mutating func lireLigne(_ ligne: Data) -> DalilPontEvenement? {
        guard let json = try? JSONSerialization.jsonObject(with: ligne) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        switch type {
        case "system" where json["subtype"] as? String == "init":
            let serveurs = json["mcp_servers"] as? [[String: Any]] ?? []
            let dalil = serveurs.first { $0["name"] as? String == "dalil" }
            serveurConnecte = dalil?["status"] as? String == "connected"
            return serveurConnecte == true ? nil : .erreur(Self.sansAcces)
        case "stream_event":
            guard let event = json["event"] as? [String: Any],
                  event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let morceau = delta["text"] as? String, !morceau.isEmpty else { return nil }
            texte += morceau
            return .texte(texte)
        case "assistant":
            // Un message entier : entre deux appels d'outil, le texte d'avant ne reste pas.
            texte = ""
            return nil
        case "result":
            let resultat = (json["result"] as? String) ?? ""
            texte = ""
            if json["is_error"] as? Bool == true || json["subtype"] as? String != "success" {
                let message = resultat.trimmingCharacters(in: .whitespacesAndNewlines)
                return .erreur(message.isEmpty ? "Claude Code n'a pas pu répondre." : message)
            }
            return .fin(resultat)
        default:
            return nil
        }
    }
}
