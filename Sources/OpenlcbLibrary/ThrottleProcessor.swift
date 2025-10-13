//
//  ThrottleProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

// Float16 not supported on macOS Rosetta.  Hence we use our own `float16ToFloat` conversion routine, see the bottom of the file.

/// Process messages for the ``ThrottleModel``
struct ThrottleProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil, model: ThrottleModel) {
        self.linkLayer = linkLayer
        self.model = model
    }
    
    let linkLayer : LinkLayer?
    let model : ThrottleModel
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleProcessor")
    
    let isTrainID = EventID("01.01.00.00.00.00.03.03")
    let isTrainIDarray : [UInt8] = [1,1,0,0,0,0,3,3]
    
    /// Received a speed update message from the command station, update speed
    /// - Parameter message: speed-containing Command or Reply message
    fileprivate func handleSpeedMessage(_ message: Message) {
        // speed message - convert from bytes to Float16
        let alignedBytes : [UInt8] = [message.data[2], message.data[1]]
        
        let mpsSpeed = float16ToFloat(alignedBytes)
        
        // compute updated speed and direction bits
        let nextMphSpeed = round(abs(mpsSpeed / ThrottleModel.mps_per_MPH))
        
        var nextForward = true
        var nextReverse = false
        if (message.data[1] & 0x80 != 0) {  // explicit check of sign bit
            nextForward = false
            nextReverse = true
        }
        
        // remember the current speed settings
        let currentSettings = model.speedSettings
        
        // wait a bit, then update if the current conditions have not changed.
        // this is done to damp down race condition between multiple throttles.
        let deadlineTime = DispatchTime.now() + .milliseconds(100)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            
            if model.speedSettings == currentSettings {
                // objective conditions have not changed, do the update
                let newSettings = SpeedAndDirection(nextMphSpeed, nextForward, nextReverse)
                model.lastSpeedSettings = newSettings // no differene, no message send
                model.speedSettings = newSettings
            } else {
                ThrottleProcessor.logger.trace("skipping speed update as model.speed has changed")
            }
        }
        
        
    }
    
    /// Received a function update message from command station, update appropriate function value
    fileprivate func handleFunctionMessage(_ message: Message) {
        // function message
        // Only work with main F0-Fn, so check for that
        if message.data[1] != 0 || message.data[2] != 0 {
            // not, so this is not for us
            return
        }
        let fn = Int(message.data[3])
        if fn > model.maxFn {
            // not set up to handle this, ignore
            return
        }
        let capturedN = fn
        let capturedState = model.fnModels[fn].pressed
        let nextState = (message.data[5] != 0)
        
        // not a change, no action
        if (nextState == capturedState) { return }
        
        // wait a bit, then update if the current conditions have not changed.
        // this is done to damp down race condition between multiple throttles.
        let deadlineTime = DispatchTime.now() + .milliseconds(100)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            if model.fnModels[fn].pressed == capturedState {
                // objective conditions have not changed, do the update
                model.fnModels[capturedN].pressed = nextState
            } else {
                ThrottleProcessor.logger.trace("skipping function update as fn \(capturedN, privacy: .public) has changed")
            }
        }

        
    }
    
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

                    model.setUpMonitorConsist(model.selected_nodeId)

                    // Start the read of FDI here
                    model.fdiModel = FdiModel(mservice: model.openlcbNetwork!.mservice, nodeID: message.source, throttleModel: model)
                    model.fdiModel!.readModel(nodeID: message.source)

                }
            }
        case .Traction_Control_Command :
            let subCommand = TC_Request_Type(rawValue: message.data[0]&0x7F) // Strip high order bit to include [listener] messages
            switch subCommand {
            case .SetSpeed:
                handleSpeedMessage(message)
                return false

            case .SetFunction:
                handleFunctionMessage(message)
                return false
                
            default:
                return false
            }
            
        case .Traction_Control_Reply :
            let subCommand = TC_Reply_Type(rawValue: message.data[0])
            switch subCommand {
            case .QuerySpeeds:
                handleSpeedMessage(message)
                return false
                
            case .QueryFunction:
                handleFunctionMessage(message)
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
    
    
    @frozen public enum TC_Request_Type : UInt8 {
        case SetSpeed               = 0x00
        case SetFunction            = 0x01
        case EStop                  = 0x02
        case QuerySpeeds            = 0x10
        case QueryFunction          = 0x11
        case ControllerConfig       = 0x20
        case ListenerConfig         = 0x30
        case TractionManagement     = 0x40
    }
    @frozen public enum TC_Reply_Type : UInt8 {
        case QuerySpeeds            = 0x10
        case QueryFunction          = 0x11
        case ControllerConfig       = 0x20
        case ListenerConfig         = 0x30
        case TractionManagement     = 0x40
    }
}

// For native Float <-> Float16 on Arm see
// https://stackoverflow.com/questions/36812583/how-to-convert-a-float-value-to-byte-array-in-swift
// See code in https://gist.github.com/codelynx/eeaeeda00828568aaf577c0341964c38

func float16ToFloat(_ input : [UInt8]) -> Float {
    let upper = UInt32(input[1])
    let lower = UInt32(input[0])
    
    if upper == 0 && lower == 0 { return +0.0 }
    if upper == 0x80 && lower == 0 { return -0.0 }
    
    let intMantissa = (upper << 8 | lower ) & 0x3FF
    let floatMantissa = 1.0 + Float(intMantissa)/1024.0
    
    let power : Int = Int((upper & 0x7C) >> 2) - 15
    
    var result = pow(2.0, Float(power)) * floatMantissa
    
    if upper & 0x80 != 0 { result = -1.0 * result }
    return result
}


