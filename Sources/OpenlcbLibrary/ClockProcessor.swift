//
//  ClockProcessor.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import Foundation

// a slave clock with limited ability to send commands (just run, basically)
struct ClockProcessor : Processor {
    public init ( _ linkLayer: LinkLayer?, _ clocks: [ClockModel]) {
        self.linkLayer = linkLayer
        self.clocks = clocks
    }
    let linkLayer : LinkLayer?
    let clocks : [ClockModel]  // provided array of valid clocks, 0 to 4 entries

    public func process( _ message : Message, _ node : Node ) -> Bool {
        switch message.mti {
        case .Producer_Consumer_Event_Report,
                .Producer_Identified_Active,
                .Producer_Identified_Inactive,
                .Producer_Identified_Unknown :
            eventReport(message, node)
        
        // TODO: We should reply to Identify_Producer, Identify_Consumer, Identify_Events?
            
        case .Link_Layer_Up :
            linkUp(message, node)
        
        default:
            // no need to do anything
            break
        }
        
        return false;
    }
    
    func linkUp(_ message : Message, _ node : Node) {
        let msg1 = Message(mti: .Consumer_Range_Identified, source: node.id, data: [1,1,0,0,1  ,0x03, 0xFF,0xFF ])  // full range for four clocks
        linkLayer?.sendMessage(msg1)
        // send Query Event ID for primary clock // TODO: handle all clocks in Clocks array?
        let msg2 = Message(mti: .Producer_Consumer_Event_Report, source: node.id, data: [1,1,0,0,1  ,0, 0xF0,0x00 ])
        linkLayer?.sendMessage(msg2)
    }

    func eventReport(_ message : Message, _ node : Node) {
        let event = message.data
        if !(event[0] == 1 && event[1] == 1 && event[2] == 0 && event[3] == 0 && event[4] == 1) {
            return
        }
        
        // here the event references a clock - which?
        let index = Int(event[5])
        if index >= clocks.count {
            // not a valid clock number, so not really a clock event
            return
        }
        let clock = clocks[index]
        
        // prep for changing the clock's Date
        let calendar = Calendar.current // user calendar
        let requestedComponents: Set<Calendar.Component> = [
            .year,
            .month,
            .day,
            .hour,
            .minute,
            .timeZone
        ]
        var components = calendar.dateComponents(requestedComponents, from: clock.getTime())

        let byte6 = Int(event[6])
        let byte7 = Int(event[7])
        
        // decode byte 6 for type of event
        if byte6 <= 0x17 {
            // hours and minutes
            components.hour = byte6
            components.minute = byte7
        } else if byte6 <= 0x2C {
            // report Date
            components.month = byte6 & 0xF
            components.day = byte7
        } else if byte6 <= 0x3F {
            // report Year
            components.year = ((byte6&0x0F)<<8) + byte7
        } else if byte6 <= 0x4F {
            // report rate
            clock.rate = Double(((byte6&0x0F)<<8) + byte7)/4
        } else if byte6 == 0xF0 {
            // controls
            // check for run/start
            if byte7 == 0x01 {
                // stop
                clock.run = false
            } else if byte7 == 0x02 {
                // start
                clock.run = true
            }
        }
        
        // have now loaded a new time, set it
        clock.setTime(calendar.date(from: components) ?? Date())
    }
}
