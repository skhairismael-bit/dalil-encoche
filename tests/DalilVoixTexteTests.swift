import Foundation

// « OK Dalil » : consigne de la voix, phrases dites et réponse bornée.

@main
enum DalilVoixTexteTests {
    nonisolated(unsafe) static var echecs = 0
    static func verifier(_ ok: Bool, _ nom: String) {
        if ok { print("ok  \(nom)") } else { echecs += 1; print("ÉCHEC \(nom)") }
    }

    static func main() {
        // Consigne : enfermé dans Annour, fait pour être entendu, dans la langue choisie.
        let fr = DalilVoixTexte.consigne(prenom: "Ismael", francais: true)
        verifier(fr.contains("Dalil") && fr.contains("Ismael"), "consigne nomme Dalil et l'utilisateur")
        verifier(fr.contains("lecture seule") && fr.contains("ni internet"), "consigne : Annour seul, pas d'internet")
        verifier(fr.contains("Réponds en français.") && fr.contains("sans liste"), "consigne : français, sans liste")
        verifier(DalilVoixTexte.consigne(prenom: nil, francais: false).contains("Answer in English."), "consigne anglaise")

        verifier(DalilVoixTexte.attente(francais: true) == "Je regarde dans Annour…", "sous-titre d'attente")
        verifier(DalilVoixTexte.echec(francais: true) == "Dalil n'a pas pu lire Annour.", "phrase d'échec")
        verifier(DalilVoixTexte.echec(francais: false) == "Dalil couldn't read Annour.", "phrase d'échec anglaise")

        // Échecs du pont : ses phrases françaises passent, jamais une ligne technique.
        verifier(DalilVoixTexte.echec(pont: DalilPontFlux.sansAcces, francais: true) == DalilPontFlux.sansAcces, "« plus accès » dit tel quel")
        verifier(DalilVoixTexte.echec(pont: DalilPont.introuvable, francais: true) == DalilPont.introuvable, "« introuvable » dit tel quel")
        verifier(DalilVoixTexte.echec(pont: "API Error: 529 overloaded", francais: true) == "Dalil n'a pas pu lire Annour.", "erreur technique → phrase d'échec")
        verifier(DalilVoixTexte.echec(pont: DalilPont.muet, francais: false) == "Dalil couldn't read Annour.", "en anglais : phrase anglaise")

        // Réponse bornée.
        verifier(DalilVoixTexte.borne("Oui. C'est fait demain.") == "Oui. C'est fait demain.", "réponse courte intacte")
        let longue = "Un. Deux ! Trois ? Quatre. Cinq. Six."
        verifier(DalilVoixTexte.borne(longue) == "Un. Deux ! Trois ? Quatre.", "quatre phrases au plus")
        let phrase = String(repeating: "mot ", count: 60) + "fin. "
        let deux = DalilVoixTexte.borne(phrase + phrase)
        verifier(deux.count <= DalilVoixTexte.caracteresMax, "longueur bornée")
        verifier(deux.hasSuffix("fin."), "coupée à la fin d'une phrase")
        let mur = DalilVoixTexte.borne(String(repeating: "mot ", count: 200))
        verifier(mur.count <= DalilVoixTexte.caracteresMax + 1 && mur.hasSuffix("mot…"), "sans point : coupée au mot, points de suite")
        verifier(DalilVoixTexte.borne("") == "", "vide reste vide")

        // Réglages → Voix : la ligne sur la clé Anthropic disparaît quand Dalil répond.
        verifier(!DalilVoixTexte.cleDemandee(dalilActif: true), "clé non demandée avec Dalil")
        verifier(DalilVoixTexte.cleDemandee(dalilActif: false), "clé demandée sans Claude Code")

        print(echecs == 0 ? "tous les tests passent" : "\(echecs) échec(s)")
        exit(echecs == 0 ? 0 : 1)
    }
}
