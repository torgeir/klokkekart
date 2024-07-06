//
//  TileFetcher.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 31/05/2024.
//

import Foundation
import SwiftUI
import Combine

class Wrapper<T: Hashable> : NSObject {
    let value: T
    init(_ _struct: T) {
        value = _struct
    }
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Wrapper else { return false }
        return self.value == other.value
    }
    override var hash: Int {
        return value.hashValue
    }
}
class ImageCache : ObservableObject {
    let cache = NSCache<NSString, UIImage>()
    
    func get(url: NSString) -> UIImage? {
        return cache.object(forKey: url)
    }
    
    func put(url: NSString, image: UIImage) {
        cache.setObject(image, forKey: url)
        objectWillChange.send()
    }
}

class TileFetcher {
    var alreadyFetching = Set<NSString>()
    let cache: ImageCache
    
    let images : PassthroughSubject<TileKey, Never> = .init()
    
    init(cache: ImageCache = ImageCache()) {
        self.cache = cache
    }
        
    func fetchTile(layer: any Layer, tileKey: TileKey, retries: Int = 0) -> Void {
        let url = layer.url(tileKey: tileKey)
        self.alreadyFetching.insert(url)
        
        if let _ = cache.get(url: url) {
            print("found in cache \(tileKey)")
            return self.images.send(tileKey)
        }
        
        if retries > 2 {
            print("gave up fetching \(tileKey)")
            self.alreadyFetching.remove(url)
            return
        }
    
        #if true
        print("fetching \(tileKey)")
        #endif
        
        guard let fetchUrl = URL(string: url as String) else {
            print("error creating url \(tileKey), retry #\(retries + 1)")
            self.alreadyFetching.remove(url)
            return self.fetchTile(layer: layer, tileKey: tileKey, retries: retries + 1)
        }

        URLSession.shared
            .dataTask(with: fetchUrl) { data, response, error in
                if (error != nil) {
                    print("error fetching \(tileKey), retry #\(retries + 1)")
                    self.alreadyFetching.remove(url)
                    return self.fetchTile(layer: layer, tileKey: tileKey, retries: retries + 1)
                }
                guard
                    let data = data,
                    let image = UIImage(data: data) else {
                        print("no image fetching \(tileKey), retry #\(retries + 1)")
                        self.alreadyFetching.remove(url)
                        return self.fetchTile(layer: layer, tileKey: tileKey, retries: retries + 1)
                    }
                
                self.alreadyFetching.remove(url)
                self.cache.put(url: layer.url(tileKey: tileKey), image: image)
                self.images.send(tileKey)
            }
            .resume()
    }
}
