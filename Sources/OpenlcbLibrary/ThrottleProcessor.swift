//
//  ThrottleProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

// Float16 not supported on Intel macOS and Rosetta.  See e.g. https://github.com/SusanDoggie/Float16 and https://forums.swift.org/t/float16-for-macos-and-older-version-of-ios/40572

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
    
    public func process( _ message : Message, _ node : Node  ) -> Bool {
        
        // Do a fast drop of messages not to us or global - note linkLayer up/down are marked as global
        if (!message.mti.isGlobal() && !checkDestID(message, node)) { return false }
                
        // specific message handling
        switch message.mti {
        case .Link_Layer_Up :
            // link layer up, ask for isATrain producers
            let request = Message(mti: .Identify_Producer, source: linkLayer!.localNodeID, data: isTrainIDarray)
            linkLayer?.sendMessage(request)
            return false
        case .Producer_Consumer_Event_Report:
            // check for isTrain event and handle
            processPossibleTrainEvent(message)
            return false
        case    .Producer_Identified_Active,
                .Producer_Identified_Inactive,
                .Producer_Identified_Unknown:
            
            // check for isTrain event and handle
            processPossibleTrainEvent(message)
            
            // check for Traction Search reply event
            // make sure in right state
            if model.tc_state == .Wait_on_TC_Search_reply {
                // make sure this has the right query string
                if model.queryEventID == EventID(message.data) {
                    // now have the node ID on message.source, need to store it away
                    model.selected_nodeId = message.source
                    
                    // next step, send the TC_Control_Command to assign the locomotive to here
                    model.tc_state = .Wait_on_TC_Assign_Reply
                    let header : [UInt8] = [0x20, 0x01, 0x01]
                    let data = header + (linkLayer!.localNodeID.toArray())
                    let command = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                                          destination: model.selected_nodeId, data: data)
                    linkLayer!.sendMessage(command)
                }
            }
        case .Traction_Control_Reply :
            let subCommand = TC_Reply_Type(rawValue: message.data[0])
            switch subCommand {
            case .QuerySpeeds:
                // speed message - convert from bytes to Float16
                // https://stackoverflow.com/questions/36812583/how-to-convert-a-float-value-to-byte-array-in-swift
                // See code in https://gist.github.com/codelynx/eeaeeda00828568aaf577c0341964c38
                let alignedBytes : [UInt8] = [message.data[2], message.data[1]]
                let speed = alignedBytes.withUnsafeBytes {
                    $0.load(fromByteOffset: 0, as: Float16.self)
                }

                model.speed = abs(speed)
                if (message.data[1] & 0x80 == 0) {  // explicit check of sign bit
                    model.forward = true
                    model.reverse = false
                } else {
                    model.forward = false
                    model.reverse = true
                }
                
                return false
            case .QueryFunction:
                // function message
                // Only work with main F0-Fn, so check for that
                if message.data[1] != 0 || message.data[2] != 0 {
                    // not, so this is not for us
                    return false
                }
                let fn = Int(message.data[3])
                model.fnModels[fn].pressed = (message.data[5] != 0)
                return false
            case .ControllerConfig:
                // check combination of message subtype and state
                if model.tc_state == .Wait_on_TC_Assign_Reply && message.data[1] == 0x01 {
                    // TODO: check and react to failure flag; now assuming success
                    // TC Assign Controller reply - now selected
                    model.tc_state = .Selected
                    model.selectedLoco = model.requestedLocoID // display requested loco in the View
                    model.selected = true
                    model.showingSelectSheet = false // reset the selection sheet, closing it
                    // Make sure there's a roster entry
                    model.addToRoster(item: RosterEntry(label: model.requestedLocoID, nodeID: model.selected_nodeId, labelSource: .TCAssignReply))
                    // Send query for speed and functions
                    var reply = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                                    destination: model.selected_nodeId, data: [0x10])  // query speed
                    linkLayer!.sendMessage(reply)
                    for fn in 0...model.maxFn {
                        reply = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                                            destination: model.selected_nodeId, data: [0x11, 0x00, 0x00, UInt8(fn)])  // query function
                        linkLayer!.sendMessage(reply)
                    }
                }
            case .TractionManagement :
                // check for heartbeat request
                if message.data[1] == 0x03 {
                    // send no-op
                    let heartbeat = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                                          destination: model.selected_nodeId, data: [0x40, 0x03])
                    linkLayer!.sendMessage(heartbeat)
                }
            default:
                return false // not of interest
            }
        default:
            return false
        }
        return false
    }
    
    func processPossibleTrainEvent(_ message : Message) {
        if message.data == isTrainIDarray {
            // retain the source ID as a roster entry with the low bits holding the address
            model.addToRoster(item: model.createRosterEntryFromNodeID(for: message.source))
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
