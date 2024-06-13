//
//  Dot.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI


struct Dot : View {
    
    @State var accuracy: Double
    
    var body: some View {
        
        // >=1000meters -> maximum 60
        // approaching 0 -> minimum 20
        let dotSize = (
            accuracy > 0
            ? 20.0 + max(min(accuracy, 1000.0), 0.0)/1000*40
            : 60.0
        )

        // >=1000meters -> 0.3
        // approaching 0 -> 1
        let dotOpacity = (
            accuracy > 0
            ? max(0.3, 1 - max(min(accuracy, 1000.0), 0.0)/1000)
            : 0.3
        )
        
        Circle()
            .fill(Color.blue.opacity(dotOpacity))
            .strokeBorder(Color.white, lineWidth: 2)
            .frame(width: dotSize, height: dotSize, alignment: .center)
    }
}

