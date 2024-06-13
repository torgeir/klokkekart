//
//  IconButton.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct IconButton : View {
    var purpose: String
    var systemName: String
    var color: Color
    var bg: Color
    var action: () -> Void
    init(_ purpose: String,
         systemName: String,
         action: @escaping () -> Void = {},
         color: Color = .white,
         bg: Color = .gray) {
        self.purpose = purpose
        self.systemName = systemName
        self.action = action
        self.color = color
        self.bg = bg
    }
    var body: some View {
        Button(purpose, systemImage: systemName, action: action)
        .font(.custom("", fixedSize: 25))
        .labelStyle(.iconOnly)
        .foregroundColor(color)
        .background(bg)
        .clipShape(Circle())
        .scaleEffect(0.8, anchor: .center)
    }
}

#Preview {
    HStack {
        IconButton("", systemName: "list.bullet")
        IconButton("", systemName: "location")
        IconButton("", systemName: "xmark")
    }
}

