//
//  TurnoutModel.swift
//  
//
//  Created by Bob Jacobsen on 10/3/22.
//

import Foundation

// TODO: Add tracking of turnout state, including when others throw

/// Provide Turnout status information and commands for e.g. a Turnout View
public class TurnoutModel : ObservableObject {
    @Published public private(set) var addressArray : [Int] = []  // address-sorted form of addressSet
    private var addressSet = Set<Int>()
    internal var network : OpenlcbNetwork?  // set during contruction
    
    init() {
    }
    
    public func setClosed(_ address : Int) {
        processAddress(address)
        let eventID : UInt64 = UInt64(0x01_01_02_00_00_FF_00_00+TurnoutModel.transmogrifyTurnoutId(from: address))+1
        network!.produceEvent(eventID: EventID(eventID))
    }
    
    public func setThrown(_ address : Int) {
        processAddress(address)
        let eventID : UInt64 = UInt64(0x01_01_02_00_00_FF_00_00+TurnoutModel.transmogrifyTurnoutId(from: address))+0
        network!.produceEvent(eventID: EventID(eventID))
    }
    func processAddress(_ address : Int) {
        if !addressSet.contains(address) {
            // only do this if needed to avoid unnecesary publishes
            addressSet.insert(address)
            addressArray = addressSet.sorted()
        }
    }
    
    /// Convert from a 1-2048 turnout address to the Olcb format for NMRA DCC.
    /// See the Event Transfer TN section 2.5.3.3 for more information.
    /// - Parameter from: a 1-2048 turnout address
    /// - Returns eventID to send in AAAaaaaaaDDD format
    static internal func transmogrifyTurnoutId(from : Int) -> Int {  // internal for testing
        let DD = (from-1) & 0x3
        let aaaaaa = (( (from-1) >> 2)+1 ) & 0x3F
        let AAA = ( (from) >> 8) & 0x7
        // print ( "\(from): \(AAA) \(aaaaaa) \(DD)")
        
        let retval = 0x0000 | (AAA << 9) | (aaaaaa << 3) | DD << 1
        // print (String(format:"%04X", retval))
        return retval
    }
}
