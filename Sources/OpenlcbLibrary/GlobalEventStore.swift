//
//  GlobalEventStore.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Store the available Events and provide multiple means of retrieval.
///  Intended to provide access to data carried with  an Event, i.e. event names
///  Storage and indexing methods are an internal detail.
///  You can't remove an Event; once we know about it, we know about it.
///  This is intended for a global store, not a local store (i.e. not by node), see ``LocalEventStore``
public struct GlobalEventStore {
    private var byIdMap : [EventID : Event] = [:]
    
    /// Store a new event or replace an existing stored event
    /// - Parameter node: new Node content
    mutating func store(_ event : Event) {
        byIdMap[event.eventID] = event
    }
    
    /// Retrieve an Event's content from the store
    /// - Parameter eventID: Look-up key
    /// - Returns: Returns Event, creating if need be
    // mutates to create non-existing event
    mutating func lookup(_ eventID : EventID) -> Event {
        if let event = byIdMap[eventID] {
            return event
        } else {
            let event = Event(eventID)
            store(event)
            return event
        }
    }
}
