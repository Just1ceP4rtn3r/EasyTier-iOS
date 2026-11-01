import SwiftUI
struct CompatibleNavigationStack<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) { NavigationStack { content } }
        else { NavigationView { content }.navigationViewStyle(.stack) }
    }
}
struct CompatibleLabeledContent<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.label = label(); self.content = content() }
    var body: some View { HStack { label; Spacer(minLength: 12); content } }
}
extension CompatibleLabeledContent where Label == Text {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.label = Text(title); self.content = content() }
}
extension CompatibleLabeledContent where Label == Text, Content == Text {
    init(_ title: LocalizedStringKey, value: String) { self.label = Text(title); self.content = Text(value).foregroundColor(.secondary) }
}
extension View {
    func compatibleTextPrompt(_ title: LocalizedStringKey, isPresented: Binding<Bool>, text: Binding<String>, confirmTitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            CompatibleNavigationStack {
                Form { TextField("config_name", text: text).adaptiveNoTextInputAutocapitalization().disableAutocorrection(true) }
                .navigationTitle(title).adaptiveNavigationBarTitleInline()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { isPresented.wrappedValue = false } }
                    ToolbarItem(placement: .confirmationAction) { Button(confirmTitle) { isPresented.wrappedValue = false; action() } }
                }
            }
        }
    }
}
