//
//  Tile.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 03/06/2024.
//

import Foundation
import SwiftUI

struct Tile: Identifiable {
    let id = UUID()
    let tilepos: GoogleTilepos
    let z: Int
    let w: Int = tileSize
    let h: Int = tileSize
    var image: UIImage?
    var color: Color? = Color.init(hue: 0.0, saturation: 0.0, brightness: 0.2)
}
