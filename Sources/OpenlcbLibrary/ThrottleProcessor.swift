//
//  ThrottleProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

struct ThrottleProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    
    let linkLayer : LinkLayer?
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleProcessor")
    
    let isTrainID = EventID("01.01.00.00.00.00.03.03")
    
    public func process( _ message : Message, _ node : Node  ) {
        
        // Do a fast drop of messages not to us, from us, or global - note linklevelup/down are marked as global
        if (!message.mti.isGlobal() && !checkSourceID(message, node) && !checkDestID(message, node)) { return }
                
        // specific message handling
        switch message.mti {
        case .Producer_Consumer_Event_Report :
            
            // TODO: detect and retain references to the isTrain event ID
            return
        default:
            return
        }
    }
}
