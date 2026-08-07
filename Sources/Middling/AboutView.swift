import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    private var copyright: String {
        Bundle.main.object(
            forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .padding(.top, 12)

            Text("Middling")
                .font(.title2.bold())

            Text("Hold Fn to drag with the middle mouse button.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(version)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            Text(copyright)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
        .frame(width: 280)
    }
}
