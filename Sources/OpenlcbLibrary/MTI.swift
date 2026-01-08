//
//  MTI.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents the Full MTI Format, a 16-bit quantity.
@frozen public enum MTI : Int {
    case Initialization_Complete            = 0x0100
    case Initialization_Complete_Simple     = 0x0101
    case Verify_NodeID_Number_Addressed     = 0x0488
    case Verify_NodeID_Number_Global        = 0x0490
    case Verified_NodeID                    = 0x0170
    case Verified_NodeID_Simple             = 0x0171
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
    case Event_With_Data_First              = 0x0F16
    case Event_With_Data_Middle             = 0x0F15
    case Event_With_Data_Last               = 0x0F14
    case Event_With_Data                    = 0x2F14

    case Simple_Node_Ident_Info_Request     = 0x0DE8
    case Simple_Node_Ident_Info_Reply       = 0x0A08
    
    case Remote_Button_Request              = 0x0948
    case Remote_Button_Reply                = 0x0549

    case Traction_Control_Command           = 0x05EB
    case Traction_Control_Reply             = 0x01E9
    
    case Datagram                           = 0x1C48
    case Datagram_Received_OK               = 0x0A28
    case Datagram_Rejected                  = 0x0A48
    
    case Stream_Initiate_Request            = 0x0CC8
    case Stream_Initiate_Reply              = 0x0868
    case Stream_Data_Send                   = 0x1F88
    case Stream_Data_Proceed                = 0x0888
    case Stream_Data_Complete               = 0x08A8
    
    case Unknown                            = 0x0000
    
    // these are used for internal signaling and are not present in the MTI specification.
    case Link_Layer_Up                      = 0x2000   // entered Permitted state; needs to be marked global
    case Link_Layer_Quiesce                 = 0x2010   // Link needs to be drained, will come back with Link_Layer_Restarted next
    case Link_Layer_Restarted               = 0x2020   // link cycled without change of node state; needs to be marked global
    case Link_Layer_Down                    = 0x2030   // entered Inhibited state; needs to be marked global
    
    case New_Node_Seen                      = 0x2048   // alias resolution found new node; marked addressed (0x8 bit)

    
    public func priority() -> Int { return (self.rawValue & 0x0C00) >> 10 }
    
    public func addressPresent() -> Bool { return (self.rawValue & 0x0008) != 0 }
    
    public func eventIDPresent() -> Bool { return (self.rawValue & 0x0004) != 0 }

    public func simpleProtocol() -> Bool { return (self.rawValue & 0x0010) != 0 }

    public func isGlobal() -> Bool { return (self.rawValue & 0x0008) == 0 }

    public var name: String {
        get { return String(describing: self) }
    }
}
