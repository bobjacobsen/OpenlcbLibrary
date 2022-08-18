//
//  ThrottleModel.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

public class ThrottleModel {
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleModel")

    @Published var speed = 0.0         // for Sliders
    {
        didSet(oldvalue) {
            logger.info("ThrottleModel.speed did change")
        }
    }
    
    @Published var forward = true   // TODO: get initial state from somewhere?
    
    @Published var reverse = false
    
}
