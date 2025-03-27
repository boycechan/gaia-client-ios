//
//  File.swift
//  
//
//  Created by Stephen Flack on 08/11/2023.
//

import Foundation

public extension Int16 {
    init?(data: Data, offset: Int = 0, bigEndian: Bool = true) {
        guard
            offset + 2 <= data.count,
            let unsigned = UInt16(data: data, offset: offset, bigEndian: bigEndian)
        else {
            return nil
        }
        
        self = Int16(bitPattern: unsigned)
    }

    func data(bigEndian: Bool = true) -> Data {
        let unsigned = UInt16(bitPattern: self)
        return unsigned.data(bigEndian: bigEndian)
    }
}

