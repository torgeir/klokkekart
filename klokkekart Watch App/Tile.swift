//
//  Tile.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 03/06/2024.
//

import Foundation
import SwiftUI

struct TileKey: Hashable, Identifiable {
    var id: String { "\(z)-\(x)-\(y)-\(size)" }
    let z: Int
    let x: Int
    let y: Int
    let size: Int
}

struct Tile: Identifiable {
    let id: TileKey
    let tilepos: GoogleTilepos
    let z: Int
    let size: Int = tileSize
    var image: UIImage? = nil
    
    init(tilepos: GoogleTilepos, z: Int, image: UIImage? = nil) {
        self.tilepos = tilepos
        self.z = z
        self.id = TileKey(z: z, x: tilepos.tx, y: tilepos.ty, size: size)
        self.image = image
    }
    
    func withImage(image: UIImage) -> Tile {
        Tile(tilepos: tilepos, z: z, image: image)
    }
}
