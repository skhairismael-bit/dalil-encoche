import Foundation

/// Une enveloppe poussée par le démon d'Annour (scripts/dalil-encoche/ du dépôt annourr) :
/// le type d'événement, le compte, l'heure — jamais un nom ni un numéro de dossier.
struct DalilEnveloppe: Codable, Equatable {
    var texte: String
    var recue: Date
    var vue: Bool
}

/// La boîte aux enveloppes de la pastille « dalil » : récentes en tête, bornée, et
/// « vue » seulement quand Ismael ouvre la liste dans l'île. Pure : le disque est ailleurs
/// (DalilEnveloppesStore). Rien ici ne marque quoi que ce soit « lu » côté Annour.
struct DalilBoite: Codable, Equatable {
    static let plafond = 50
    /// Une enveloppe du démon fait moins de cent caractères ; au-delà, c'est une charge anormale.
    static let texteMax = 200
    static let versionActuelle = 1
    var version: Int = versionActuelle
    var enveloppes: [DalilEnveloppe] = []

    init() {}

    enum CodingKeys: String, CodingKey { case version, enveloppes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.versionActuelle
        enveloppes = try c.decodeIfPresent([DalilEnveloppe].self, forKey: .enveloppes) ?? []
    }

    var nonVues: Int { enveloppes.filter { !$0.vue }.count }

    /// Ajoute en tête ; faux si le texte est vide (rien n'est écrit).
    @discardableResult
    mutating func ajouter(_ texte: String, le date: Date = Date()) -> Bool {
        let propre = String(texte.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.texteMax))
        guard !propre.isEmpty else { return false }
        enveloppes.insert(DalilEnveloppe(texte: propre, recue: date, vue: false), at: 0)
        if enveloppes.count > Self.plafond { enveloppes.removeLast(enveloppes.count - Self.plafond) }
        return true
    }

    mutating func marquerToutesVues() {
        for i in enveloppes.indices { enveloppes[i].vue = true }
    }

    func encoder() -> Data? {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(self)
    }

    static func decoder(_ data: Data) -> DalilBoite? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(DalilBoite.self, from: data)
    }

    /// « 16:42 » au fuseau donné (celui du Mac par défaut).
    static func heure(_ date: Date, fuseau: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.timeZone = fuseau
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
