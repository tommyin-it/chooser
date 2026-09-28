import AppKit

struct BrowserProfile: Codable, Equatable {
    let browser: Browser
    let directory: String
    let name: String
    var label: String { "\(browser.name) · \(name)" }
}

struct SavedProfile: Codable, Equatable {
    var profile: BrowserProfile
    var isEnabled: Bool = true
    var id: String { "\(profile.browser.rawValue)/\(profile.directory)" }
}

enum BrowserChoice: Equatable {
    case browser(Browser)
    case profile(BrowserProfile)
    var browser: Browser {
        switch self { case .browser(let browser): return browser; case .profile(let profile): return profile.browser }
    }
    var name: String {
        switch self { case .browser(let browser): return browser.name; case .profile(let profile): return profile.name }
    }
}

func chooserChoices(preferred: Browser, extras: [BrowserProfile]) -> [BrowserChoice] {
    [.browser(preferred), .browser(preferred.other)]
        + [preferred, preferred.other].flatMap { browser in extras.filter { $0.browser == browser }.map(BrowserChoice.profile) }
}

enum ProfileCatalog {
    static func root(for browser: Browser) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(browser == .chrome ? "Google/Chrome" : "BraveSoftware/Brave-Browser")
    }
    static func currentProfile(for browser: Browser) -> BrowserProfile? {
        let available = profiles(for: browser)
        if let data = try? Data(contentsOf: root(for: browser).appendingPathComponent("Local State")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let state = json["profile"] as? [String: Any],
           let last = state["last_used"] as? String,
           let profile = available.first(where: { $0.directory == last }) { return profile }
        return available.first(where: { $0.directory == "Default" }) ?? available.first
    }
    static func validDirectory(_ directory: String) -> Bool {
        !directory.isEmpty && directory != "." && directory != ".." && !directory.contains("/") && !directory.contains("\\") && !directory.contains("\0")
    }
    static func profiles(for browser: Browser, root customRoot: URL? = nil) -> [BrowserProfile] {
        let root = customRoot ?? self.root(for: browser)
        guard let data = try? Data(contentsOf: root.appendingPathComponent("Local State")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: [String: Any]] else { return [] }
        return cache.compactMap { directory, info in
            var isDirectory: ObjCBool = false
            guard validDirectory(directory),
                  FileManager.default.fileExists(atPath: root.appendingPathComponent(directory).path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            let name = (info["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? directory
            return BrowserProfile(browser: browser, directory: directory, name: name)
        }.sorted { $0.name == $1.name ? $0.directory < $1.directory : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

final class ProfileLauncher {
    private var processes: [UUID: Process] = [:]
    enum Failure: LocalizedError {
        case missingProfile, missingBrowser
        var errorDescription: String? {
            switch self {
            case .missingProfile: return "Ten profil jest niedostępny. Wybierz istniejący profil w Ustawieniach → Profile."
            case .missingBrowser: return "Nie znaleziono wybranej przeglądarki."
            }
        }
    }
    static func arguments(profile: BrowserProfile, urls: [URL]) -> [String] {
        ["--profile-directory=\(profile.directory)", "--"] + webURLs(urls).map(\.absoluteString)
    }
    func open(_ urls: [URL], profile: BrowserProfile, onError: @escaping (String) -> Void) throws {
        guard !webURLs(urls).isEmpty else { return }
        guard ProfileCatalog.profiles(for: profile.browser).contains(where: { $0.directory == profile.directory }) else { throw Failure.missingProfile }
        guard let app = profile.browser.applicationURL, let executable = Bundle(url: app)?.executableURL else { throw Failure.missingBrowser }
        let process = Process()
        let id = UUID()
        process.executableURL = executable
        // Pass argv directly: never interpret URL text through a shell. Starting
        // the executable forwards these arguments to Chromium's existing process
        // too, unlike NSWorkspace arguments on an already-running application.
        process.arguments = Self.arguments(profile: profile, urls: urls)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.processes[id] = nil
                if process.terminationStatus != 0 {
                    onError("\(profile.browser.name) nie przyjął żądania otwarcia profilu (kod \(process.terminationStatus)).")
                }
            }
        }
        processes[id] = process
        do { try process.run() }
        catch { processes[id] = nil; throw error }
        NSRunningApplication.runningApplications(withBundleIdentifier: profile.browser.bundleID).first?.activate(options: [])
    }
}
