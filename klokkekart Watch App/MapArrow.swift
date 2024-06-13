//
//  MapArrow.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 09/06/2024.
//

import Foundation
import SwiftUI

struct MapArrow : View {
    static let DefaultRotation = 50.0
    
    var bg: Color = Color.gray
    var color: Color = Color.white
    var filled: Bool = false
    var rotation: CGFloat = DefaultRotation
    var action: () -> Void = {}
    
    var body: some View {
            IconButton(
                "Track",
                systemName: filled ? "location.north.fill" : "location.north",
                action: action,
                color: color,
                bg: bg
            )
            .rotationEffect(.degrees(rotation))
    }
}


#Preview {
    HStack {
        MapArrow(bg: .yellow, color: .red, filled: true, rotation: 20.0)
        MapArrow(bg: .yellow, color: .red, filled: false, rotation: 20.0)
    }
}
