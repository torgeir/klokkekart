//
//  SettingSightOffset.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct SettingSightOffset : View {
    
    @Binding var adjustment: Double

    var body: some View {
        NavigationStack {
            GeometryReader { reader in
                VStack(alignment: .center) {
                    Explanation("For some activities, like biking or scooting, your watch ends up at an angle to the direction you are moving when the map is oriented. Offset it using the crown.")
                        .aspectRatio(1, contentMode: .fill)
                    Text("\(adjustment, format: .number)°")
                        .padding(2)
                        .frame(alignment: .center)
                    ZStack {
                        ConeOfSight(amount: 0.2, size: 120)
                            .rotationEffect(Angle(degrees: adjustment))
                            .focusable(interactions: .activate)
                            .digitalCrownRotation(
                                detent: $adjustment,
                                from: -180,
                                through: 180,
                                by: 1,
                                sensitivity: .medium,
                                isContinuous: false,
                                isHapticFeedbackEnabled: true,
                                onChange: { _ in },
                                onIdle: { print("adjustment is \(adjustment)") }
                            )
                        Dot(accuracy: 0.7)
                    }
                    .offset(y: -15)
                    .onTapGesture(count: 2, perform: { adjustment = 0 })
                }
                .frame(alignment: .bottom)
            }
        }.navigationTitle("Sight offset angle")
    }
}

#Preview {
    SettingSightOffset(adjustment: .constant(20))
}
