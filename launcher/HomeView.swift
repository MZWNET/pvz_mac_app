import AppKit
import SwiftUI

struct HomeView: View {
    @ObservedObject var store: OptionsStore

    private let build = BuildInfo.current

    @State private var importing = false
    @State private var confirmCrash = false
    @State private var alert: AlertMessage?

    init(store: OptionsStore, startupError: Error? = nil) {
        self.store = store
        _alert = State(initialValue: startupError.map { AlertMessage($0, title: localized("error.launch.title")) })
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                header
                if !store.options.resourcesReady { missingAssets }
                directories
                runtimeFlags
                preview
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 640, height: 720)
        .disabled(importing)
        .overlay { if importing { importOverlay } }
        .alert(alert?.title ?? "", isPresented: alertPresented, presenting: alert) { _ in
            Button("common.ok", role: .cancel) {}
        } message: {
            Text($0.message)
        }
        .confirmationDialog("crash.confirm.title", isPresented: $confirmCrash) {
            Button("crash.confirm.enable", role: .destructive) { store.options.crash = true }
            Button("common.cancel", role: .cancel) { store.options.crash = false }
        } message: {
            Text("crash.confirm.message")
        }
    }

    private var header: some View {
        Section {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "PvZ Portable")
                        .font(.title2.weight(.semibold))
                    Text(build.engineVersionFull)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Badge(title: "badge.cheat", on: build.pvzDebug)
                        Badge(title: "badge.fixes", on: build.doFixBugs || build.hasVanilla)
                        Text(build.arch)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var missingAssets: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("home.no_assets.title")
                        .font(.headline)
                    Text("home.no_assets.body")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("home.import", action: runImport)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var directories: some View {
        Section("home.section.directories") {
            PathRow(
                label: "home.resource_dir",
                path: $store.options.resourceDir,
                hint: store.options.resourcesReady ? "home.assets_found" : "home.assets_missing",
                hintIsGood: store.options.resourcesReady,
                trailing: ("home.reimport", runImport)
            )
            PathRow(
                label: "home.save_dir",
                path: $store.options.saveDir,
                hint: store.options.saveDir.isEmpty ? "home.save_dir.default" : nil
            )

            if build.hasVanilla {
                Picker("home.engine", selection: $store.options.useVanillaEngine) {
                    Text("home.engine.fixed").tag(false)
                    Text("home.engine.vanilla").tag(true)
                }
                .pickerStyle(.radioGroup)
                Text("home.engine.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var runtimeFlags: some View {
        Section("home.section.flags") {
            FlagRow(
                flag: "-cheat",
                description: "flag.cheat.desc",
                isOn: $store.options.cheat,
                disabled: !build.pvzDebug,
                note: build.pvzDebug ? nil : "flag.cheat.unavailable"
            )
            FlagRow(
                flag: "-screensaver",
                description: "flag.screensaver.desc",
                isOn: $store.options.screensaver
            )

            DemoRow(.record, flag: "-record", description: "flag.record.desc", selection: $store.options.demoMode) {
                FileField(path: $store.options.recordPath, placeholder: "flag.record.placeholder")
            }
            DemoRow(.recnum, flag: "-recnum", description: "flag.recnum.desc", selection: $store.options.demoMode) {
                NumberField(value: $store.options.recordKeep)
            }
            DemoRow(.play, flag: "-play", description: "flag.play.desc", selection: $store.options.demoMode) {
                FileField(path: $store.options.playPath, placeholder: "flag.play.placeholder")
            }
            DemoRow(.playnum, flag: "-playnum", description: "flag.playnum.desc", selection: $store.options.demoMode) {
                NumberField(value: $store.options.playIndex)
            }

            FlagRow(
                flag: "-crash",
                description: "flag.crash.desc",
                isOn: Binding(
                    get: { store.options.crash },
                    set: { wantsOn in
                        if wantsOn { confirmCrash = true } else { store.options.crash = false }
                    }
                ),
                warning: true
            )

            LabeledContent("home.extra_args") {
                TextField("", text: $store.options.extraArguments, prompt: Text("home.extra_args.placeholder"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
            Text("home.extra_args.note")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preview: some View {
        Section("home.section.preview") {
            Text(store.options.commandLinePreview)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("home.skip", isOn: $store.options.skipHome)
                .help("home.skip.help")
            Spacer()
            Button("home.quit") { NSApp.terminate(nil) }
            Button("home.start", action: launch)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var importOverlay: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.85)
            VStack(spacing: 10) {
                ProgressView()
                Text("home.importing")
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }

    private var alertPresented: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }

    private func launch() {
        do {
            try EngineLauncher.exec(store.options)
        } catch {
            alert = AlertMessage(error, title: localized("error.launch.title"))
        }
    }

    private func runImport() {
        guard let source = ResourceImporter.chooseSource() else { return }

        let destination = store.options.resourceDirURL
        importing = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try ResourceImporter.importResources(from: source, into: destination)
                }.value
            } catch {
                alert = AlertMessage(error, title: localized("error.import.title"))
            }
            importing = false
        }
    }
}

/// Both fields are already localized — Text(String) does not consult the strings table.
struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: Error, title: String) {
        self.title = title
        message = error.localizedDescription
    }
}
