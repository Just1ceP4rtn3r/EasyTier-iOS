import SwiftUI

struct AdaptiveNavigation<PrimaryView, SecondaryView, Enum>: View where PrimaryView: View, SecondaryView: View, Enum: Identifiable & Hashable {
#if os(macOS)
    let sizeClass = UserInterfaceSizeClass.compact
#else
    @Environment(\.horizontalSizeClass) var sizeClass
#endif
    @ViewBuilder var primaryColumn: PrimaryView
    @ViewBuilder var secondaryColumn: SecondaryView
    @Binding var showNav: Enum?
    
    init(_ primary: PrimaryView, _ secondary: SecondaryView, showNav: Binding<Enum?>) {
        primaryColumn = primary
        secondaryColumn = secondary
        _showNav = showNav
    }
    
    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    primaryColumn
                        .frame(maxWidth: columnMaxWidth)
                    secondaryColumn
                }
            } else {
                primaryColumn
            }
        }
        .adaptiveNavigationDestination(item: (sizeClass == .compact ? $showNav : .constant(nil)), destination: { secondaryColumn })
    }
}

extension View {
    func adaptiveNavigationDestination<Enum: Identifiable & Hashable, Destination: View>(
        item: Binding<Enum?>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> AnyView {
        let presented = Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        if #available(iOS 17, macOS 14, *) { return AnyView(self.navigationDestination(item: item) { _ in destination() }) }
        if #available(iOS 16, macOS 13, *) { return AnyView(self.navigationDestination(isPresented: presented, destination: destination)) }
        return AnyView(self.background(NavigationLink(destination: destination(), isActive: presented) { EmptyView() }))
    }
}
