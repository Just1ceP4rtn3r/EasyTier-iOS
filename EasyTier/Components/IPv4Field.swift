import SwiftUI

@available(iOS 15, macOS 12, *)
struct ModernIPv4Field: View {
#if os(iOS)
    @AppStorage("plainTextIPInput") var plainTextIPInput: Bool = false
#else
    let plainTextIPInput = true
#endif
    @Binding var ipAddress: String
    
    var length: Binding<String>?
    var disabledLengthEdit: Bool
    
    @FocusState private var focusedField: Int?
    @State private var octets: [String] = ["", "", "", ""]
    
    init(ip: Binding<String>, length: Binding<String>? = nil, disabledLengthEdit: Bool = false) {
        self._ipAddress = ip
        self.length = length
        self.disabledLengthEdit = disabledLengthEdit
    }

    var body: some View {
        HStack(spacing: 0) {
            if plainTextIPInput {
                TextField("0.0.0.0", text: $ipAddress)
                    .labelsHidden()
                    .decimalKeyboardType()
                    .multilineTextAlignment(.trailing)
                    .font(.system(.body, design: .monospaced))
            } else {
#if os(iOS)
                ForEach(0..<4, id: \.self) { index in
                    ipTextField(index: index)
                    
                    if index < 3 {
                        Text(".")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 1)
                            .padding(.bottom, 2)
                    }
                }
#endif
            }
            
            if let lengthBinding = length {
                Text("/")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, plainTextIPInput ? 8 : 2)
                    .padding(.bottom, 2)
                
                if plainTextIPInput {
                    TextField("32", text: lengthBinding)
                        .labelsHidden()
                        .disabled(disabledLengthEdit)
                        .numberKeyboardType()
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: false)
                        .font(.system(.body, design: .monospaced))
                } else {
#if os(iOS)
                    TextField("32", text: Binding(
                        get: { lengthBinding.wrappedValue },
                        set: { processLengthInput($0, binding: lengthBinding) }
                    ))
                    .disabled(disabledLengthEdit)
                    .numberKeyboardType()
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .focused($focusedField, equals: 4)
                    .font(.system(.body, design: .monospaced))
#endif
                }
            }
        }
        .onAppear {
            syncOctetsFromExternal()
        }
        .onChange(of: ipAddress) { newValue in
            if octets.joined(separator: ".") != newValue {
                syncOctetsFromExternal()
            }
        }
        .onDisappear {
            focusedField = nil
        }
    }
    
#if os(iOS)
    private func ipTextField(index: Int) -> some View {
        TextField("0", text: Binding(
            get: { octets[index] },
            set: { processOctetInput(oldValue: octets[index], newValue: $0, at: index) }
        ))
        .keyboardType(index < 3 ? .decimalPad : .numberPad)
        .multilineTextAlignment(.center)
        .frame(minWidth: 30, maxWidth: 45)
        .focused($focusedField, equals: index)
        .font(.system(.body, design: .monospaced))
    }
#endif
    
    @MainActor
    private func setFocusedField(_ field: Int?) {
        focusedField = field
    }

    private func processOctetInput(oldValue: String, newValue: String, at index: Int) {
        if oldValue == newValue { return }

        if length != nil && newValue.contains("/") {
            if newValue.count > 4 {
                parseAndDistribute(fullString: newValue)
                return
            }
            if !octets[index].isEmpty {
                octets[index] = newValue.replacingOccurrences(of: "/", with: "")
                updateIPBinding()
                setFocusedField(4)
                return
            }
        }

        if newValue.contains(".") {
            if newValue.split(separator: ".").count > 1 {
                parseAndDistribute(fullString: newValue)
                return
            }
            if !octets[index].isEmpty && index < 3 {
                octets[index] = newValue.replacingOccurrences(of: ".", with: "")
                updateIPBinding()
                setFocusedField(index + 1)
                return
            }
        }

        let filtered = newValue.filter { "0123456789".contains($0) }

        if filtered.isEmpty && !octets[index].isEmpty {
            octets[index] = ""
            updateIPBinding()
            if index > 0 { setFocusedField(index - 1) }
            return
        }

        if let num = Int(filtered) {
            octets[index] = String(max(min(num, 255), 0))

            if filtered.count >= 3 {
                setFocusedField(index + 1)
            }
            updateIPBinding()
        }
    }

    private func processLengthInput(_ newValue: String, binding: Binding<String>) {
        if newValue.isEmpty && !binding.wrappedValue.isEmpty {
            binding.wrappedValue = ""
            setFocusedField(3)
            return
        }

        let filtered = newValue.filter { "0123456789".contains($0) }

        if let num = Int(filtered) {
            binding.wrappedValue = String(max(min(num, 32), 0))
        } else if filtered.isEmpty {
            binding.wrappedValue = ""
        }
    }

    private func updateIPBinding() {
        self.ipAddress = octets.map {
            if let num = Int($0) {
                String(max(min(num, 255), 0))
            } else { "" }
        }.joined(separator: ".")
    }

    private func syncOctetsFromExternal() {
        let parts = ipAddress.split(separator: ".")
        for (i, part) in parts.enumerated() {
            if i < 4 { octets[i] = String(part) }
        }
        if ipAddress.isEmpty {
            octets = ["", "", "", ""]
        }
    }

    private func parseAndDistribute(fullString: String) {
        let components = fullString.split(separator: "/")

        if components.count > 0 {
            let ipPart = String(components[0])
            let validIpChars = ipPart.filter { "0123456789.".contains($0) }
            self.ipAddress = validIpChars

            let parts = validIpChars.split(separator: ".").map {
                if let num = Int($0) {
                    String(max(min(num, 255), 0))
                } else { "" }
            }
            for (i, part) in parts.enumerated() {
                if i < 4 { octets[i] = String(part.prefix(3)) }
            }
        }

        if let lengthBinding = length, components.count > 1 {
            let lengthPart = String(components[1]).prefix(2)
            if let num = Int(lengthPart) {
                lengthBinding.wrappedValue = String(max(min(num, 32), 0))
            }
        }

        if components.count > 1 && length != nil {
            setFocusedField(4)
        } else {
            setFocusedField(3)
        }
    }
}

struct IPv4Field: View {
 @Binding var ipAddress: String
 var length: Binding<String>?
 var disabledLengthEdit: Bool
 init(ip: Binding<String>, length: Binding<String>? = nil, disabledLengthEdit: Bool = false) { _ipAddress=ip; self.length=length; self.disabledLengthEdit=disabledLengthEdit }
 var body: some View {
  if #available(iOS 15, macOS 12, *) { return AnyView(ModernIPv4Field(ip: $ipAddress, length: length, disabledLengthEdit: disabledLengthEdit)) }
  return AnyView(HStack { TextField("0.0.0.0", text: $ipAddress).decimalKeyboardType(); if let length { Text("/"); TextField("32", text: length).numberKeyboardType().disabled(disabledLengthEdit) } })
 }
}
