import Foundation

// MARK: - WakePhrase tests (pure functions, no concurrency)

@main
enum WakePhraseTests {

    static var failures = 0

    static func main() {
        // MARK: split — should match

        // Basic wake phrases (no command)
        checkMatch("ok dalil",              WakePhrase.split("ok dalil"),              cmd: "")
        checkMatch("OK DALIL",              WakePhrase.split("OK DALIL"),              cmd: "")
        checkMatch("okay dalil",            WakePhrase.split("okay dalil"),            cmd: "")
        checkMatch("ok daleel",                WakePhrase.split("ok daleel"),                cmd: "")
        checkMatch("ok da lil",             WakePhrase.split("ok da lil"),             cmd: "")
        checkMatch("hey dalil",             WakePhrase.split("hey dalil"),             cmd: "")
        checkMatch("Hey Dalil",             WakePhrase.split("Hey Dalil"),             cmd: "")

        // Command extracted from original text (casing/punctuation preserved)
        checkMatch("Okay, Dalil, ajoute GitHub",
                   WakePhrase.split("Okay, Dalil, ajoute GitHub"),             cmd: "ajoute GitHub")
        checkMatch("ok dalile add github",
                   WakePhrase.split("ok dalile add github"),                    cmd: "add github")
        checkMatch("ok dalil ouvre figma",
                   WakePhrase.split("ok dalil ouvre figma"),                   cmd: "ouvre figma")

        // Apostrophes, hyphens and accents preserved in command
        checkMatch("OK Dalil, mets l'album de Daft Punk",
                   WakePhrase.split("OK Dalil, mets l'album de Daft Punk"),   cmd: "mets l'album de Daft Punk")
        checkMatch("ok dalil qu'est-ce que fait Claude ?",
                   WakePhrase.split("ok dalil qu'est-ce que fait Claude ?"),  cmd: "qu'est-ce que fait Claude ?")

        // Wake anywhere in transcript (word-boundary search)
        checkMatch("euh ok dalil mets de la musique",
                   WakePhrase.split("euh ok dalil mets de la musique"),        cmd: "mets de la musique")
        checkMatch("la chanson dit ok dalil",
                   WakePhrase.split("la chanson dit ok dalil"),                cmd: "") // accepted false positive

        // LAST occurrence wins
        checkMatch("ok dalil search ok dalil play music",
                   WakePhrase.split("ok dalil search ok dalil play music"),   cmd: "play music")

        // Partial word-by-word delivery
        checkNoMatch("ok alone",             WakePhrase.split("ok"))
        checkMatch("ok dalil partial",      WakePhrase.split("ok dalil"),              cmd: "")
        checkMatch("ok dalil with more",    WakePhrase.split("ok dalil mets"),         cmd: "mets")

        // MARK: split — should NOT match
        checkNoMatch("standalone dalil",    WakePhrase.split("dalil"))
        checkNoMatch("standalone DALIL",    WakePhrase.split("DALIL"))
        checkNoMatch("partial dalil ça va", WakePhrase.split("dalil ça va"))
        checkNoMatch("dalil comment",       WakePhrase.split("dalil comment tu vas"))
        checkNoMatch("ok google",            WakePhrase.split("ok google"))
        checkNoMatch("hey siri",             WakePhrase.split("hey siri"))
        checkNoMatch("okkkk dalil",         WakePhrase.split("okkkk dalil"))
        checkNoMatch("empty",                WakePhrase.split(""))

        // Summary
        if failures == 0 { print("\n\(total)/\(total) tests passed.") }
        else { print("\n\(failures) test(s) FAILED."); exit(1) }
    }

    static var total = 0

    static func checkMatch(_ label: String, _ r: WakePhrase.SplitResult, cmd: String) {
        total += 1
        if !r.matched {
            print("✗  \(label) — expected match, got no match"); failures += 1; return
        }
        if r.command != cmd {
            print("✗  \(label) — matched ✓ but command \"\(r.command)\" ≠ \"\(cmd)\""); failures += 1; return
        }
        print("✓  \(label)")
    }

    static func checkNoMatch(_ label: String, _ r: WakePhrase.SplitResult) {
        total += 1
        if r.matched { print("✗  \(label) — expected no match, got matched (cmd: \"\(r.command)\")"); failures += 1 }
        else         { print("✓  \(label)") }
    }
}
