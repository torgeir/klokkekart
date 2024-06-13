//
//  ConeOfSight.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 08/06/2024.
//

import Foundation
import SwiftUI


struct Arc: Shape {
    var amount: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let startAngle: Angle = .radians(pi_div_2*max(amount, 0.14))
        let endAngle: Angle = .radians(-pi_div_2*max(amount, 0.14))
        let clockwise: Bool = true

        var path = Path()
        
        // Calculate the center and radius of the arc
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Add the arc to the path
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        path.addLine(to: center)
        path.closeSubpath()
        
        return path
    }
}

struct ConeOfSight : View {
    var amount: CGFloat = 1
    var size = 150.0
    var body: some View {
        Arc(amount: amount)
            .fill(RadialGradient(
                colors: [Color.blue, Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: size / 2.4
            ))
            .frame(width: size, height: size)
            .rotationEffect(.radians(-pi_div_2))
    }
}


#Preview {
    VStack {
        ConeOfSight(amount: 0.1)
        Arc(amount: 0.4)
    }
}
