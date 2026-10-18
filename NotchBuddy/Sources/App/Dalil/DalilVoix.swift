#if !APPSTORE
import Foundation

/// « OK Dalil, … » répondu par Annour, à travers le pont unique `DalilPont` (Claude Code de
/// l'utilisateur, mcp-annour en lecture seule). Décidé par Ismael le 19/10/2026 : une réponse
/// quand il parle, jamais de prise de parole spontanée ; pas d'internet ; aucune trace écrite.
///
/// La conversation s'ouvre au mot d'appel (claude se connecte pendant qu'il parle), sert la
/// question et sa relance éventuelle, puis se ferme avec l'échange (silence, île fermée) :
/// rien n'est gardé d'un « OK Dalil » à l'autre. Une question à la fois ; une réponse qui
/// arrive après la fermeture est jetée.
@MainActor
final class DalilVoix {
    static let shared = DalilVoix()

    /// La voix passe par Dalil dès que Claude Code est installé : pas de clé API.
    static var isActive: Bool { ClaudeCLI.executable() != nil }

    enum Issue: Equatable {
        case reponse(String)
        case echec(String)
    }

    private(set) var enCours = false
    private var conversation: UUID?

    private var francais: Bool { VoiceSettings.language == "fr" }
    private var modele: String {
        UserDefaults.standard.string(forKey: DalilVoixTexte.cleModele) ?? DalilVoixTexte.modeleParDefaut
    }
    private var consigne: String {
        DalilVoixTexte.consigne(prenom: resolveUserFirstName(), francais: francais)
    }

    /// Au mot d'appel : lance claude pour la conversation de cet échange.
    func ouvrir() {
        let id = conversation ?? UUID()
        conversation = id
        DalilPont.shared.preparer(conversation: id, modele: modele, consigne: consigne)
    }

    /// Une question entendue. `nil` quand l'échange a été fermé pendant l'attente : la
    /// réponse ne doit plus être ni dite ni montrée.
    func repondre(_ transcript: String) async -> Issue? {
        guard !enCours else { return nil }
        enCours = true
        defer { enCours = false }
        let id = conversation ?? UUID()
        conversation = id
        var finale: String?
        var echec: String?
        for await evenement in DalilPont.shared.question(transcript, conversation: id,
                                                         modele: modele, consigne: consigne) {
            switch evenement {
            case .texte: break
            case .fin(let texte): finale = texte
            case .erreur(let message): echec = message
            }
        }
        guard conversation == id else { return nil }
        if let finale {
            let dite = DalilVoixTexte.borne(VoiceQuery.spokenText(finale))
            if !dite.isEmpty { return .reponse(dite) }
        }
        // Le pont a pu fermer ce processus : la prochaine question en ouvrira un neuf.
        fermer()
        appendAppLog("nb.log", "[Voice] Dalil failed: \(echec ?? "empty answer")")
        return .echec(DalilVoixTexte.echec(pont: echec ?? "", francais: francais))
    }

    /// Fin de l'échange : claude s'arrête, rien n'est gardé.
    func fermer() {
        guard let id = conversation else { return }
        conversation = nil
        DalilPont.shared.fermer(conversation: id)
    }
}
#endif
