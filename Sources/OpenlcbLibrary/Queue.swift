//
//  Queue.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//  See https://medium.com/@JoyceMatos/data-structures-in-swift-queues-and-stacks-e7d715634f07
//

import Foundation
struct Queue<T> {
    var list = [T]()
    
    mutating func enqueue(_ element: T) {
        list.append(element)
    }
    mutating func dequeue() -> T? {
        if !list.isEmpty {
            return list.removeFirst()
        } else {
            return nil
        }
    }
    
    func peek() -> T? {
        if !list.isEmpty {
            return list[0]
        } else {
            return nil
        }
    }
    
    var isEmpty: Bool {
        return list.isEmpty
    }
    
}
