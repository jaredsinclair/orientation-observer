//
//  RingBuffer.swift
//  OrientationObserver
//
//  Created by Jared Sinclair on 1/1/20.
//  Copyright © 2020 Nice Boy, LLC. All rights reserved.
//

public struct RingBuffer<Element> {

    @usableFromInline
    internal var buffer: ContiguousArray<Element?>

    @usableFromInline
    internal var headIndex: Index

    @usableFromInline
    internal var tailIndex: Index

    @inlinable
    public init(capacity: Int) {
        precondition(capacity > 1, "RingBuffer does not support capacities that small.")
        buffer = ContiguousArray(repeating: nil, count: capacity)
        headIndex = Index(rawValue: 0)
        tailIndex = Index(rawValue: 1)
    }

}

extension RingBuffer : RangeReplaceableCollection {

    @inlinable
    public init() {
        self.init(capacity: 16)
    }

    @inlinable
    public mutating func append(_ newElement: Element) {
        buffer[tailIndex] = newElement
        headIndex = headIndex.incrementedByOne(for: self)
        tailIndex = tailIndex.incrementedByOne(for: self)
    }

}

extension RingBuffer : Collection {

    public struct Index {

        @usableFromInline
        internal let rawValue: Int

        @inlinable
        internal init(rawValue: Int) {
            self.rawValue = rawValue
        }

        @inlinable
        internal isValid(for ring: RingBuffer<Element>) -> Bool {
            (0..<ring.buffer.count).contains(rawValue)
        }

        @inlinable
        internal func incrementedByOne(for ring: RingBuffer<Element>) -> Index {
            let next = rawValue + 1
            return (next >= ring.buffer.count) ? .zero : Index(rawValue: next)
        }

        @inlinable
        static let zero = Index(rawValue: 0)

    }

    @inlinable
    public var startIndex: Index { headIndex }

    @inlinable
    public var endIndex: Index { tailIndex }

    @inlinable
    public subscript(position: Index) -> Element {
        assert(position.isValid(for: self), "Invalid index: \(position)")
        return buffer[position.rawValue]!
    }

    @inlinable
    public func index(after i: Index) -> Index {
        return i.incrementedByOne(for: self)
    }

}

extension RingBuffer.Index : Comparable {

    public static func < (lhs: RingBuffer<Element>.Index, rhs: RingBuffer<Element>.Index) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

}
