//
//  LinkView.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import SwiftUI

struct LinkView: View {
    var imageName: String
    var title: String
    var link: String
    var body: some View {
        HStack {
            Button(action: {
                if let url = URL(string: self.link) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16)
                        .foregroundColor(.primary)
                    
                    Text(title.localized)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }.buttonStyle(LinkButtonStyle())
        }
    }
}

struct LinkView_Previews: PreviewProvider {
    static var previews: some View {
        LinkView(imageName: "ico_compass", title: "About Frost", link: "https://github.com/zhengyishen/frost-app")
    }
}
