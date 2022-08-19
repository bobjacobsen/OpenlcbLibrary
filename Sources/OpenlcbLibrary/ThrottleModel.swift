//
//  ThrottleModel.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

public class ThrottleModel : ObservableObject {
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleModel")
    // Data to construct a throttle
    
    @Published public var speed : Float16 = 0.0 {
        didSet(speed) {
            sendSetSpeed(to: speed)
        }
    }

    @Published public var forward = true   // TODO: get initial state from somewhere?
    @Published public var reverse = false

    // Operations methods
    public func sendSetSpeed(to: Float16) {
        print ("sendSetSpeed to \(to)")
    }

    let maxFn = 28
    @Published public var fnModels : [FnModel] = []  // TODO: associate these with state from throttle
    
    public init() {
        for index in 0...maxFn {
            // default fn labels are just the numbers
            fnModels.append(FnModel("\(index)"))
        }
        fnModels[2].momentary = true
        
        logger.debug("init of ThrottleModel")
    }

    var trainNodes  = Set<NodeID>([])
}

// Data to construct a single function button
public class FnModel : ObservableObject {
    public let label : String
    public let id = UUID()
    @Published public var pressed : Bool = false {
        didSet(pressed) {
            sendFunctionSet(to: pressed)
        }
    }
    @Published public var momentary : Bool = false
    
    public init(_ label : String) {
        self.label = label
    }
    public func sendFunctionSet(to: Bool) {
        print ("sendFunctionSet \(label) \(to)")
    }
}
