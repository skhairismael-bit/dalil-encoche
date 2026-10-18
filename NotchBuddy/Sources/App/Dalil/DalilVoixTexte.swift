#if !APPSTORE
import Foundation

// « OK Dalil » : la partie sans processus ni micro (consigne, phrases dites, réponse bornée),
// testable seule par scripts/test-dalil-voix.sh.

enum DalilVoixTexte {
    /// Modèle de la voix : `defaults write fr.louisraille.NotchBuddy dalilVoiceModel opus`.
    static let cleModele = "dalilVoiceModel"
    static let modeleParDefaut = "sonnet"

    /// Une réponse dite ne dépasse pas ces bornes, quoi qu'écrive le modèle.
    static let phrasesMax = 4
    static let caracteresMax = 450

    static func consigne(prenom: String?, francais: Bool) -> String {
        let qui = prenom.map { "de \($0)" } ?? "de l'utilisateur"
        let langue = francais ? "Réponds en français." : "Answer in English."
        return """
        Tu es Dalil, l'assistant \(qui), dans l'encoche de son Mac. Il t'a parlé à voix haute et \
        ta réponse sera lue par une voix de synthèse. Tu lis Annour, l'application de sa société, \
        par les outils dalil, en lecture seule ; tu n'as ni internet ni les fichiers du Mac : \
        dis-le quand une question en a besoin. Ne dis jamais qu'une chose a été faite ou retenue. \
        \(langue) Trois phrases courtes au plus, sans liste, sans titre, sans lien, sans tableau, \
        sans numéro de dossier sauf s'il est demandé. Si Annour ne le sait pas, dis-le.
        """
    }

    static func attente(francais: Bool) -> String {
        francais ? "Je regarde dans Annour…" : "Looking in Annour…"
    }

    static func echec(francais: Bool) -> String {
        francais ? "Dalil n'a pas pu lire Annour." : "Dalil couldn't read Annour."
    }

    /// Ce que la voix dit quand le pont échoue : ses phrases à lui quand elles sont faites pour
    /// être entendues (en français), sinon la phrase d'échec. Jamais une ligne technique de claude.
    static func echec(pont message: String, francais: Bool) -> String {
        let connues = [DalilPont.introuvable, DalilPont.muet, DalilPontFlux.sansAcces]
        return francais && connues.contains(message) ? message : echec(francais: francais)
    }

    /// Réglages → Voix : la ligne sur la clé Anthropic ne paraît que si Dalil ne répond pas
    /// (sans Claude Code, la voix retombe sur la clé de l'utilisateur).
    static func cleDemandee(dalilActif: Bool) -> Bool { !dalilActif }

    /// Réponse déjà débarrassée du Markdown (VoiceQuery.spokenText), coupée à `phrasesMax`
    /// phrases et `caracteresMax` caractères, à la fin d'une phrase ou d'un mot.
    static func borne(_ texte: String) -> String {
        var phrases: [String] = []
        var courante = ""
        for c in texte {
            courante.append(c)
            if ".!?…".contains(c) {
                phrases.append(courante)
                courante = ""
            }
        }
        if !courante.trimmingCharacters(in: .whitespaces).isEmpty { phrases.append(courante) }
        var r = phrases.prefix(phrasesMax).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard r.count > caracteresMax else { return r }
        // Trop long : la dernière phrase entière qui tient, sinon le dernier mot entier.
        var tenu = ""
        for p in phrases {
            let essai = (tenu + p)
            if essai.trimmingCharacters(in: .whitespaces).count > caracteresMax { break }
            tenu = essai
        }
        tenu = tenu.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tenu.isEmpty { return tenu }
        r = String(r.prefix(caracteresMax))
        if let espace = r.lastIndex(of: " ") { r = String(r[..<espace]) }
        return r + "…"
    }
}
#endif
