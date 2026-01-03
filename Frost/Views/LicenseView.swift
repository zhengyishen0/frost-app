//
//  LicenseView.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import SwiftUI

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
                    Text("Paste your license key below")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 260)
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
                        if let url = URL(string: "https://buy.stripe.com/YOUR_STRIPE_LINK") {
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
        .frame(width: 340, height: isAlreadyLicensed ? 220 : 320)
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
