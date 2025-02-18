//
//  TurnoutModel.swift
//  
//
//  Created by Bob Jacobsen on 10/3/22.
//

import Foundation

// TODO: Add tracking of turnout state, including when others throw

/// Provide Turnout commands for e.g. a Turnout View
public class TurnoutModel : ObservableObject {
    @Published public private(set) var addressArray : [Int] = []  // address-sorted form of addressSet
    private var addressSet = Set<Int>()
    @Published public private(set) var macroArray : [Int] = []  // number-sorted form of macroSet
    private var macroSet = Set<Int>()
    internal var network : OpenlcbNetwork?  // set during contruction
    
    init() {
    }
    
    let TURNOUT_BASE_EVENTID : UInt64   = UInt64(0x01_01_02_00_00_FF_00_00)
    let MACRO_BASE_EVENTID : UInt64     = UInt64(0x09_00_99_FE_FF_FE_00_00)
    
    /// Make sure a layout turnout is set closed
    /// - Parameter address: Address in 1-2048 form
    public func setClosed(_ address : Int) {
        processAddress(address)
        let eventID : UInt64 = UInt64(TURNOUT_BASE_EVENTID+TurnoutModel.transmogrifyTurnoutId(from: address))+1
        network!.produceEvent(eventID: EventID(eventID))
    }
    
    /// Make sure a layout turnout is set thrown
    /// - Parameter address: Address in 1-2048 form
    public func setThrown(_ address : Int) {
        processAddress(address)
        let eventID : UInt64 = UInt64(TURNOUT_BASE_EVENTID+TurnoutModel.transmogrifyTurnoutId(from: address))+0
        network!.produceEvent(eventID: EventID(eventID))
    }
    
    /// Make sure a layout turnout is set thrown
    /// - Parameter macro: Macro in 1-65535 form
    public func setMacro(_ macro : Int) {
        processMacro(macro)
        let eventID : UInt64 = UInt64(MACRO_BASE_EVENTID+TurnoutModel.transmogrifyTurnoutId(from: macro))
        network!.produceEvent(eventID: EventID(eventID))
    }
    
    /// Add an address to the list of known addresses
    /// - Parameter address: Address in 1-2048 form
    func processAddress(_ address : Int) {
        if !addressSet.contains(address) {
            // only do this if needed to avoid unnecesary publishes
            addressSet.insert(address)
            addressArray = addressSet.sorted()
        }
    }
    
    /// Add an macro to the list of known macros
    /// - Parameter macro: Address in 1-65535 form
    func processMacro(_ macro : Int) {
        if !macroSet.contains(macro) {
            // only do this if needed to avoid unnecesary publishes
            macroSet.insert(macro)
            macroArray = macroSet.sorted()
        }
    }
    
    /// Convert from a 1-2048 turnout address to the Olcb format for NMRA DCC.
    /// See the Event Transfer TN section 2.5.3.3 for more information.
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
}
