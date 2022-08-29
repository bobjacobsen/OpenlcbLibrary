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
    var openlcbLibrary : OpenlcbLibrary?
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleModel")
    
    /// Speed here is in meters/second.  Views that work in MPH need to do the conversion before
    /// changing `speed` here
    @Published public var speed : Float16 = 0.0 {
        willSet(speed) {
            sendSetSpeed(to: speed)
        }
    }
    
    @Published public var forward = true   // TODO: send TC update request to get initial state from command station
    @Published public var reverse = false
    
    
    // Operations methods
    
    /// 1 scale mph to meters per second for the speed commands.
    /// The screen works in MPH; the model works in meters/sec
    static let MPH_to_mps : Float16 = 0.44704
    
    /// Speed here is in MPH, and conversion to meters/sec is done here
    public func sendSetSpeed(to mphSpeed: Float16) {
        if tc_state != .Selected {
            // nothing selected to send the speed to
            return
        }
        let mpsSpeed = mphSpeed * ThrottleModel.MPH_to_mps
        let signedSpeed = reverse ? -1.0 * mpsSpeed : mpsSpeed
        let bytes = signedSpeed.bytes               // see extension to Float16 below
        
        let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID, destination: selected_nodeId,
                              data: [0x00, bytes[1], bytes[0]])
        linkLayer?.sendMessage(message)
    }
    
    let maxFn = 28
    @Published public var fnModels : [FnModel] = []
    
    public init(_ linkLayer : CanLink?) {
        self.linkLayer = linkLayer
        
        // construct the array of function models
        for index in 0...maxFn {
            // default fn labels are just the numbers
            fnModels.append(FnModel(index, "\(index)", self))
        }
        
        logger.debug("init of ThrottleModel complete")
    }
    
    @Published public var roster : [RosterEntry] = [RosterEntry(label: "<None>", nodeID: NodeID(0))]
    
    // Have to ensure entries are unique when added to the roster
    public func addToRoster(item : RosterEntry) {
        if roster.contains(item) { return }
        roster.append(item)
        roster.sort()
    }
    
    /// Convert a numeric address to a Train Search Protocol search EventID
    /// The default flags are Allocate, Exact, Address Only, DCC, default address space, any speed steps
    static func createQueryEventID(matching : UInt64, flags : UInt8 = 0x0E0) -> EventID {
        // convert matching value to BCD
        var binaryInput = matching
        var bcdResult : UInt64 = 0
        var shift = 0
        while (binaryInput > 0) {
            bcdResult |= (binaryInput % 10) << (shift << 2);
            shift += 1
            binaryInput /= 10;
        }

        // shift result into position and add unused indicators
        while (bcdResult >> 20 ) & 0xF == 0 { // shift to have MSNibble in position
            bcdResult = ( bcdResult << 4) | 0xF
        }
        let match1 : UInt8 = UInt8( ( bcdResult >> 16 ) & 0xFF )
        let match2 : UInt8 = UInt8( ( bcdResult >> 8  ) & 0xFF )
        let match3 : UInt8 = UInt8( ( bcdResult       ) & 0xFF )
        return EventID([0x09, 0x00, 0x99, 0xFF, match1, match2, match3, flags])
    }
    
    // works with ThrottleProcessor to execute a state machine
    public func startSelection(address : UInt64, forceLongAddr : Bool = false) {
        // zero speed, reset functions
        resetSpeedAndFunctions()
        // start search for requested number
        tc_state = .Wait_on_TC_Search_reply
        let shortLongLabel : String = forceLongAddr ? "L" : (address > 127 ? "L" : "S")
        requestedLocoID = "\(address) \(shortLongLabel)"  // for placing in display label when Assign succeeds
        // send a Traction Search event request
        queryEventID = ThrottleModel.createQueryEventID(matching: address, flags: forceLongAddr ? 0xEC : 0xE8 )
        let message = Message(mti: .Identify_Producer, source: linkLayer!.localNodeID, data: queryEventID.toArray())
        linkLayer?.sendMessage(message)
    }
    
    public func startSelection(entry: RosterEntry) {
        // zero speed, reset functions
        resetSpeedAndFunctions()
        // selection has actual node ID, go straight to sending Assign
        tc_state = .Wait_on_TC_Assign_Reply
        requestedLocoID = entry.label
        selected_nodeId = entry.nodeID
        let header : [UInt8] = [0x20, 0x01, 0x01]
        let data = header + (linkLayer!.localNodeID.toArray())
        let command = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID,
                              destination: entry.nodeID, data: data)
        linkLayer!.sendMessage(command)

    }
    
    func resetSpeedAndFunctions() {
        speed = 0
        forward = true
        reverse = false
        for fn in fnModels {
            fn.pressed = false
        }
    }
    
    func createRosterEntry(for nodeID: NodeID) -> RosterEntry {
        var label = ""
        if (nodeID.nodeId == 0) {
            label = "<none>"
        } else {
            label = openlcbLibrary!.lookUpNodeName(for: nodeID)
            if label == "" {
                // probably too early, and SNIP not loaded yet
                // create one from NodeID
                let addr = nodeID.nodeId & 0x3FFF
                if addr <= 127 && (nodeID.nodeId & 0xC000 == 0) {
                    label = "\(addr)S"
                } else {
                    label = "\(addr)"
                }
            }
        }
        return RosterEntry(label: label, nodeID: nodeID)

    }
    
    var tc_state : TC_Selection_State = .Idle_no_selection
    var selected_nodeId : NodeID = NodeID(0)
    
    @Published public var selected : Bool = false
    @Published public var selectedLoco : String = "Select"  // "Select" goes with !selected

    // Is the selection view showing?  This is set true
    // when a View presents the selection sheet, and
    // reset to false when selection succeeds.
    @Published public var showingSelectSheet = false
    
    // EventID used when querying for (existance of or creation as needed) a locomotive
    var queryEventID : EventID = EventID(0)
    // hold the name of the requested loco during selection
    var requestedLocoID : String = ""
    
    // handle a function call
    public func sendFunctionSet(function: Int, to: Bool) {
        if tc_state != .Selected {
            // nothing selected to send the speed to
            return
        }
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
    // case Wait_on_Verified_Node    // have sent VerifyNode to make sure we have alias - this is now obsolete, as Traction Search event is used instead
    case Wait_on_TC_Search_reply
    case Wait_on_TC_Assign_Reply    // have sent TC Command Assign, wait on TC Reply assign OK
    case Selected                   // selection complete
    
    case Wait_on_TC_Deassign_Reply  // have sent TC Command Desassign, wait on TC Reply OK
}

public struct RosterEntry : Hashable, Equatable, Comparable {
    public let label : String // TODO: eventually this should be computed from SNIP
    public let nodeID : NodeID

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
