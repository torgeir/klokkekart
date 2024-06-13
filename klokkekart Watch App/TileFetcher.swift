//
//  TileFetcher.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 31/05/2024.
//

import Foundation
import SwiftUI
import Combine

struct TileFetcher {
    
    let layer: any Layer
    let preventFetchCache: NSCache<NSString, NSString>
    
    init(layer: any Layer) {
        self.layer = layer
        self.preventFetchCache = NSCache<NSString, NSString>()
    }
    
    func hasFetchedTile(zoom: Int, x: Int, y: Int) -> Bool {
        let url = layer.url(z: zoom, x: x, y: y, tileSize: tileSize)
        return self.preventFetchCache.object(forKey: url) != nil
    }
    
    func resetPreventFetchCache() {
        self.preventFetchCache.removeAllObjects()
    }
    
    func fetchTile(zoom: Int, x: Int, y: Int, tileSize: Int) -> Future<UIImage?, Never> {
        // don't fetch multiple times at once
        let url = layer.url(z: zoom, x: x, y: y, tileSize: tileSize)
        preventFetchCache.setObject(url, forKey: url)
        
        return Future { promise in
            
            #if DEBUG
            print("fetching \(url)")
            #endif
            
            guard let url = URL(string: url as String) else {
                promise(.success(nil))
                return
            }

            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if (error != nil) {
                    print("ERROR: \(error!)")
                }
                guard
                    let data = data,
                    let image = UIImage(data: data) else {
                        promise(.success(nil))
                        return
                    }

                promise(.success(image))
            }

            task.resume()
        }
    }
}
