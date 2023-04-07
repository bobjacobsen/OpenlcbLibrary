//
//  FdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/25/22.
//

import Foundation
import os

/// Provide a model for use by e.g. a ThrottleView for function type and name information.
public class FdiModel : XmlModel, ObservableObject {
    
    @Published public var tree : [FdiXmlMemo] = [] // content!

    internal let throttleModel : ThrottleModel
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "FdiModel")
    
    public init (mservice : MemoryService, nodeID : NodeID, throttleModel: ThrottleModel ) {
        self.throttleModel = throttleModel
        super.init(mservice: mservice, nodeID: nodeID, space: 0xFA)
    }
    
    override internal func processAquiredText() {
        // reset the function model items to default content
        for index in 0...throttleModel.maxFn {
            throttleModel.fnModels[index].label = "FN \(index)"
        }

        // actually process it into an XML tree
        
        let processedData = FdiXmlMemo.process(savedDataString.data(using: .utf8)!)
                                               
        guard processedData.count > 0 else { return }
        guard processedData[0].children != nil else { return }

        tree = processedData[0].children! // index due to null base node
        
        // Copy the FDI definitions into the function model items, overwriting standard content
        let segment = tree[0]
        if let group = segment.children?[0] {
            // find the individual function elements
            for function in group.children! {
                let number = function.number
                let name = function.name
                let momentary = function.momentaryKind
                
                // get the FnModel to update
                if (number <= throttleModel.maxFn) {
                    throttleModel.fnModels[number].label = name
                    throttleModel.fnModels[number].momentary = momentary
                }
            }
        }
    }
    
}
