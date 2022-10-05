//
//  FdiXmlMemo.swift
//  
//
//  Created by Bob Jacobsen on 9/25/22.
//

import Foundation

/// Representation of an FDI XML node
///
import Foundation

/// Represent an XML FDI tree as objects for use by e,g, FdiModel.
///
/// FdiiXmlMemo is a class so that reference semantics can be used to parts of the tree of memos.
/// The tree of FdiMemo objects only has downward links, so no cycles are created (nor allowed).
/// This doesn't track the memory locations, because traction control FDI doesn't have a corresponding configuration memory.
/// Instead, the absolute addresses are defined in the S&TN.
public final class FdiXmlMemo : Identifiable {
    
    /// Represent the type of each node.
    /// Maps to `FdiParserDelegate.NextTextOperation` states
    public enum XMLMemoType {
        case TOPLEVEL // FDI element itself
        case SEGMENT  // Segment is a top-level group
        case GROUP
        case FUNCTION
    }
    
    // common values
    public internal(set) var type : XMLMemoType
    public internal(set) var name : String
    public internal(set) var description : String
    public internal(set) var number : Int
    public internal(set) var binaryKind : Bool
    public internal(set) var momentaryKind : Bool

    // input values - usage determined by type
    public internal(set) var offset : Int                 // Initial offset from the FDI
    public internal(set) var space : Int
            
    public internal(set) var children : [FdiXmlMemo]?     // Optional required to display in SwiftUI.  Never nil here.
    
    public let id = UUID() // for Identifiable
        
    /// Copy ctor makes deep copy
    internal init(_ memo : FdiXmlMemo) {
        self.type = memo.type
        self.name = memo.name
        self.description = memo.description
        self.number = memo.number
        self.binaryKind = memo.binaryKind
        self.momentaryKind = memo.momentaryKind
        self.offset = memo.offset
        self.space = memo.space
        // make a recursive deep copy of memo.children
        self.children = nil
        if let children = memo.children {
            self.children = []
            for child in children {
                self.children!.append(FdiXmlMemo(child))
            }
        }
    }
    
    /// Null object ctor - for later fill-out
    internal init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.description = ""
        self.number = 0
        self.binaryKind = false
        self.momentaryKind = false
        self.offset = 0
        self.space = 0
        self.children = []
    }
    
    /// Take a String Data object containing FDI XML and process it into a FdiXmlMemo tree
    ///    Includes post-processing streps
    static public func process(_ data : Data) -> [FdiXmlMemo] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = FdiParserDelegate()
        parser.delegate = delegate
        
        // run the parser
        parser.parse()
        
        return delegate.memoStack
    }
}


