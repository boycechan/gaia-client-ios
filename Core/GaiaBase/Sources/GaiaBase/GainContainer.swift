//
//  GainContainer.swift
//  
//
//  Created by Stephen Flack on 12/10/2023.
//

import Foundation

public struct GainContainer {
    public struct Value {
        public let gain: UInt8
        public let totalGain: Float?
        public init(gain: UInt8, totalGain: Float?) {
            self.gain = gain
            self.totalGain = totalGain
        }
    }
    public struct Instance {
        public let left: Value
        public let right: Value
        public init(left: Value, right: Value) {
            self.left = left
            self.right = right
        }
    }
    
    public let instances: [Instance]
    
    public init(instances: [Instance]) {
        self.instances = instances
    }
    
    public var leftValues: [Value] {
        return instances.map { $0.left }
    }
    
    public var rightValues: [Value] {
        return instances.map { $0.right }
    }
}
