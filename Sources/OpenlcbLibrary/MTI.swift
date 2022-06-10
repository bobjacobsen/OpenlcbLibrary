//
//  MTI.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents the Full MTI Format, a 16-bit quantity
public enum MTI : Int {
    case InitializationComplete         = 0x0100
    case InitializationCompleteSimple   = 0x0101
    case VerifyNodeIDNumberAddressed    = 0x0488
    case VerifyNodeIDNumberGlobal       = 0x0490
    case VerifiedNodeID                 = 0x0170
    case OptionalInteractionRejected    = 0x0068
    case TerminateDueToError            = 0x00A8
    
    case ProtocolSupportInquiry         = 0x0828
    case ProtocolSupportReply           = 0x0668
    
    case IdentifyConsumer               = 0x08F4
    case ConsumerRangeIdentified        = 0x04A4
    case ConsumerIdentifiedUnknown      = 0x04C7
    case ConsumerIdentifiedActive       = 0x04C4
    case ConsumerIdentifiedInactive     = 0x04C5
    case IdentifyProducer               = 0x0914
    case ProducerRangeIdentified        = 0x0524
    case ProducerIdentifiedUnknown      = 0x0547
    case ProducerIdentifiedActive       = 0x0544
    case ProducerIdentifiedInactive     = 0x0545
    case IdentifyEventsAddressed        = 0x0968
    case IdentifyEventsGlobal           = 0x0970
    case LearnEvent                     = 0x0594
    case ProducerConsumerEventReport    = 0x05b4
    
    case SimpleNodeIdentInfoRequest     = 0x0DE8
    case SimpleNodeIdentInfoReply       = 0x0A08
    
    case Datagram                       = 0x1C48
    case DatagramReceivedOK             = 0x0A28
    case DatagramRejected               = 0x0A48
    
    case Unknown                        = 0x0000
    
    // these are used for internal signalling and are not present in the MTI specification
    case LinkLevelUp                    = 0x2000   // entered Permitted state, needs to be global
    case LinkLevelDown                  = 0x2001   // entered Inhibited state, needs to be global

    public func priority() -> Int { return (self.rawValue & 0x0C00) >> 10 }
    
    public func addressPresent() -> Bool { return (self.rawValue & 0x0008) != 0 }
    
    public func eventIDPresent() -> Bool { return (self.rawValue & 0x0004) != 0 }

    public func simpleProtocol() -> Bool { return (self.rawValue & 0x0010) != 0 }

}
