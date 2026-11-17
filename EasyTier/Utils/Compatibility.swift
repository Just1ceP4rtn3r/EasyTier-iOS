import SwiftUI

#if os(iOS)
    let ToolbarLeading = ToolbarItemPlacement.navigationBarLeading
    let ToolbarTrailing = ToolbarItemPlacement.navigationBarTrailing
#else
    let ToolbarLeading = ToolbarItemPlacement.navigation
    let ToolbarTrailing = ToolbarItemPlacement.primaryAction
#endif

extension View {
    func decimalKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.decimalPad)
#else
        return self
#endif
    }
    
    func numberKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.numberPad)
#else
        return self
#endif
    }
    
    func adaptiveNavigationBarTitleInline() -> some View {
#if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
#else
        return self
#endif
    }
    
    func adaptiveNoTextInputAutocapitalization() -> some View {
#if os(iOS)
        return self.autocapitalization(.none)
#else
        return self
#endif
    }
}


struct CompatNavigationStack<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 16, macOS 13, *) { return AnyView(NavigationStack { content }) }
        else {
#if os(iOS)
            return AnyView(NavigationView { content }.navigationViewStyle(StackNavigationViewStyle()))
#else
            return AnyView(NavigationView { content })
#endif
        }
    }
}
struct CompatLabeledContent<Content: View, Label: View>: View {
    let content: Content
    let label: Label
    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.content = content(); self.label = label() }
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text { self.content = content(); self.label = Text(title) }
    init(_ title: LocalizedStringKey, value: String) where Label == Text, Content == Text { self.content = Text(value); self.label = Text(title) }
    var body: some View { HStack { label; Spacer(); content } }
}

extension View {
 func compatTextSelection() -> AnyView {
  if #available(iOS 15, macOS 12, *) { return AnyView(self.textSelection(.enabled)) }
  return AnyView(self)
 }
}

struct CompatButtonStyle: ButtonStyle {
 func makeBody(configuration: Configuration) -> some View {
  configuration.label.padding(8).foregroundColor(.white).background(Color.accentColor.opacity(configuration.isPressed ? 0.5 : 1)).cornerRadius(8)
 }
}
private struct CompatTaskModifier<ID: Equatable>: ViewModifier {
 let id: ID
 let action: () async -> Void
 @State private var task: Task<Void, Never>?
 func body(content: Content) -> some View {
  content.onAppear(perform: restart).onChange(of: id) { _ in restart() }.onDisappear { task?.cancel(); task = nil }
 }
 private func restart() { task?.cancel(); task = Task { await action() } }
}
extension View {
 func compatTask<ID: Equatable>(id: ID, _ action: @escaping () async -> Void) -> some View { modifier(CompatTaskModifier(id: id, action: action)) }
 func compatTask(_ action: @escaping () async -> Void) -> some View { compatTask(id: true, action) }
 func compatDismissKeyboard() -> AnyView {
  if #available(iOS 16, macOS 13, *) { return AnyView(self.scrollDismissesKeyboard(.immediately)) }
  return AnyView(self)
 }
 func compatTextPrompt(_ title: LocalizedStringKey, isPresented: Binding<Bool>, text: Binding<String>, confirm: LocalizedStringKey, action: @escaping () -> Void) -> some View {
  sheet(isPresented: isPresented) {
   NavigationView {
    Form { TextField("config_name", text: text).adaptiveNoTextInputAutocapitalization() }
     .navigationTitle(title)
     .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { isPresented.wrappedValue = false } }
      ToolbarItem(placement: .confirmationAction) { Button(confirm) { isPresented.wrappedValue = false; action() } }
     }
   }
  }
 }
}

struct CompatTitleIconStyle: LabelStyle { func makeBody(configuration: Configuration) -> some View { HStack { configuration.icon; configuration.title } } }


extension View {
    // iOS 14.0–14.4 only honors the last presentation modifier on one view.
    // Give each presentation a separate anchor so all buttons remain usable.
    func compatSheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        background(Color.clear.frame(width: 0, height: 0).sheet(isPresented: isPresented, onDismiss: onDismiss, content: content))
    }
    func compatSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        background(Color.clear.frame(width: 0, height: 0).sheet(item: item, onDismiss: onDismiss, content: content))
    }
    func compatAlert(isPresented: Binding<Bool>, content: @escaping () -> Alert) -> some View {
        background(Color.clear.frame(width: 0, height: 0).alert(isPresented: isPresented, content: content))
    }
    func compatAlert<Item: Identifiable>(item: Binding<Item?>, content: @escaping (Item) -> Alert) -> some View {
        background(Color.clear.frame(width: 0, height: 0).alert(item: item, content: content))
    }
}
