import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Badge: View {
    let title: LocalizedStringKey
    let on: Bool

    var body: some View {
        Label(title, systemImage: on ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption)
            .foregroundStyle(on ? Color.green : Color.secondary)
    }
}

struct PathRow: View {
    let label: LocalizedStringKey
    @Binding var path: String
    var hint: LocalizedStringKey?
    var hintIsGood = true
    var trailing: (LocalizedStringKey, () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) {
                HStack(spacing: 6) {
                    TextField("", text: $path, prompt: Text("home.default_placeholder"))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                    Button("common.choose", action: choose)
                    Button {
                        Paths.revealInFinder(directory)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("home.reveal")
                    if let (title, action) = trailing {
                        Button(title, action: action)
                    }
                }
            }
            if let hint {
                Label(hint, systemImage: hintIsGood ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(hintIsGood ? Color.secondary : Color.orange)
            }
        }
    }

    private var directory: URL {
        URL(fileURLWithPath: path.isEmpty ? Paths.appSupport.path : path)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

struct FlagRow: View {
    let flag: String
    let description: LocalizedStringKey
    @Binding var isOn: Bool
    var disabled = false
    var warning = false
    var note: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: $isOn) {
                FlagLabel(flag: flag, description: description, warning: warning)
            }
            .disabled(disabled)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
            }
        }
    }
}

/// Looks like a checkbox but behaves as one option of a radio group, matching the engine's mutually exclusive demo flags.
struct DemoRow<Accessory: View>: View {
    let mode: DemoMode
    let flag: String
    let description: LocalizedStringKey
    @Binding var selection: DemoMode
    let accessory: () -> Accessory

    init(
        _ mode: DemoMode,
        flag: String,
        description: LocalizedStringKey,
        selection: Binding<DemoMode>,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.mode = mode
        self.flag = flag
        self.description = description
        _selection = selection
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                isOn: Binding(
                    get: { selection == mode },
                    set: { selection = $0 ? mode : .off }
                )
            ) {
                FlagLabel(flag: flag, description: description)
            }
            accessory()
                .enabled(selection == mode)
                .padding(.leading, 22)
        }
    }
}

struct FileField: View {
    @Binding var path: String
    let placeholder: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $path, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
            Button("common.choose", action: choose)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        // .dmo has no registered UTI, so this falls back to a dynamic type
        panel.allowedContentTypes = [UTType(filenameExtension: "dmo") ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

struct NumberField: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 6) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Stepper("", value: $value, in: 1...999)
                .labelsHidden()
        }
    }
}

private struct FlagLabel: View {
    let flag: String
    let description: LocalizedStringKey
    var warning = false

    var body: some View {
        HStack(spacing: 8) {
            // Text(String) uses the non-localizing initializer, which is what a flag name wants
            Text(flag)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(warning ? Color.orange : Color.primary)
            Text(description)
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    fileprivate func enabled(_ isEnabled: Bool) -> some View {
        disabled(!isEnabled).opacity(isEnabled ? 1 : 0.45)
    }
}
