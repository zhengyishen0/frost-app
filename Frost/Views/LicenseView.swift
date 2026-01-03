//
//  LicenseView.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import SwiftUI
import AppKit

// NSTextField wrapper that properly supports paste
struct PastableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.alignment = .center
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PastableTextField

        init(_ parent: PastableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

struct LicenseView: View {
    @State private var licenseKey: String = ""
    @State private var showError: Bool = false
    @State private var showSuccess: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let isAlreadyLicensed = LicenseManager.shared.isLicensed

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: isAlreadyLicensed ? "checkmark.seal.fill" : "key.fill")
                .font(.system(size: 48))
                .foregroundColor(isAlreadyLicensed ? .green : .primary)

            // Title
            Text(isAlreadyLicensed ? "Licensed" : "Enter License")
                .font(.system(size: 20, weight: .semibold))

            if isAlreadyLicensed {
                // Already licensed view
                VStack(spacing: 12) {
                    Text("Thank you for purchasing Frost!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let storedKey = LicenseManager.shared.storedLicense {
                        Text(storedKey)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            } else {
                // License input view
                VStack(spacing: 16) {
                    // Show trial status
                    if LicenseManager.shared.isTrialActive {
                        Text(LicenseManager.shared.statusText)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    } else {
                        Text("Trial expired")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    Text("Paste your license key below")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    PastableTextField(text: $licenseKey, placeholder: "FROST-SNOW-ICE-CRYSTAL")
                        .frame(width: 280, height: 24)
                        .onChange(of: licenseKey) { _ in
                            showError = false
                            showSuccess = false
                        }

                    if showError {
                        Text("Invalid license key")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    if showSuccess {
                        Text("License activated!")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Activate") {
                            activateLicense()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Divider()
                        .padding(.top, 8)

                    Button(action: {
                        if let url = URL(string: "https://buy.stripe.com/00w14ndAA3hv2p8duv5EY04") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Purchase License")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(30)
        .frame(width: 340, height: isAlreadyLicensed ? 220 : 360)
    }

    private func activateLicense() {
        if LicenseManager.shared.activate(key: licenseKey) {
            showSuccess = true
            showError = false
            // Close window after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
                // Notify that license status changed
                NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
            }
        } else {
            showError = true
            showSuccess = false
        }
    }
}

// Notification for license status changes
extension Notification.Name {
    static let licenseStatusChanged = Notification.Name("licenseStatusChanged")
}

struct LicenseView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView()
    }
}
