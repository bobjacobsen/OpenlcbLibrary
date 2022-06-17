//
//  LocalEventStore.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Store node-specific Event information
///
///  See also ``GlobalEventStore``

// TODO: Add support for ranges
public struct LocalEventStore {
    internal var eventsConsumed : Set<EventID> = []
    internal var eventsProduced : Set<EventID> = []

    mutating func consumes(_ id : EventID) {
        eventsConsumed.insert(id)
    }
    
    func isConsumed(_ id: EventID) -> (Bool) {
        return eventsConsumed.contains(id)
    }
    
    mutating func produces(_ id : EventID) {
        eventsProduced.insert(id)
    }
    
    func isProduced(_ id: EventID) -> (Bool) {
        return eventsProduced.contains(id)
    }
}
