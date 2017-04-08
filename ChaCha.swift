//
//  ChaCha.swift
//  ChaCha keystream generation
//
//  Copyright © 2017 JP Aumasson. All rights reserved.
//

import Foundation

public class ChaCha {

    let blockLen = 64
    let keyLen = 32
    let nonceLen = 12
    let doubleRounds = 10
    var v = [UInt32](repeating:0, count:16)

    fileprivate var key = [UInt32](repeating: 0, count: 8)
    fileprivate var counter = [UInt32](repeating: 0, count: 4)

    init(_ key: [UInt8], _ nonce:  [UInt8]) {
        precondition(key.count == keyLen)
        precondition(nonce.count == nonceLen)
        
        let keyData = Data(bytes: key)
        let nonceData = Data(bytes: nonce)

        for i in 0..<8 {
            self.key[i] = UInt32(littleEndian: keyData.subdata(in:(i*4)..<((i+1)*4)).withUnsafeBytes { $0.pointee })
        }

        self.counter[0] = 1
        self.counter[1] = UInt32(littleEndian: nonceData.subdata(in:0..<4).withUnsafeBytes { $0.pointee })
        self.counter[2] = UInt32(littleEndian: nonceData.subdata(in:4..<8).withUnsafeBytes { $0.pointee })
        self.counter[3] = UInt32(littleEndian: nonceData.subdata(in:8..<12).withUnsafeBytes { $0.pointee })
    }

    convenience init(_ key: [UInt8]) {
        let nonce = [UInt8](repeating: 0, count: 12)
        self.init(key, nonce)
    }

    fileprivate func ROTL32(_ word: UInt32, _ count: UInt32) -> UInt32 { 
        return ((word << count) ^ (word >> (32 - count)))
    }

    fileprivate func qround(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        v[a] = v[a] &+ v[b]
        v[d] = ROTL32(v[d] ^ v[a], 16)
        v[c] = v[c] &+ v[d]
        v[b] = ROTL32(v[b] ^ v[c], 12)
        v[a] = v[a] &+ v[b]
        v[d] = ROTL32(v[d] ^ v[a],  8)
        v[c] = v[c] &+ v[d]
        v[b] = ROTL32(v[b] ^ v[c], 7)
    }

    fileprivate func permuteAdd() {
        let w = v
        for _ in 0..<doubleRounds {
            qround(0, 4,  8, 12)
            qround(1, 5,  9, 13)
            qround(2, 6, 10, 14)
            qround(3, 7, 11, 15)
            qround(0, 5, 10, 15)
            qround(1, 6, 11, 12)
            qround(2, 7,  8, 13)
            qround(3, 4,  9, 14)
        }
        for i in 0..<16 {
            v[i] = v[i] &+ w[i]
        }
    }


    // returns a keystream block given the current counter value
    func keystreamBlock() -> [UInt8]{
        var out = [UInt8](repeating: 0, count: 64)
        v[0] = 0x61707865
        v[1] = 0x3320646e
        v[2] = 0x79622d32
        v[3] = 0x6b206574
        v[4..<12] = self.key[0..<8]
        v[12..<16] = self.counter[0..<4]

        permuteAdd()

        for i in 0..<16 {
            let byteArray = stride(from:0, through:24, by:8).map {
                UInt8(truncatingBitPattern: v[i] >> UInt32($0))
            }
            for j in 0..<4 {
                out[i*4 + j] = byteArray[j]
            }
        }

        self.counter[0] += 1
        return out
    }

    func keystream(_ outLen: Int) -> [UInt8] {
        precondition(outLen > 0)
        var count = outLen
        var out = [UInt8]()

        while count >= blockLen {
            out.append(contentsOf: self.keystreamBlock())
            count -= blockLen
        }
        if count > 0 {
            var left = self.keystreamBlock()
            out.append(contentsOf: left[0..<count])
        }
        return out
    }
}