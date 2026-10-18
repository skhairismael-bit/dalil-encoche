import Foundation

/// Finding the `claude` command, shared by the iPhone instructions and Dalil's bridge.
enum ClaudeCLI {
    /// Where `claude` usually lives; the app doesn't get the shell's PATH.
    static func executable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.claude/local/claude",
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/.bun/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// The PATH `claude` needs to find node and its helpers.
    static func path(for claude: String, inherited: String?) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [URL(fileURLWithPath: claude).deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin",
                "/usr/bin", "/bin", "/usr/sbin", "/sbin", "\(home)/.local/bin", inherited ?? ""].joined(separator: ":")
    }
}
