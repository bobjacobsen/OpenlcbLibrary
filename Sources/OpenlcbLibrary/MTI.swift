//
//  MTI.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents the Full MTI Format, a 16-bit quantity
public enum MTI : Int {
    case Initialization_Complete            = 0x0100
    case Initialization_Complete_Simple     = 0x0101
    case Verify_NodeID_Number_Addressed     = 0x0488
    case Verify_NodeID_Number_Global        = 0x0490
    case Verified_NodeID                    = 0x0170
    case Optional_Interaction_Rejected      = 0x0068
    case Terminate_Due_To_Error             = 0x00A8
    
    case Protocol_Support_Inquiry           = 0x0828
    case Protocol_Support_Reply             = 0x0668
    
    case Identify_Consumer                  = 0x08F4
    case Consumer_Range_Identified          = 0x04A4
    case Consumer_Identified_Unknown        = 0x04C7
    case Consumer_Identified_Active         = 0x04C4
    case Consumer_Identified_Inactive       = 0x04C5
    case Identify_Producer                  = 0x0914
    case Producer_Range_Identified          = 0x0524
    case Producer_Identified_Unknown        = 0x0547
    case Producer_Identified_Active         = 0x0544
    case Producer_Identified_Inactive       = 0x0545
    case Identify_Events_Addressed          = 0x0968
    case Identify_Events_Global             = 0x0970
    case Learn_Event                        = 0x0594
    case Producer_Consumer_Event_Report     = 0x05b4
    
    case Simple_Node_Ident_Info_Request     = 0x0DE8
    case Simple_Node_Ident_Info_Reply       = 0x0A08
    
    case Datagram                           = 0x1C48
    case Datagram_Received_OK               = 0x0A28
    case Datagram_Rejected                  = 0x0A48
    
    case Unknown                            = 0x0000
    
    // these are used for internal signalling and are not present in the MTI specification.
    case Link_Level_Up                      = 0x2000   // entered Permitted state, needs to be marked global
    case Link_Level_Down                    = 0x2010   // entered Inhibited state, needs to be marked global
    case New_Node_Seen                      = 0x2028   // alias resolution found new node, marked addressed

    
    public func priority() -> Int { return (self.rawValue & 0x0C00) >> 10 }
    
    public func addressPresent() -> Bool { return (self.rawValue & 0x0008) != 0 }
    
    public func eventIDPresent() -> Bool { return (self.rawValue & 0x0004) != 0 }

    public func simpleProtocol() -> Bool { return (self.rawValue & 0x0010) != 0 }

    public func isGlobal() -> Bool { return (self.rawValue & 0x0008) == 0 }

    var name: String {
        get { return String(describing: self) }
    }
}
