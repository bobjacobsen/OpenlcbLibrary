//
//  PIP.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Defines the various protocol bits as a enum, and
/// provides a routine for converting a numeric value to a set of enum constants.
///
///
public enum PIP : UInt32, CaseIterable {
    
    /// Coded as a 32-bit values instead of the 24-bit values in the standard to give expansion room
    case SIMPLE_PROTOCOL                        = 0x80_00_00_00
    case DATAGRAM_PROTOCOL                      = 0x40_00_00_00
    case STREAM_PROTOCOL                        = 0x20_00_00_00
    case MEMORY_CONFIGURATION_PROTOCOL          = 0x10_00_00_00
    case RESERVATION_PROTOCOL                   = 0x08_00_00_00
    case EVENT_EXCHANGE_PROTOCOL                = 0x04_00_00_00
    case IDENTIFICATION_PROTOCOL                = 0x02_00_00_00
    case TEACH_LEARN_PROTOCOL                   = 0x01_00_00_00
    case REMOTE_BUTTON_PROTOCOL                 = 0x00_80_00_00
    case ADCDI_PROTOCOL                         = 0x00_40_00_00
    case DISPLAY_PROTOCOL                       = 0x00_20_00_00
    case SIMPLE_NODE_IDENTIFICATION_PROTOCOL    = 0x00_10_00_00
    case CONFIGURATION_DESCRIPTION_INFORMATION  = 0x00_08_00_00
    case TRAIN_CONTROL_PROTOCOL                 = 0x00_04_00_00
    case FUNCTION_DESCRIPTION_INFORMATION       = 0x00_02_00_00
    case DCC_COMMAND_STATION_PROTOCOL           = 0x00_01_00_00
    case SIMPLE_TRAIN_NODE_INFO_PROTOCOL        = 0x00_00_80_00
    case FUNCTION_CONFIGURATION                 = 0x00_00_40_00
    case FIRMWARE_UPGRADE_PROTOCOL              = 0x00_00_20_00
    case FIRMWARE_ACTIVE                        = 0x00_00_10_00
    
    /**
     * The name of the enumeration (as written in case).
     */
    var name: String {
        get { return String(describing: self) }
    }

    // return an array of strings for all included values
    public static func contentsNames(_ contents : UInt32) -> [String] {
        var retval : [String] = []
        for pip in PIP.allCases {
            if (pip.rawValue & contents == pip.rawValue) {
                retval += [pip.name]
            }
        }
        return retval
    }

    // return an array of strings for all included values
    public static func contentsNames(_ contents : Set<PIP>) -> [String] {
        var retval : [String] = []
        for pip in contents {
            retval += [pip.name.replacingOccurrences(of: "_", with: " ").capitalized]
        }
        return retval
    }
    
    static func setContents(_ input : UInt32) -> Set<PIP> {
        var retVal = Set<PIP>()
        for val in PIP.allCases {
            if (val.rawValue & input != 0) {
                retVal.insert(val)
            }
        }
        return retVal
    }
    
    static func setContents(raw: [UInt8]) -> Set<PIP> {
        var data : UInt32 = 0
        if (raw.count > 0 ) { data |= (UInt32(raw[0]) << 24 ) }
        if (raw.count > 1 ) { data |= (UInt32(raw[1]) << 16 ) }
        if (raw.count > 2 ) { data |= (UInt32(raw[2]) <<  8 ) }
        if (raw.count > 3 ) { data |= (UInt32(raw[3])       ) }
        return setContents(data)
    }
}
