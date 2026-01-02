//
//  AboutView.swift
//  Frost
//
//  A focus utility for macOS.
//

import SwiftUI

struct AboutView: View {
    private let releaseVersion = Bundle.main.releaseVersionNumber ?? ""
    private let buildVersion = Bundle.main.buildVersionNumber ?? ""

    var body: some View {
        VStack(spacing: 20) {
            // Snowflake icon
            Image(systemName: "snowflake")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                Text("Frost")
                    .font(.system(size: 24))
                    .fontWeight(.bold)

                Text("Focus on what matters")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("Version \(releaseVersion) (\(buildVersion))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Text("Created by")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Button(action: {
                    if let url = URL(string: "https://x.com/ZhengyiShen") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Zhengyi Shen")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Button(action: {
                    if let url = URL(string: "https://github.com/zhengyishen0/blurred-monocle") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("View on GitHub")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Text("MIT License")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .frame(width: 320, height: 320)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
