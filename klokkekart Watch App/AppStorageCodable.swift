//
//  AppStorageCodable.swift
//  klokkekart Watch App
//
//  Created by Torgeir Thoresen on 15/06/2024.
//

import Foundation
import SwiftUI

@propertyWrapper
struct AppStorageCodable<T: Codable>: DynamicProperty {
    @AppStorage private var storedData: Data?
    private let key: String
    private let defaultValue: T

    var wrappedValue: T {
        get {
            if let data = storedData, let value = try? JSONDecoder().decode(T.self, from: data) {
                return value
            }
            return defaultValue
        }
        set {
            storedData = try? JSONEncoder().encode(newValue)
        }
    }

    init(key: String, defaultValue: T) {
        self._storedData = AppStorage(key)
        self.key = key
        self.defaultValue = defaultValue
    }
}
