//
//  ThrottleModel.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

// Data to construct a throttle
public class ThrottleModel : ObservableObject {
    
    var linkLayer : CanLink?
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleModel")
    
    /// Speed here is in meters/second.  Views that work in MPH need to do the conversion before
    /// changing `speed` here
    @Published public var speed : Float16 = 0.0 {
        willSet(speed) {
            sendSetSpeed(to: speed)
        }
    }
    
    @Published public var forward = true   // TODO: get initial state from somewhere?
    @Published public var reverse = false
    
    // Is the selection view showing?  This is set true
    // when a View presents the selection sheet, and
    // reset to false when selection succeeds.
    @Published public var showingSelectSheet = false
    
    // Operations methods
    
    /// 1 scale mph to meters per second for the speed commands.
    /// The screen works in MPH; the model works in meters/sec
    static let MPH_to_mps : Float16 = 0.44704
    
    /// Speed here is in MPH, and conversion to meters/sec is done here
    public func sendSetSpeed(to mphSpeed: Float16) {
        let mpsSpeed = mphSpeed * ThrottleModel.MPH_to_mps
        let signedSpeed = reverse ? -1.0 * mpsSpeed : mpsSpeed
        let bytes = signedSpeed.bytes               // see extension to Float16 below
        
        let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID, destination: selected_nodeId,
                              data: [0x00, bytes[1], bytes[0]])
        linkLayer?.sendMessage(message)
    }
    
    let maxFn = 28
    @Published public var fnModels : [FnModel] = []  // TODO: associate these with state from throttle
    
    public init(_ linkLayer : CanLink?) {
        self.linkLayer = linkLayer
        
        // construct the array of function models
        for index in 0...maxFn {
            // default fn labels are just the numbers
            fnModels.append(FnModel(index, "\(index)", self))
        }
        
        logger.debug("init of ThrottleModel complete")
    }
    
    @Published public var roster : [RosterEntry] = [RosterEntry("<none>", NodeID(0))]
    
    // Have to ensure entries are unique when added to the roster
    public func addToRoster(item : RosterEntry) {
        // TODO: add handling for a "<none>" case, including setting the Picker at start?
        if roster.contains(item) { return }
        roster.append(item)
        roster.sort()
    }
    
    // works with ThrottleProcessor to execute a state machine
    public func startSelection(_ selection : NodeID) {  // selection has low 16 bits of address, needs to be augmented
        selectedLoco = "\(selection.nodeId)"
        let nodeID = NodeID(selection.nodeId | 0x06_01_00_00_00_00)
        logger.debug("start selection with \(selection.nodeId, privacy: .public) and \(nodeID, privacy: .public)")
        // first step is making sure you have the alias for this node
        selected_nodeId = nodeID
        tc_state = .Idle_no_selection
        let message = Message(mti: .Verify_NodeID_Number_Global, source: linkLayer!.localNodeID, data: nodeID.toArray())
        linkLayer?.sendMessage(message)
    }
    
    var tc_state : TC_Selection_State = .Idle_no_selection
    var selected_nodeId : NodeID = NodeID(0)
    
    @Published public var selected : Bool = false
    @Published public var selectedLoco : String = "Select"  // "Select" goes with !selected
    
    // handle a function call
    public func sendFunctionSet(function: Int, to: Bool) {
        let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID, destination: selected_nodeId,
                              data: [0x01, 0x00, 0x00, UInt8(function), 0x00, to ? 0x01 : 0x00])
        linkLayer!.sendMessage(message)
    }
}

// For converting Float16 to bytes and vice versa
// See https://stackoverflow.com/questions/36812583/how-to-convert-a-float-value-to-byte-array-in-swift
extension Float16 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}


// the selection state, referenced here and in ThrottleProcessor
public enum TC_Selection_State {
    case Idle_no_selection
    case Wait_on_Verified_Node      // have sent VerifyNode to make sure we have alias
    case Wait_on_TC_Assign_Reply    // have sent TC Command Assign, wait on TC Reply assign OK
    case Selected                   // selection complete
    
    case Wait_on_TC_Deassign_Reply  // have sent TC Command Desassign, wait on TC Reply OK
}

public struct RosterEntry : Hashable, Equatable, Comparable {
    public let label : String
    public let nodeID : NodeID
    public init(_ label : String, _ nodeID : NodeID) {
        self.label = label
        self.nodeID = nodeID
    }
    /// Equality is defined on the NodeID only.
    public static func ==(lhs: RosterEntry, rhs:RosterEntry) -> Bool {
        return lhs.nodeID == rhs.nodeID
    }
    public func hash(into hasher : inout Hasher) {
        hasher.combine(nodeID)
    }
    // Comparable is defined on the NodeID
    public static func <(lhs: RosterEntry, rhs: RosterEntry) -> Bool {
        return lhs.nodeID.nodeId < rhs.nodeID.nodeId
    }
}

// Data to construct a single function button
public class FnModel : ObservableObject {
    public let label : String
    public let number : Int
    var model: ThrottleModel
    public let id = UUID()
    
    @Published public var pressed : Bool = false {
        willSet(pressed) {
            model.sendFunctionSet(function: number, to: pressed)
        }
    }
    @Published public var momentary : Bool = false
    
    public init(_ number : Int, _ label : String, _ model : ThrottleModel) {
        self.number = number
        self.label = label
        self.model = model
    }
}
