import SwiftUI
import Combine
import AppKit

struct SmoothScrollConfig: Codable {
    var hostStepPixels: Double = 3
    var hostIntervalMs: Double = 5
    var damping: Double = 0.28
    var maxStepPerFrame: Double = 6
    var minimumOutputMagnitude: Double = 0.4

    func sanitized() -> SmoothScrollConfig {
        var copy = self
        copy.hostStepPixels = max(1, copy.hostStepPixels)
        copy.hostIntervalMs = max(1, copy.hostIntervalMs)
        copy.damping = max(0.01, min(copy.damping, 1.0))
        copy.maxStepPerFrame = max(copy.hostStepPixels, max(1, copy.maxStepPerFrame))
        copy.minimumOutputMagnitude = max(0.1, copy.minimumOutputMagnitude)
        return copy
    }
}

final class ConfigStore: ObservableObject {
    @Published var config: SmoothScrollConfig
    @Published var statusMessage: String = ""

    private static let daemonBundleID = "org.anavi.SmoothScrollDaemon"

    init() {
        config = Self.load()
    }

    private static func configURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let directory = base.appendingPathComponent("SmoothScrollDaemon", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("config.json", isDirectory: false)
    }

    private static func load() -> SmoothScrollConfig {
        let url = configURL()
        guard let data = try? Data(contentsOf: url) else {
            return SmoothScrollConfig()
        }

        do {
            return try JSONDecoder().decode(SmoothScrollConfig.self, from: data).sanitized()
        } catch {
            print("SmoothScrollConfigurator: failed to parse config.json (\(error.localizedDescription)). Using defaults.")
            return SmoothScrollConfig()
        }
    }

    func saveAndRestartDaemon() {
        let sanitized = config.sanitized()
        do {
            let data = try JSONEncoder().encode(sanitized)
            try data.write(to: Self.configURL(), options: .atomic)
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
            return
        }

        let restartResult = restartDaemon()
        switch restartResult {
        case .success:
            statusMessage = "Saved and restarted daemon."
            config = sanitized
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }

    private enum ConfigError: LocalizedError {
        case daemonBinaryMissing
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .daemonBinaryMissing:
                return "Daemon binary not found. Build it first."
            case .launchFailed(let message):
                return "Failed to launch daemon: \(message)"
            }
        }
    }

    private func restartDaemon() -> Result<Void, ConfigError> {
        terminateDaemon()

        let binaryURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Active/Development/General_Projects/anavi/host/mac/SmoothScrollDaemon/.build/release/smooth-scroll-daemon")
        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            return .failure(.daemonBinaryMissing)
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = []

        do {
            try process.run()
            return .success(())
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    private func terminateDaemon() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.daemonBundleID)
        for app in runningApps {
            app.terminate()
        }

        let process = Process()
        process.launchPath = "/usr/bin/pkill"
        process.arguments = ["-f", "smooth-scroll-daemon"]
        try? process.run()
    }
}

@main
struct SmoothScrollConfiguratorApp: App {
    @StateObject private var store = ConfigStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 420, minHeight: 360)
        }
        .windowStyle(.titleBar)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section(header: Text("Scroll delta")) {
                    Stepper(value: $store.config.hostStepPixels, in: 1...64, step: 1) {
                        HStack {
                            Text("Host step (pixels)")
                            Spacer()
                            Text("\(Int(store.config.hostStepPixels))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(value: $store.config.hostIntervalMs, in: 1...16, step: 1) {
                        Text("Interval (ms)")
                    }
                    HStack {
                        Text("Interval (ms)")
                        Spacer()
                        Text("\(Int(store.config.hostIntervalMs))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Smoothing")) {
                    Slider(value: $store.config.damping, in: 0.05...0.6, step: 0.01) {
                        Text("Damping")
                    }
                    HStack {
                        Text("Damping")
                        Spacer()
                        Text(String(format: "%.2f", store.config.damping))
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $store.config.maxStepPerFrame, in: max(store.config.hostStepPixels, 1)...128, step: 1) {
                        HStack {
                            Text("Max step / frame")
                            Spacer()
                            Text(String(format: "%.0f", store.config.maxStepPerFrame))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(value: $store.config.minimumOutputMagnitude, in: 0.1...4, step: 0.1) {
                        Text("Minimum output")
                    }
                    HStack {
                        Text("Minimum output")
                        Spacer()
                        Text(String(format: "%.1f", store.config.minimumOutputMagnitude))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button(action: {
                store.saveAndRestartDaemon()
            }) {
                Text("Save & Restart Daemon")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text(store.statusMessage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
