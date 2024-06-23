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
        let urlKey = layer.url(z: zoom, x: x, y: y, tileSize: tileSize)
        preventFetchCache.setObject(urlKey, forKey: urlKey)
        
        return Future { promise in
            
            #if false
            print("fetching \(url)")
            #endif
            
            guard let url = URL(string: urlKey as String) else {
                preventFetchCache.removeObject(forKey: urlKey)
                promise(.success(nil))
                return
            }

            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if (error != nil) {
                    print("ERROR: \(error!)")
                    preventFetchCache.removeObject(forKey: urlKey)
                }
                guard
                    let data = data,
                    let image = UIImage(data: data) else {
                        promise(.success(nil))
                        preventFetchCache.removeObject(forKey: urlKey)
                        return
                    }

                preventFetchCache.removeObject(forKey: urlKey)
                promise(.success(image))
            }

            task.resume()
        }
    }
}
