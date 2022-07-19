//
//  CanPhysicalLayerGridConnect.swift
//  
//
//  Created by Bob Jacobsen on 6/14/22.
//

/// Provide a CanPhysicalLayer for GridConnect format strings
///
/// Works with frames like
///         :X19490365N;
///         :X19170365N020112FE056C;

import Foundation
import os

public class CanPhysicalLayerGridConnect : CanPhysicalLayer {
    
    let logger = Logger(subsystem: "org.ardenwood.OpenlcbLibrary", category: "CanPhysicalLayerGridConnect")
    // callback to send a string-formatted frame over the link
    let canSendCallback : (_ : String) -> ()  // argument is the text to be send, including \n as needed
    
    public init( callback : @escaping (_ : String) -> () ) {
        canSendCallback = callback
    }
    
    override func sendCanFrame(_ frame : CanFrame) {
        var output  = ":X\(String(format:"%08X", frame.header))N"
        for byte in frame.data {
            output += "\(String(format:"%02X", byte))"
        }
        output += ";\n"
        // logger.debug("sending to link \(output, privacy: .public)")
        canSendCallback(output)
    }
    
    var inboundBuffer : [UInt8] = []
    
    /// Receive a string from the outside link to be parsed
    public func receiveString(string : String) {
        receiveChars(data: Array(string.utf8))
    }
    
    /// Provide characters from the outside link to be parsed
    public func receiveChars(data : [UInt8]) {
        //logger.debug("receive \(data, privacy: .public)")
        inboundBuffer += data
        var lastByte = 0
        if inboundBuffer.contains(0x3B) {  // ';' ends message so we have at least one
            // found end, now find start
            for index in 0...inboundBuffer.count-1 {
                var outData : [UInt8] = []
                if !inboundBuffer[index...inboundBuffer.count-1].contains(0x3B) { break }
                if inboundBuffer[index] == 0x3A { // ':' starts message
                    // now start to accumulate data from entire message
                    var header : UInt = 0
                    for offset in 2...9 {
                        let nextChar = UInt(inboundBuffer[index+offset])
                        let nextByte = nextChar > 0x39 ? (nextChar & 0xF)+9 : nextChar & 0xF
                        header = (header<<4)+nextByte
                    }
                    // offset 10 is N
                    // offset 11 might be data, might be ;
                    lastByte = index+11
                    for dataItem in 0...8 {
                        if inboundBuffer[index+11+2*dataItem] == 0x3B { break }
                        // two characters are data
                        let byte1 = inboundBuffer[index+11+2*dataItem]
                        let part1 = byte1 > 0x39 ? (byte1 & 0xF)+9 : byte1 & 0xF
                        let byte2 = inboundBuffer[index+11+2*dataItem+1]
                        let part2 = byte2 > 0x39 ? (byte2 & 0xF)+9 : byte2 & 0xF
                        outData += [part1<<4 | part2]
                        lastByte += 2
                    }
                    // lastByte is index of ; in this message
                    
                    let cf = CanFrame(header : header, data: outData)
                    // logger.debug("received from link \(cf, privacy: .public)")
                    fireListeners(cf)
                }
            }
            // shorten buffer
            inboundBuffer = Array(inboundBuffer[lastByte...inboundBuffer.count-1])
        }
        

    }
    
    
}
