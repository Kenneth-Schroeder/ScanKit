//
//  MetalBuffer.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 17.08.21, partly copied from Apple Inc. code samples
//

import MetalKit

protocol Resource {
    associatedtype Element
}

/// A wrapper around MTLBuffer which provides type safe access and assignment to the underlying MTLBuffer's contents.

struct MetalBuffer<Element>: Resource { // , Sequence
        
    /// The underlying MTLBuffer.
    fileprivate let buffer: MTLBuffer
    
    /// The index that the buffer should be bound to during encoding.
    /// Should correspond with the index that the buffer is expected to be at in Metal shaders.
    fileprivate let index: Int
    
    /// The number of elements of T the buffer can hold.
    let count: Int
    var stride: Int {
        MemoryLayout<Element>.stride
    }

    /// Initializes the buffer with zeros, the buffer is given an appropriate length based on the provided element count.
    init(device: MTLDevice, count: Int, index: UInt32, label: String? = nil, options: MTLResourceOptions = []) {
        
        guard let buffer = device.makeBuffer(length: MemoryLayout<Element>.stride * count, options: options) else {
            fatalError("Failed to create MTLBuffer.")
        }
        self.buffer = buffer
        self.buffer.label = label
        self.count = count
        self.index = Int(index)
    }
    
    /// Initializes the buffer with the contents of the provided array.
    init(device: MTLDevice, array: [Element], index: UInt32, options: MTLResourceOptions = []) {
        
        guard let buffer = device.makeBuffer(bytes: array, length: MemoryLayout<Element>.stride * array.count, options: .storageModeShared) else {
            fatalError("Failed to create MTLBuffer")
        }
        self.buffer = buffer
        self.count = array.count
        self.index = Int(index)
    }
    
    //func makeIterator() -> MetalBufferIterator<Element> {
    //    return MetalBufferIterator<Element>(self, 10)
    //}
    
    /// Replaces the buffer's memory at the specified element index with the provided value.
    func assign<T>(_ value: T, at index: Int = 0) {
        precondition(index <= count - 1, "Index \(index) is greater than maximum allowable index of \(count - 1) for this buffer.")
        withUnsafePointer(to: value) {
            buffer.contents().advanced(by: index * stride).copyMemory(from: $0, byteCount: stride)
        }
    }
    
    /// Replaces the buffer's memory with the values in the array.
    func assign<Element>(with array: inout [Element]) { // inout should increase performance here
        let byteCount = array.count * stride
        precondition(byteCount <= buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        buffer.contents().copyMemory(from: array, byteCount: byteCount)
    }
    
    /// Replaces the buffer's memory with the values in the array.
    func assign<Element>(with array: [Element]) { // without inout for copy by value
        let byteCount = array.count * stride
        precondition(byteCount <= buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        buffer.contents().copyMemory(from: array, byteCount: byteCount)
    }
    
    /// copies the content of the buffer to a swift array
    func copyTo<Element>(_ array: inout [Element]) { // inout important for actual by reference modification
        let byteCount = array.count * stride
        precondition(byteCount <= buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        memcpy( &array, buffer.contents(), byteCount)
    }
    
    /// Returns a copy of the value at the specified element index in the buffer.
    subscript(index: Int) -> Element {
        get {
            precondition(stride * index <= buffer.length - stride, "This buffer is not large enough to have an element at the index: \(index)")
            return buffer.contents().advanced(by: index * stride).load(as: Element.self)
        }
        
        set {
            assign(newValue, at: index)
        }
    }
    
}

/*
class MetalBufferIterator<Element>: IteratorProtocol {
    private let buffer: MetalBuffer<Element>
    private var index = 0
    private var maxIndex = 0

    init(_ buffer: MetalBuffer<Element>, _ maxIndex: Int) {
        self.buffer = buffer
        self.maxIndex = maxIndex
    }

    func next() -> Element? {
        defer { index += 1 }
        return index <= maxIndex ? buffer[index] : nil
    }
}*/

// Note: This extension is in this file because access to Buffer<T>.buffer is fileprivate.
// Access to Buffer<T>.buffer was made fileprivate to ensure that only this file can touch the underlying MTLBuffer.
extension MTLRenderCommandEncoder {
    func setVertexBuffer<T>(_ vertexBuffer: MetalBuffer<T>, offset: Int = 0) {
        setVertexBuffer(vertexBuffer.buffer, offset: offset, index: vertexBuffer.index)
    }
    
    func setVertexBuffer<T>(_ vertexBuffer: MetalBuffer<T>, atCustomIndex:Int, offset: Int = 0) {
        setVertexBuffer(vertexBuffer.buffer, offset: offset, index: atCustomIndex)
    }
    
    func setFragmentBuffer<T>(_ fragmentBuffer: MetalBuffer<T>, offset: Int = 0) {
        setFragmentBuffer(fragmentBuffer.buffer, offset: offset, index: fragmentBuffer.index)
    }
    
    func setVertexResource<R: Resource>(_ resource: R) {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setVertexBuffer(buffer)
        }
        
        if let texture = resource as? Texture {
            setVertexTexture(texture.texture, index: texture.index)
        }
    }
    
    func setFragmentResource<R: Resource>(_ resource: R) {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setFragmentBuffer(buffer)
        }

        if let texture = resource as? Texture {
            setFragmentTexture(texture.texture, index: texture.index)
        }
    }
}

struct Texture: Resource {
    typealias Element = Any
    
    let texture: MTLTexture
    let index: Int
}
