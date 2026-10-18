// Tests de la boîte aux enveloppes de Dalil (pure, sans disque).
import Foundation

@main
enum DalilEnveloppesTests {
    static var echecs = 0
    static func verifier(_ ok: Bool, _ nom: String) {
        if ok { print("ok  \(nom)") } else { echecs += 1; print("ÉCHEC \(nom)") }
    }

    static func main() {
let t0 = Date(timeIntervalSince1970: 1_800_000_000)
var boite = DalilBoite()
verifier(boite.nonVues == 0 && boite.enveloppes.isEmpty, "boîte vide au départ")

boite.ajouter("1 nouveauté dans Annour : 1 vol modifié · 09:00", le: t0)
boite.ajouter("2 nouveautés dans Annour : 2 billets lus · 09:05", le: t0.addingTimeInterval(300))
verifier(boite.nonVues == 2, "deux enveloppes non vues")
verifier(boite.enveloppes.first?.texte.hasPrefix("2 nouveautés") == true, "la plus récente en tête")
verifier(boite.enveloppes.last?.texte.hasPrefix("1 nouveauté") == true, "la plus ancienne en queue")

boite.marquerToutesVues()
verifier(boite.nonVues == 0, "tout vu après ouverture")
verifier(boite.enveloppes.count == 2, "marquer vu ne retire rien")

boite.ajouter("alerte", le: t0.addingTimeInterval(600))
verifier(boite.nonVues == 1, "une nouvelle enveloppe redevient non vue")

var pleine = DalilBoite()
for i in 0..<(DalilBoite.plafond + 7) { pleine.ajouter("e\(i)", le: t0.addingTimeInterval(Double(i))) }
verifier(pleine.enveloppes.count == DalilBoite.plafond, "bornée au plafond")
verifier(pleine.enveloppes.first?.texte == "e\(DalilBoite.plafond + 6)", "la borne garde les récentes")

verifier(boite.ajouter("") == false && boite.enveloppes.count == 3, "texte vide refusé")

let data = boite.encoder()
verifier(data != nil, "encodage JSON")
let relue = data.flatMap { DalilBoite.decoder($0) }
verifier(relue == boite, "aller-retour JSON identique")
verifier(DalilBoite.decoder(Data("pas du json".utf8)) == nil, "JSON illisible = nil, pas de plantage")

var longue = DalilBoite()
longue.ajouter(String(repeating: "x", count: 1000), le: t0)
verifier(longue.enveloppes.first?.texte.count == DalilBoite.texteMax, "texte borné à texteMax")
let sansVersion = DalilBoite.decoder(Data("{\"enveloppes\":[]}".utf8))
verifier(sansVersion?.version == DalilBoite.versionActuelle, "JSON sans version = version actuelle")
verifier(DalilBoite.decoder(Data("{}".utf8))?.enveloppes.isEmpty == true, "JSON vide = boîte vide")

verifier(DalilBoite.resume("2 nouveautés dans Annour : 2 billets lus · 16:42") == "2 billets lus", "résumé : préfixe et heure retirés")
verifier(DalilBoite.resume("1 nouveauté dans Annour : 1 vol modifié · 09:05") == "1 vol modifié", "résumé au singulier")
verifier(DalilBoite.resume("3 nouveautés dans Annour : 2 billets lus, 1 vol modifié · 16:42") == "2 billets lus, 1 vol modifié", "résumé à deux comptes")
verifier(DalilBoite.resume("Dalil n’a plus accès à Annour : relancer autoriser.mjs · 16:42") == "Dalil n’a plus accès à Annour : relancer autoriser.mjs", "alerte : seule l'heure retirée")
verifier(DalilBoite.resume("texte libre") == "texte libre", "texte inconnu rendu tel quel")

let tz = TimeZone(identifier: "Europe/Brussels")!
verifier(DalilBoite.heure(t0, fuseau: tz) == "09:00", "heure courte au fuseau donné (1 800 000 000 s = 15/01/2027 08:00 UTC, +1 en hiver)")

print(echecs == 0 ? "DalilEnveloppes : tout passe" : "DalilEnveloppes : \(echecs) échec(s)")
exit(echecs == 0 ? 0 : 1)
    }
}
