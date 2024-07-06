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

struct TileKeyError : Error {
    let tileKey: TileKey
    let retry: Int
    init(_ tileKey: TileKey, _ retry: Int) {
        self.tileKey = tileKey
        self.retry = retry
    }
}

class TileFetcher {
    var alreadyFetching = Set<NSString>()
    let cache: ImageCache
    
    let images : PassthroughSubject<Result<TileKey, TileKeyError>, Never> = .init()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(cache: ImageCache = ImageCache()) {
        self.cache = cache
    }
        
    func fetchTile(layer: any Layer, tileKey: TileKey, retries: Int = 0) -> Void {
        let url = layer.url(tileKey: tileKey)
        if (self.alreadyFetching.contains(url)) {
            print("already fetching it, bailing.. \(tileKey)")
            return;
        }

        self.alreadyFetching.insert(url)
        
        if let _ = cache.get(url: url) {
            print("found in cache \(tileKey)")
            return self.images.send(.success(tileKey))
        }
        
        if retries > 2 {
            print("failsafe: gave up fetching \(tileKey) the \(retries) time")
            self.alreadyFetching.remove(url)
            return self.images.send(.failure(TileKeyError(tileKey, retries + 1)))
        }
    
        #if true
        if retries > 0 {
            print("retrying \(tileKey), retries \(retries)")
        } else {
            print("fetching \(tileKey)")
        }
        #endif
        
        guard let fetchUrl = URL(string: url as String) else {
            print("error creating url \(tileKey), retry #\(retries + 1)")
            self.alreadyFetching.remove(url)
            return self.images.send(.failure(TileKeyError(tileKey, retries + 1)))
        }

        URLSession.shared
            .dataTaskPublisher(for: fetchUrl)
            .timeout(.seconds(3), scheduler: DispatchQueue.main) {
                URLSession.DataTaskPublisher.Failure(.timedOut)
            }
            .compactMap { UIImage(data: $0.data) }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: {
                    self.alreadyFetching.remove(url)
                    switch $0 {
                    case .finished:
                        print("finished fetching \(tileKey)")
                    case let .failure(err):
                        print("fetched err, description: \(err.localizedDescription)")
                        self.images.send(.failure(TileKeyError(tileKey, retries + 1)))
                    }
                },
                receiveValue: { image in
                    self.cache.put(url: layer.url(tileKey: tileKey), image: image)
                    self.images.send(.success(tileKey))
                })
            .store(in:&cancellables)
    }
}
