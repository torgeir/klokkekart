//
//  Copyright.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct Copyright : View {
    var copyright: String
    init(_ copyright: String) {
        self.copyright = copyright
    }
    var body: some View {
        Text(copyright)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .font(.custom("Helvetica Neue", size: 7))
            .padding(1)
            .colorMultiply(.black)
            .background(
                .regularMaterial.blendMode(.screen),
                in: RoundedRectangle(cornerRadius: 3))
    }
}
