//
//  Explanation.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct Explanation : View {
    var explanation: String
    init(_ explanation: String) {
        self.explanation = explanation
    }
    var body: some View {
        Text(explanation)
            .foregroundStyle(.gray)
            .font(.system(size: 13))
    }
}

#Preview {
    Explanation("For some activities, like biking or scooting, your watch end up at an angle to the direction you are moving when the map is oriented.")
}
