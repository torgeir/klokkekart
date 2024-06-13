//
//  Arrow.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 09/06/2024.
//

import Foundation
import SwiftUI

struct Arrow : Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        // bottom left
        path.move(to:    CGPoint(x: w/7,     y: h))
        // top middle
        path.addLine(to: CGPoint(x: w/2,     y: h - h/3.5))
        // bottom right
        path.addLine(to: CGPoint(x: w - w/7, y: h))
        // inset center
        path.addLine(to: CGPoint(x: w/2,     y: 0))
        // and back to the start
        path.closeSubpath()
        return path
    }
}
