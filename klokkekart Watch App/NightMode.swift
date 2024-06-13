//
//  NightMode.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct NightMode<Content> : View where Content : View {
    var isOn: Bool
    @ViewBuilder var content: () -> Content
    var body: some View {
        if (isOn) {
            content().colorMultiply(.red)
        }
        else {
            content()
        }
    }
}
