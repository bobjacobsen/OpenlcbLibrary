//
//  ThrottleModel.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import Foundation
import os

// Float16 not supported on macOS Rosetta.  Hence we use our own `floatToFloat16` conversion routine, see the bottom of the file.

// Data to construct a throttle
final public class ThrottleModel : ObservableObject {
    
    var linkLayer : LinkLayer?
    var openlcbNetwork : OpenlcbNetwork?
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ThrottleModel")
    
    /// Speed here is in meters/second.  Views that work in MPH need to do the conversion before
    /// changing `speed` here
    @Published public var speed : Float = 0.0 {
        willSet(speed) {
            sendSetSpeed(to: speed)
        }
    }
    
    @Published public var forward = true
    @Published public var reverse = false
    
    // Operations methods
    
    /// 1 scale mph to meters per second for the speed commands.
    /// The screen works in MPH; the model works in meters/sec
    static internal let mps_per_MPH : Float = 0.44704
    
    /// Send the current speed in mph to the command station.
    /// Speed here is in MPH, and conversion to meters/sec is done here
    public func sendSetSpeed(to mphSpeed: Float) {
        if tc_state != .Selected {
            // nothing selected to send the speed to
            return
        }
        
        let bytes = encodeSpeed(to: mphSpeed)
        
        let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID, destination: selected_nodeId,
                              data: [0x00, bytes[1], bytes[0]])
        linkLayer?.sendMessage(message)
    }
    
    func encodeSpeed(to mphSpeed : Float) -> ([UInt8]){
        let mpsSpeed = mphSpeed * ThrottleModel.mps_per_MPH
        let signedSpeed = reverse ? -1.0 * mpsSpeed : mpsSpeed
        let bytes = floatToFloat16(signedSpeed)
        return bytes
    }
    
    public let maxFn = 28
    @Published public var fnModels : [FnModel] = []

    public init(_ linkLayer : CanLink?) {
        self.linkLayer = linkLayer
        
        // construct the array of function models
        for index in 0...maxFn { // includes 0 and maxFn, i.e. 0 to 28 inclusive
            // default fn labels are just the numbers
            fnModels.append(FnModel(number: index, label: "\(index)", model: self))
        }
        
        ThrottleModel.logger.debug("init of ThrottleModel complete")
    }
    
    // Data to construct a single function button
    final public class FnModel : ObservableObject {
        public let label : String
        public let number : Int
        var model: ThrottleModel
        public let id = UUID()
        
        @Published public var pressed : Bool = false {
            willSet(newValue) {
                if newValue != pressed {
                    // send on change only
                    model.sendFunctionSet(function: number, to: newValue)
                }
            }
        }
        @Published public var momentary : Bool = false

        public init(number : Int, label : String, model : ThrottleModel) {
            self.number = number
            self.label = label
            self.model = model
        }
    }

    // MARK: Roster support
    
    @Published public var roster : [RosterEntry] = [RosterEntry(label: "<None>", nodeID: NodeID(0), labelSource: .Initial)]
 
    /// Get the name of a roster entry from its NodeID
    public func getRosterEntryName(from : NodeID) -> String {
        for entry in roster {
            if entry.nodeID == from {
                return entry.label
            }
        }
        return from.description
    }

    /// Get the roster entry NodeID from its label name
    public func getRosterEntryNodeID(from : String) -> NodeID {
        for entry in roster {
            if entry.label == from {
                return entry.nodeID
            }
        }
        ThrottleModel.logger.error("getRosterEntryNodeID asked for \"\(from, privacy:.public)\" which didn't match")
        return NodeID(0)
    }

    /// Add a roster entry to the roster.  Prevents duplication by, if needed, updating
    /// an existing entry that's not as current
    public func addToRoster(item : RosterEntry) {
        // check source enum and update if higher priority
        // get the matching roster entry if any
        if let rosterEntry = roster.first(where: {$0 == item}) {
            // match exists
            if item.labelSource.rawValue < rosterEntry.labelSource.rawValue {
                // do the update
                item.label = rosterEntry.label
                item.labelSource = rosterEntry.labelSource
            }
        } else {
            roster.append(item)
        }
        roster.sort() // sort by .id, which is nodeID
    }
    
    /// Load the labels in roster entries from SNIP if that's been updated
    public func reloadRoster() {
        DispatchQueue.main.async{ // to avoid "publishing changes from within view updates is not allowed"
            ThrottleModel.logger.trace("reloadRoster starting on main queue")
            for index in 0..<self.roster.count {
                let newEntry = self.createRosterEntryFromNodeID(for: self.roster[index].nodeID)
                // remake if label quality has improved or name changed
                if newEntry.labelSource.rawValue > self.roster[index].labelSource.rawValue
                            || ( newEntry.labelSource.rawValue == self.roster[index].labelSource.rawValue && newEntry.label != self.roster[index].label) {
                    ThrottleModel.logger.trace("   Updating roster entry due to new label: \(newEntry.label)")
                    self.roster[index].label = newEntry.label
                    self.roster[index].labelSource = newEntry.labelSource
                }
            }
            self.roster.sort()  // sort by .id, which is nodeID
            //roster.sort { $0.label < $1.label } // TODO: Sorts by label, but alpha sort messes up <None>, 100S vs 21S, etc; need better comparison function; add a 'sortBy' property to roster entries
        }
    }
    
    /// Convert a numeric address to a Train Search Protocol search EventID
    /// The default flags are Allocate, Exact, Address Only, DCC, default address space, any speed steps
    static internal func createQueryEventID(matching : UInt64, flags : UInt8 = 0x0E0) -> EventID {
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
    
    /// Start the locomotive selection process from a user-provided address . Optionally "force long address"
    /// which creates a long address even if it's numerically in the short address 1->127 range
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
    
    /// Start the locomotive selection process from a specific RosterEntry.
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
        
        // start the read of the FDI  // TODO: Maybe it's attached to the ThrottleModel instead of a roster entry.
        // entry.fdiModel = FdiModel(mservice: openlcbNetwork!.mservice, nodeID: entry.nodeID)
        // entry.fdiModel!.readModel(nodeID: entry.nodeID)

    }
    
    /// Set speed to 0 Forward and turn off all functions.
    /// This will trigger updates to the command station as needed.
    internal func resetSpeedAndFunctions() {
        speed = 0
        forward = true
        reverse = false
        for fn in fnModels {
            fn.pressed = false
        }
    }
    
    /// Create a new RosterEntry from just a NodeID.  Takes name from SNIP if available
    /// otherwise gueses an address from the nodeID.  The guess is not guaranteed to work,
    /// as some command stations don't use the 06.01.00.00.XX.XX node ID range
    internal func createRosterEntryFromNodeID(for nodeID: NodeID) -> RosterEntry {
        var label = ""
        var labelSource : RosterEntry.LabelSource = .Initial
        
        if (nodeID.nodeId == 0) {
            label = "<None>"
            labelSource = .Initial
        } else {
            label = openlcbNetwork!.lookUpNodeName(for: nodeID)
            if label != "" {
                labelSource = .SNIP
            } else {
                // probably too early, and SNIP not loaded yet
                // create one from NodeID
                let addr = nodeID.nodeId & 0x3FFF
                if addr <= 127 && (nodeID.nodeId & 0xC000 == 0) {
                    label = "\(addr) S"
                } else {
                    label = "\(addr)"
                }
                labelSource = .NodeID
            }
        }
        let newEntry = RosterEntry(label: label, nodeID: nodeID, labelSource: labelSource)
        
        return newEntry
    }
    
    internal var tc_state : TC_Selection_State = .Idle_no_selection
    internal var selected_nodeId : NodeID = NodeID(0)
    
    /// True is a selection has succeeded and a locmotive is selected
    @Published public var selected : Bool = false
    /// When `selected` is true, this carries the user-friendly-name of the selected locomotive
    @Published public var selectedLoco : String = "Select"  // "Select" goes with !selected

    /// Is the selection view showing?  This is set true
    /// when a View presents the selection sheet, and
    /// reset to false when selection succeeds.
    @Published public var showingSelectSheet = false
    
    // EventID used when querying for (existance of or creation as needed) a locomotive via search protocol
    internal var queryEventID : EventID = EventID(0)
    // Hold the name of the requested loco during selection
    internal var requestedLocoID : String = ""
    
    /// Forward a function update to the command station.
    public func sendFunctionSet(function: Int, to: Bool) {
        if tc_state != .Selected {
            // nothing selected to send the speed to
            return
        }
        let message = Message(mti: .Traction_Control_Command, source: linkLayer!.localNodeID, destination: selected_nodeId,
                              data: [0x01, 0x00, 0x00, UInt8(function), 0x00, to ? 0x01 : 0x00])
        linkLayer!.sendMessage(message)
    }
} // end of ThrottleModel class

// The selection state, referenced here and in ThrottleProcessor
internal enum TC_Selection_State {
    case Idle_no_selection
    // case Wait_on_Verified_Node    // have sent VerifyNode to make sure we have alias - this is now obsolete, as Traction Search event is used instead
    case Wait_on_TC_Search_reply
    case Wait_on_TC_Assign_Reply    // have sent TC Command Assign, wait on TC Reply assign OK
    case Selected                   // selection complete
    
    case Wait_on_TC_Deassign_Reply  // have sent TC Command Desassign, wait on TC Reply OK
}

// This needs reference semantics so that it can be passed and then updated
final public class RosterEntry : Hashable, Equatable, Comparable {
    public var label : String
    public let nodeID : NodeID
    public var fdiModel : FdiModel? = nil
    
    internal var labelSource : LabelSource // quality of label information
    
    // Code where the label came from, in increasing reliability order
    // This is needed becaue an isATrainEvent might come after e.g. TCAssignReply data was loaded
    enum LabelSource : Int {
        case Initial       = 1 // not initialized at all, i.e. from creation of the model before 1st real roster entry is added
        case NodeID        = 2 // inferred from NodeID, i.e. when constructed by isATrain event
        case TCAssignReply = 3
        case SNIP          = 4
    }
    
    init(label : String, nodeID : NodeID, labelSource: LabelSource){
        self.label = label
        self.nodeID = nodeID
        self.labelSource = labelSource
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

func floatToFloat16(_ input : Float) -> [UInt8] {
    var outputUpper : UInt8 = 0
    var outputLower : UInt8 = 0
    
    if (input == 0.0 && input.sign == .plus) { return [0, 0x00]}
    if (input == 0.0 && input.sign != .plus) { return [0, 0x80]}
    
    var rawExp = 15  // initial bias
    var trialValue = abs(input)
    if trialValue > 1.0 {
        while trialValue >= 2.0 {
            rawExp += 1
            trialValue = trialValue/2
        }
    } else if trialValue < 1.0 {
        while trialValue < 1.0 {
            rawExp -= 1
            trialValue = trialValue*2.0
        }
    }
    if rawExp > 31 { rawExp = 31 }
    if rawExp <  0 { rawExp =  0 }
    let finalExp = rawExp << 2
    
    let trialMantissa = trialValue - 1 // should now be between 0 and 1, from 1 to 2
    let mantissa = Int(round(trialMantissa*1024.0))
    
    outputUpper = UInt8((finalExp & 0x7C) | ((mantissa >> 8) & 0x03))
    if input < 0.0 {outputUpper = 0x80 | outputUpper }
    outputLower = UInt8(mantissa & 0xFF)
    
    return [outputLower, outputUpper]
}


