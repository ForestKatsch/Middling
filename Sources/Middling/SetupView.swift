import SwiftUI
import ApplicationServices

final class SetupModel: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published var launchAtLogin = false

    var onOpenSettings: () -> Void = {}
    var onToggleLaunchAtLogin: (Bool) -> Void = { _ in }
    var onDone: () -> Void = {}
}

struct SetupView: View {
    @ObservedObject var model: SetupModel

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 116, height: 116)
                .padding(.top, 20)

            Text("Middling")
                .font(.system(size: 32, weight: .bold))

            Text("Hold Fn to drag with the middle mouse button.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Group {
                if model.trusted {
                    granted
                } else {
                    needsAccess
                }
            }
            .padding(.top, 28)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
        .frame(width: 440)
        .animation(.default, value: model.trusted)
    }

    private var needsAccess: some View {
        VStack(spacing: 14) {
            Text("Middling needs Accessibility access.")

            PillButton("Open System Settings…") { model.onOpenSettings() }

            Text("Turn Middling on in the list. If it is already on, "
                + "turn it off and back on. This window updates automatically.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var granted: some View {
        VStack(spacing: 14) {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body.weight(.medium))

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.onToggleLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.checkbox)

            PillButton("Done") { model.onDone() }
        }
    }
}

private struct PillButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(.quaternary.opacity(0.7)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
