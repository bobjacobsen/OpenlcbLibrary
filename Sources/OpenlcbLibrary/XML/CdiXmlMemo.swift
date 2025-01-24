//
//  CdiXmlMemo.swift
//  
//
//  Created by Bob Jacobsen on 6/19/22.
//

/// Representation of a CDI XML node
///
import Foundation

/// Represent an XML CDI tree as objects for use by e.g. `CdiModel`.
public final class CdiXmlMemo : Identifiable {
    // CdiXmlMemo is a class so that reference semantics can be used to parts of the tree of memos
    // The tree of CdiMemo objects only has downward links, so no cycles are created (nor allowed)

    /// Represent the type of each node.
    /// Maps to `CdiParserDelegate.NextTextOperation` states
    public enum XMLMemoType {
        case TOPLEVEL // cdi element itself
        case SEGMENT  // Segment is a top-level group
        case GROUP
        case GROUP_REP // child of group for replications > 1
        case INPUT_EVENTID
        case INPUT_INT
        case INPUT_STRING
        case MAP        // held within a INPUT_* node
        case UNKNOWN_SIZED // unknown (future) element with a size attribute
        case UNKNOWN_UNSIZED
    }
    
    // common values
    public internal(set) var type : XMLMemoType
    public internal(set) var name : String
    public internal(set) var repname : String
    public internal(set) var description : String
    
    // input values - usage determined by type
    public internal(set) var length : Int                 // Bytes for data types, replications for GROUP and GROUP_REP
    public internal(set) var offset : Int                 // Initial offset from the CDI
    public internal(set) var space : Int
    
    public internal(set) var defaultValue : Int
    public internal(set) var maxValue = 2_147_483_647     // 32 bit max, will be changed as needed
    public internal(set) var minValue = 0
    public internal(set) var maxSet = false
    public internal(set) var minSet = false

    public internal(set) var startAddress : Int           // Set on segment element, otherwise computed
    
    public var currentIntValue : Int
    public var currentStringValue : String

    public internal(set) var children : [CdiXmlMemo]?     // Optional required to display in SwiftUI.  Never nil here.
    
    public internal(set) var properties : [String] = []
    public internal(set) var values : [String] = []
    
    public let id = UUID() // for Identifiable
    
    // TODO: ACDI handling (see also CdiParserDelegate)
    // TODO: How to handle the identification block?  Present or not? Read-only
    
    /// Copy ctor makes deep copy
    internal init(_ memo : CdiXmlMemo) {
        self.type = memo.type
        self.name = memo.name
        self.repname = memo.repname
        self.description = memo.description
        self.length = memo.length
        self.offset = memo.offset
        self.space = memo.space
        self.startAddress = memo.startAddress
        self.defaultValue = memo.defaultValue
        self.minValue = memo.minValue
        self.maxValue = memo.maxValue
        self.minSet = memo.minSet
        self.maxSet = memo.maxSet
        self.currentIntValue = memo.currentIntValue
        self.currentStringValue = memo.currentStringValue
        // make a recursive deep copy of memo.children
        self.children = nil
        if let children = memo.children {
            self.children = []
            for child in children {
                self.children!.append(CdiXmlMemo(child))
            }
        }
        self.properties = []
        for property in memo.properties {
            self.properties.append(property)
        }
        self.values = []
        for value in memo.values {
            self.values.append(value)
        }

        
    }
    
    /// Null object ctor - for later fill-out
    internal init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.repname = ""
        self.description = ""
        self.length = 0
        self.offset = 0
        self.startAddress = 0
        self.space = 0
        self.defaultValue = 0
        self.currentIntValue = 0
        self.currentStringValue = ""
        self.children = []
    }
    
    /// Take a String Data object containing CDI XML and process it into a CdiXmlMemo tree
    ///    Includes post-processing streps
    static public func process(_ data : Data) -> [CdiXmlMemo] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate
        
        // run the parser
        parser.parse()
        // and post-process
        processGroupReplication(delegate.memoStack[0])
        _ = computeMemoryLocations(delegate.memoStack[0], space: 0, endAddress: 0)
        rmEmptyGroups(delegate.memoStack[0])
        
        return delegate.memoStack
    }
    
    // recurse through the Memo tree to expand group(replication>1) -> multiple GROUP_REP memos in the tree
    static private func processGroupReplication(_ memo : CdiXmlMemo) {
        if memo.type == .GROUP  && memo.length > 1 { // length holds replication count
            // here, replication is required
            // copy the current node to get children, etc,
            let newChildNode = CdiXmlMemo(memo) // includes making a deep copy
            newChildNode.type = .GROUP_REP // this will be the master that's copied for the new childen
            
            // drop children in prior memo
            memo.children = []  // clears old elements (int, event, even group) that are now in new sub-elements
            
            // add repl nodes as children of original
            for i in 1...memo.length {
                let tempChildNode = CdiXmlMemo(newChildNode)  // create a new, to-be child node
                tempChildNode.name = memo.repname+" \(i)"
                tempChildNode.offset = 0  // offset is only on original node, kept in place there
                memo.children?.append(tempChildNode)
            }
        }
        // done if needed here, descend into children (including the new .GROUP_REP nodes, which are just skipped over)
        if let children = memo.children {
            for child in children {
                processGroupReplication(child)
            }
        }
    }

    // Recursively scan the tree (depth first) assigning starting addresses.
    // Assumes that group expansion has already taken place (or won't be done)
    static private func computeMemoryLocations(_ memo : CdiXmlMemo, space : Int, endAddress : Int) -> Int {  // returns endAddress of entire memo subtree
        var nextSpace = space
        var newEndAddress = endAddress
        
        if memo.type == .SEGMENT {
            nextSpace = memo.space
            newEndAddress = memo.startAddress
        } else {
            memo.startAddress = endAddress+memo.offset
            if memo.type != .GROUP && memo.type != .GROUP_REP {  // in GROUP and GROUP_REP, length is replication count not bytes of length
                newEndAddress = memo.startAddress+memo.length
            } else {
                newEndAddress = memo.startAddress  // .GROUP and .GROUP_REP case
            }
        }
        memo.space = nextSpace
        
        //+ newEndAddress = newEndAddress+memo.offset
        
        // descend into children (including the new .GROUP_REP nodes)
        if let children = memo.children {
            for child in children {
                newEndAddress = computeMemoryLocations(child, space: nextSpace, endAddress: newEndAddress)
            }
        }
        // print ("node \(memo.name) end: \(newEndAddress) from: \(endAddress) type: \(memo.type) o: \(memo.offset)")
        return newEndAddress
    }

    /// Recursively scan the  tree, removing any groups that have none of
    ///  - child nodes, i.e. content
    ///  - name
    ///  - or a description
    ///  By removing them as part of processing, we remove empty lines in the display.
    ///  Should be run after memory address computation, as may remove a group with an offset
    static private func rmEmptyGroups(_ memo : CdiXmlMemo) {
        // descend into children, removing nested groups as necessary
        if let children = memo.children {
            for child in children {
                rmEmptyGroups(child)
            }
        }

        // and check that this node's children can now be removed, taking into account that children might be already removed
        if let children = memo.children {
            //for (index, child) in children.enumerated() {
            for index in stride(from: children.count-1, through: 0, by: -1) { // have to go in reverse to allow deletion w/o changing index
                let child = children[index]
                // check for empty child that can be removed.                
                if child.type == .GROUP && child.name.isEmpty && child.description.isEmpty && (child.children == nil || child.children!.count == 0) {
                    // Remove this child element
                    memo.children?.remove(at: index)
                }
            }
        }
    }

}


