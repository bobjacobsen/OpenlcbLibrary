//
//  ThrottleProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

struct ThrottleProcessor : Processor {
    public init ( _ linkLayer: CanLink? = nil, model: ThrottleModel) {
        self.linkLayer = linkLayer
        self.model = model
    }
    
    let linkLayer : CanLink?
    let model : ThrottleModel
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleProcessor")
    
    let isTrainID = EventID("01.01.00.00.00.00.03.03")
    let isTrainIDarray : [UInt8] = [1,1,0,0,0,0,3,3]
    
    public func process( _ message : Message, _ node : Node  ) {
        
        // Do a fast drop of messages not to us or global - note linklevelup/down are marked as global
        if (!message.mti.isGlobal() && !checkDestID(message, node)) { return }
                
        // specific message handling
        switch message.mti {
        case .Link_Level_Up :
            // link level up, ask for isATrain producers
            let message = Message(mti: .Identify_Producer, source: linkLayer!.localNodeID, data: isTrainIDarray)
            linkLayer?.sendMessage(message)
            return
        case .Producer_Consumer_Event_Report,
                .Producer_Identified_Active,
                .Producer_Identified_Inactive,
                .Producer_Identified_Unknown:
            if message.data == isTrainIDarray {
                logger.debug("eventID matches")
                
                // retain the source ID as a roster entry with the low bits holding the address
                model.roster.append(RosterEntry("\(message.source.nodeId & 0xFFFF)", message.source))
            }
            return
        case .Verified_NodeID :
            // TODO: make sure this has the right node ID
            model.tc_state = .Wait_on_TC_Reply
            let header : [UInt8] = [0x20, 0x01, 0x01]
            let data = header + (linkLayer!.localNodeID.toArray())
            let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                                        destination: model.selected_nodeId, data: data)
            print("\(message)")
            linkLayer!.sendMessage(message)
        case .Traction_Control_Reply :
            let subCommand = TC_Reply_Type(rawValue: message.data[0])
            switch subCommand {
            case .QuerySpeeds:
                // speed message
                let speed : Float16 = Float16(message.data[1] << 8 | message.data[2])
                model.speed = speed // TODO: confirm that this publishes
                return
            case .QueryFunction:
                // function message
                let fn = Int(message.data[3]) // TODO: check for function space in bytes 1,2
                model.fnModels[fn].pressed = (message.data[5] != 0)
                return
            case .ControllerConfig:
                // check combination of message subtype and state
                if model.tc_state == .Wait_on_TC_Reply && message.data[1] == 0x01 {
                    // TODO: check and react to failure flag; now assuming success
                    // TC Assign Controller reply - now selected
                    model.tc_state = .Selected
                    // model.selectedLoco was set at start 
                    model.selected = true
                    
                }
                
            default:
                return // not of interest
            }
        default:
            return
        }
    }
    
    public enum TC_Request_Type : UInt8 {
        case SetSpeed               = 0x00
        case SetFunction            = 0x01
        case EStop                  = 0x02
        case QuerySpeeds            = 0x10
        case QueryFunction          = 0x11
        case ControllerConfig       = 0x20
        case ListenerConfig         = 0x30
        case TractionManagement     = 0x40
    }
    public enum TC_Reply_Type : UInt8 {
        case QuerySpeeds            = 0x10
        case QueryFunction          = 0x11
        case ControllerConfig       = 0x20
        case ListenerConfig         = 0x30
        case TractionManagement     = 0x40
    }
}
