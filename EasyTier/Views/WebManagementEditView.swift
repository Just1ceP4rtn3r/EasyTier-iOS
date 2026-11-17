import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct WebManagementEditView: View {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var server: String
    @Binding var hostname: String
    @Binding var machineID: String
    @Binding var secureMode: Bool

    let onSave: () -> Void

    @State private var showResetMachineIDAlert = false

    var body: some View {
        Form {
            Section {
                CompatLabeledContent("web_management.server.placeholder") {
                    TextField(
                        "tcp://et-web.console.easytier.net:22020/your_token",
                        text: $server
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .adaptiveNoTextInputAutocapitalization()
                    .disableAutocorrection(true)
                }
                CompatLabeledContent("hostname") {
                    TextField(
                        "common_text.default",
                        text: $hostname
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                }
                Toggle("web_management.secure_mode", isOn: $secureMode)
                    .onChange(of: secureMode) { _ in onSave() }
            } header: {
                Text("web_management.title")
            } footer: {
                Text("web_management.secure_mode_help")
            }
            Section(header: Text("web_management.machine_id")) {
                CompatLabeledContent {
                    Button(action: copyMachineID) {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("web_management.machine_id.copy")
                } label: {
                    Text(machineID).font(.system(.caption, design: .monospaced))
                        .compatTextSelection()
                }
                Button("web_management.machine_id.reset") {
                    showResetMachineIDAlert = true
                }
            }
        }

        .compatAlert(isPresented: $showResetMachineIDAlert) {
            Alert(title: Text("web_management.machine_id.reset_confirm_title"), message: Text("web_management.machine_id.reset_confirm_message"), primaryButton: .destructive(Text("reset")) {
                guard isEnabled else { return }
                machineID = UUID().uuidString.lowercased()
                onSave()
            }, secondaryButton: .cancel())
        }
    }

    private func copyMachineID() {
#if os(iOS)
        UIPasteboard.general.string = machineID
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(machineID, forType: .string)
#endif
    }
}
