//
//  Components.swift
//  Cirkit
//
//  Created by Baris Akcay on 2.03.2026.
//

import Foundation
import SwiftData

@Model
final class Component {
    var name: String
    var x: Double
    var y: Double
    var value: Double
    var type: String
    var rotation: Double = 0.0
    
    init(name: String, x: Double, y: Double, value: Double = 1000.0, type: String = "Resistor", rotation: Double = 0.0) {
        self.name = name
        self.x = x
        self.y = y
        self.value = value
        self.type = type
        self.rotation = rotation
    }
}
