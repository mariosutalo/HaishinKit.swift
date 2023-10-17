public struct RingBuffer {
    private var array: [UInt8]
    private var readIndex = 0
    private var writeIndex = 0
    
    public init(count: Int) {
        array = Array(repeating: 0, count: count)
    }
    
    /* Returns false if out of space. */
    @discardableResult
    public mutating func write(_ element: UInt8) -> Bool {
        guard !isFull else { return false }
        defer {
            writeIndex += 1
        }
        array[writeIndex] = element
        return true
    }
    
    /* Returns nil if the buffer is empty. */
    public mutating func read() -> UInt8? {
        guard !isEmpty else { return nil }
        defer {
            //array[readIndex] = nil
            readIndex += 1
        }
        return array[readIndex]
    }
    
    public var availableSpaceForReading: Int {
        return writeIndex - readIndex
    }
    
    public var isEmpty: Bool {
        return availableSpaceForReading == 0
    }
    
    private var availableSpaceForWriting: Int {
        return array.count - availableSpaceForReading
    }
    
    public var isFull: Bool {
        return availableSpaceForWriting == 0
    }
    
    public mutating func appendRange(_ data: [UInt8]) {
        for x in data {
            self.write(x)
        }
    }
    
    public mutating func clearToIndex(index: Int) {
        readIndex = index
    }
    
    public mutating func clear() {
        readIndex = 0
        writeIndex = 0
    }
    public mutating func getData() -> Data{
        let pointer = UnsafeRawPointer(array)
        let newPointer = pointer.advanced(by: readIndex)
        //let buffer = Data(bytes: newPointer, count: writeIndex)
        let buffer = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: newPointer), count: availableSpaceForReading, deallocator: .none)
        //let buffer3 = buffer2
        //array[readIndex+1] = 122
        //print("buffer 3 bytes: \(buffer3.bytes)")
        //print("buffer bytes: \(buffer2.bytes)")
        return buffer
    }
}

extension RingBuffer: Sequence {
    public func makeIterator() -> AnyIterator<UInt8> {
        var index = readIndex
        return AnyIterator {
            guard index < self.writeIndex else { return nil }
            defer {
                index += 1
            }
            return self.array[wrapped: index]
        }
    }
}

private extension Array {
    subscript (wrapped index: Int) -> Element {
        get {
            return self[index % count]
        }
        set {
            self[index % count] = newValue
        }
    }
}
