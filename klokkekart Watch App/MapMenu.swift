//
//  MapMenu.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 09/06/2024.
//

import Foundation
import SwiftUI

let menuButtonSize = 40.0

// TODO delete me?
struct MapMenu : View {
    var color: Color = .white
    
    var body: some View {
        let stroke: CGFloat = 1
        ZStack {
            Circle()
                .fill(Color.gray)
                .strokeBorder(Color.white, lineWidth: 0)
                .frame(width: menuButtonSize, height: menuButtonSize, alignment: .center)
            Path { path in
                let w = menuButtonSize
                path.addLines([ CGPoint(x: 0, y: 0),  CGPoint(x: w, y: 0)  ])
                path.addLines([ CGPoint(x: 0, y: menuButtonSize / 4), CGPoint(x: w, y: menuButtonSize / 4) ])
                path.addLines([ CGPoint(x: 0, y: menuButtonSize / 2), CGPoint(x: w, y: menuButtonSize / 2) ])
            }
            .scale(0.45, anchor: .center)
            .offset(x: 0, y: menuButtonSize / 8)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: stroke,
                    lineCap: .round,
                    lineJoin: .miter,
                    miterLimit: 0,
                    dash: [],
                    dashPhase: 0
                ))
            .frame(width: menuButtonSize, height: menuButtonSize, alignment: .center)
        }
    }
}
