//
//  TurnoutModel.swift
//
//  Created by Bob Jacobsen on 10/3/22.
//

import Foundation
import SwiftUI // for array remove at offsets

// TODO: Add tracking of turnout state, including when others throw

/// Provide Turnout commands for e.g. a Turnout View
/// and Macro commands
final public class TurnoutModel : ObservableObject {
    @Published public private(set) var turnoutDefinitionArray : [TurnoutDefinition] = [] // address-sorted form of addressSet
    private var turnoutDefinitionSet = Set<TurnoutDefinition>()

    @Published public private(set) var macroArray : [Int] = []  // number-sorted form of macroSet
    private var macroSet = Set<Int>()

    internal var network : OpenlcbNetwork?  // set during contruction
    
    init() {
    }
        
    /// Make sure a layout turnout is set closed
    /// - Parameter turnoutDefinition: Defines closed Event ID
    public func setClosed(_ turnoutDefinition : TurnoutDefinition) {
        processTurnoutDefinition(turnoutDefinition)
        let eventID = turnoutDefinition.closedEventID
        if let network = network {
            network.produceEvent(eventID: eventID)
        }
    }
    
    /// Make sure a layout turnout is set closed
    /// - Parameter address: Address in 1 - 2048 form
    public func setClosed(_ address : Int) {
        let turnoutDefinition = processTurnout(address)
        let eventID = turnoutDefinition.closedEventID
        if let network = network {
            network.produceEvent(eventID: eventID)
        }
    }
    
    /// Make sure a layout turnout is set thrown
    /// - Parameter turnoutDefinition: Defines thrown Event ID
    public func setThrown(_ turnoutDefinition : TurnoutDefinition) {
        processTurnoutDefinition(turnoutDefinition)
        let eventID = turnoutDefinition.thrownEventID
        if let network = network {
            network.produceEvent(eventID: eventID)
        }
    }
    
    /// Make sure a layout turnout is set thrown
    /// - Parameter address: Address in 1 - 2048 form
    public func setThrown(_ address : Int) {
        let turnoutDefinition = processTurnout(address)
        let eventID = turnoutDefinition.thrownEventID
        if let network = network {
            network.produceEvent(eventID: eventID)
        }
    }
    
    /// Add a turnout to the list of known turnouts
    /// - Parameter address: Address in 1 - 2048 form
    func processTurnout(_ address : Int) -> TurnoutDefinition {
        let turnoutDefinition = TurnoutDefinition(address)
        processTurnoutDefinition(turnoutDefinition)
        return turnoutDefinition
    }

    /// See if a TurnoutDefinition needs to be stored; only store if new or changed
    public func processTurnoutDefinition(_ turnoutDefinition : TurnoutDefinition) {
        // if not present, add
        if !turnoutDefinitionSet.contains(turnoutDefinition) {
            replaceTurnoutDefinition(turnoutDefinition)
            return
        }
        // check for different contents; if so, replace
        for element in turnoutDefinitionSet {
            if element == turnoutDefinition {
                // this is the element - compare the event IDs
                if element.closedEventID != turnoutDefinition.closedEventID || element.thrownEventID != turnoutDefinition.thrownEventID {
                    replaceTurnoutDefinition(turnoutDefinition)
                    return
                }
            }
        }
    }
    
    /// Force a  definition to be stored, perhaps because it has different thrown/closed event IDs
    private func replaceTurnoutDefinition(_ turnoutDefinition : TurnoutDefinition) {
        turnoutDefinitionSet.insert(turnoutDefinition)
        turnoutDefinitionArray = turnoutDefinitionSet.sorted()
    }
    
    /// Delete specific definition(s)
    public func deleteAtOffsets(_ offsets: IndexSet) {
        turnoutDefinitionSet = Set<TurnoutDefinition>() // new empty set
        
        // array .remove(atOffsets: offsets) is not compiling without import SwiftUI
        turnoutDefinitionArray.remove(atOffsets: offsets)
        
        turnoutDefinitionSet.formUnion(turnoutDefinitionArray)
    }
    
    /// Make sure a layout macro is set
    /// - Parameter macro: Macro in 1-65535 form
    public func setMacro(_ macro : Int) {
        processMacro(macro)
        let eventID : UInt64 = UInt64(MACRO_BASE_EVENTID+TurnoutModel.transmogrifyModelId(from: macro))
        if let network = network {
            network.produceEvent(eventID: EventID(eventID))
        }
    }
        
    /// Convert from a 1-2048 turnout address to the Olcb format for NMRA DCC.
    /// See the Event ID TN section 2.5.3.3 for more information.
    /// - Parameter from: a 1-2048 turnout address
    /// - Returns eventID to send in AAAaaaaaaDDD format
    static internal func transmogrifyModelId(from : Int) -> UInt64 {  // internal for testing
        var turnout = UInt64(from)
        if (turnout >= 2045) {
            turnout = turnout-2045;
        } else {
            turnout = turnout + 3;
        }

        return turnout << 1
    }

    let MACRO_BASE_EVENTID : UInt64     = UInt64(0x09_00_99_FE_FF_FE_00_00)

    /// Add an macro to the list of known macros
    /// - Parameter macro: Address in 1-65535 form
    func processMacro(_ macro : Int) {
        if !macroSet.contains(macro) {
            // only do this if needed to avoid unnecesary publishes
            macroSet.insert(macro)
            macroArray = macroSet.sorted()
        }
    }
    
}

///
/// Record the name and EventID addresses for a single Turnout
///
public struct TurnoutDefinition : Equatable, Hashable, Comparable, Codable {
    public let visibleAddress : String
    public let closedEventID : EventID
    public let thrownEventID : EventID 

    public init(_ address : String, _ closed : EventID, _ thrown : EventID) {
        self.visibleAddress = address
        self.closedEventID = closed
        self.thrownEventID = thrown
    }

    var TURNOUT_BASE_EVENTID : UInt64 = UInt64(0x01_01_02_00_00_FF_00_00)  // form of constant that doesn't issue decoding warnings
    
    public init(_ address : Int) {
        self.visibleAddress = String(address)
        self.closedEventID = EventID(UInt64(TURNOUT_BASE_EVENTID+TurnoutDefinition.transmogrifyTurnoutId(from: address))+1)
        self.thrownEventID = EventID(UInt64(TURNOUT_BASE_EVENTID+TurnoutDefinition.transmogrifyTurnoutId(from: address))+0)
    }

    /// Convert from a 1-2048 turnout address to the Olcb format for NMRA DCC.
    /// See the Event ID TN section 2.5.3.3 for more information.
    /// - Parameter from: a 1-2048 turnout address
    /// - Returns eventID to send in AAAaaaaaaDDD format
    static internal func transmogrifyTurnoutId(from : Int) -> UInt64 {  // internal for testing
        var turnout = UInt64(from)
        if (turnout >= 2045) {
            turnout = turnout-2045;
        } else {
            turnout = turnout + 3;
        }

        return turnout << 1
    }

    /// Used to make Set.contains work on just the address
    // Comparable is defined on the address only
    public static func <(lhs: TurnoutDefinition, rhs: TurnoutDefinition) -> Bool {
        return lhs.visibleAddress < rhs.visibleAddress
    }
    
    // Equatable is defined on the address only
    public static func ==(lhs: TurnoutDefinition, rhs: TurnoutDefinition) -> Bool {
        return lhs.visibleAddress == rhs.visibleAddress
    }
    
    // Hashable is defined on the address only
    public func hash(into hasher: inout Hasher) {
        hasher.combine(visibleAddress)
    }
}
