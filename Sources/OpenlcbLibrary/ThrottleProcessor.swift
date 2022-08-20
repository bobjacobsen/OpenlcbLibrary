//
//  ThrottleProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

struct ThrottleProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil, model: ThrottleModel) {
        self.linkLayer = linkLayer
        self.model = model
    }
    
    let linkLayer : LinkLayer?
    let model : ThrottleModel
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleProcessor")
    
    let isTrainID = EventID("01.01.00.00.00.00.03.03")
    let isTrainIDarray : [UInt8] = [1,1,0,0,0,0,3,3]
    
    public func process( _ message : Message, _ node : Node  ) {
        
        // Do a fast drop of messages not to us or global - note linklevelup/down are marked as global
        if (!message.mti.isGlobal() && !checkDestID(message, node)) { return }
                
        // specific message handling
        switch message.mti {
        case .Producer_Consumer_Event_Report :
            if message.data == isTrainIDarray {
                logger.debug("eventID matches")
                
                // retain the source ID as a roster entry with the low bits holding the address
                model.roster.append(RosterEntry("\(message.source.nodeId & 0xFFFF)", message.source))
            }
            return
        case .Traction_Control_Reply :
            let subCommand = message.data[0]
            switch subCommand {
            case 0x10:
                // speed message // TODO: decode speed message in IEEE16 / Float16
                return
            case 0x20:
                // function message // TODO: decode function message
                return
            default:
                return // not of interest
            }
        default:
            return
        }
    }
}
