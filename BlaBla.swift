//
//  BlaBla.swift
//  Like ChaCha, but with BLAKE2b (2x larger blocks, faster)
//
//  Copyright © 2017 JP Aumasson. All rights reserved.
//

import Foundation

public class BlaBla {

    let blockLen = 128
    let keyLen = 32
    let nonceLen = 16
    let nbRounds = 10
    var v = [UInt64](repeating:0, count:16)

    fileprivate var key = [UInt64](repeating: 0, count: 4)
    fileprivate var counter = [UInt64](repeating: 0, count: 3)

    init(_ key: [UInt8], _ nonce: [UInt8]) {
        precondition(key.count == keyLen)
        precondition(nonce.count == nonceLen)
        
        let keyData = Data(bytes: key)
        let nonceData = Data(bytes: nonce)

        for i in 0..<4 {
            self.key[i] = UInt64(littleEndian: keyData.subdata(in:(i*8)..<((i+1)*8)).withUnsafeBytes { $0.pointee })
        }

        self.counter[0] = 1
        self.counter[1] = UInt64(littleEndian: nonceData.subdata(in:0..<8).withUnsafeBytes { $0.pointee })
        self.counter[2] = UInt64(littleEndian: nonceData.subdata(in:8..<16).withUnsafeBytes { $0.pointee })
    }

    convenience init(_ key: [UInt8]) {
        let nonce = [UInt8](repeating: 0, count: 16)
        self.init(key, nonce)
    }

    fileprivate func ROTR64(_ word: UInt64, _ count: UInt64) -> UInt64 { 
        return ((word >> count) ^ (word << (64 - count)))
    }

    fileprivate func G(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        v[a] = v[a] &+ v[b]
        v[d] = ROTR64(v[d] ^ v[a], 32)
        v[c] = v[c] &+ v[d]
        v[b] = ROTR64(v[b] ^ v[c], 24)
        v[a] = v[a] &+ v[b]
        v[d] = ROTR64(v[d] ^ v[a], 16)
        v[c] = v[c] &+ v[d]
        v[b] = ROTR64(v[b] ^ v[c], 63)
    }
    
    fileprivate func permuteAdd() {
        let w = v
        for _ in 0..<nbRounds {
            G(0, 4, 8, 12) 
            G(1, 5, 9, 13) 
            G(2, 6,10, 14) 
            G(3, 7,11, 15)
            G(0, 5,10, 15)
            G(1, 6,11, 12)
            G(2, 7, 8, 13)
            G(3, 4, 9, 14)
        }
        for i in 0..<16 {
            v[i] = v[i] &+ w[i]
        }
    }

    // returns a keystream block given the current counter value
    func keystreamBlock() -> [UInt8]{
        var out = [UInt8](repeating: 0, count: 128)
        v[0] = 0x6170786593810fab
        v[1] = 0x3320646ec7398aee
        v[2] = 0x79622d3217318274
        v[3] = 0x6b206574babadada
        v[4..<8] = self.key[0..<4]
        v[8] = 0x2ae36e593e46ad5f
        v[9] = 0xb68f143029225fc9
        v[10] = 0x8da1e08468303aa6
        v[11] = 0xa48a209acd50a4a7
        v[12] = 0x7fdc12f23f90778c
        v[13..<16] = self.counter[0..<3]

        permuteAdd()

        for i in 0..<16 {
            let byteArray = stride(from:0, through:56, by:8).map {
                UInt8(truncatingBitPattern: v[i] >> UInt64($0))
            }
            for j in 0..<8 {
                out[i*8 + j] = byteArray[j]
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

// $ switfc -DTESTING BlaBla.swift && ./BlaBla
#if TESTING
var key = [UInt8](repeating: 0, count: 32)
for i in 0..<32 { key[i] = UInt8(i) }
var bla = BlaBla(key)
let ks = bla.keystream(300)
let blablabla: [UInt8] = [173, 80, 254, 123, 103, 188, 241, 234, 16, 130, 154, 201, 95, 86, 3, 99, 72, 175, 218, 238, 238, 136, 184, 20, 133, 42, 223, 58, 55, 33, 216, 12, 166, 112, 185, 55, 193, 11, 119
, 227, 146, 58, 124, 149, 74, 197, 80, 118, 0, 218, 217, 174, 61, 137, 91, 97, 40, 16, 211, 53, 189, 200, 89, 37, 141, 101, 46, 178, 2, 88, 27, 29, 13, 78, 105, 28, 101, 122, 99,
 76, 252, 86, 87, 240, 169, 109, 187, 179, 192, 248, 16, 51, 90, 208, 222, 25, 0, 61, 209, 146, 176, 15, 28, 175, 43, 125, 235, 39, 67, 125, 251, 218, 135, 66, 3, 219, 156, 251,
221, 170, 137, 26, 84, 134, 231, 202, 116, 30, 126, 12, 146, 166, 195, 17, 233, 23, 50, 126, 236, 147, 63, 218, 165, 117, 37, 218, 219, 175, 191, 69, 142, 246, 98, 178, 17, 228,
142, 61, 231, 209, 67, 50, 195, 31, 217, 83, 25, 170, 233, 222, 82, 119, 102, 13, 94, 187, 62, 169, 14, 233, 217, 116, 190, 169, 178, 44, 38, 158, 186, 231, 118, 233, 236, 192, 
108, 123, 105, 234, 169, 98, 208, 139, 87, 190, 110, 59, 114, 166, 114, 68, 174, 94, 192, 24, 47, 9, 149, 219, 84, 153, 231, 24, 148, 202, 204, 210, 238, 37, 156, 78, 239, 45, 42,
 80, 144, 38, 182, 156, 240, 47, 170, 99, 8, 114, 35, 202, 242, 241, 198, 102, 21, 239, 48, 72, 43, 224, 29, 79, 215, 132, 82, 79, 224, 241, 161, 20, 190, 241, 81, 148, 70, 148,
88, 107, 47, 30, 5, 41, 226, 224, 81, 95, 96, 50, 159, 96, 221, 242, 17, 214, 22, 109, 12, 153, 96, 196, 6, 102, 109, 90]
 if (ks == blablabla) {
    print("looks good")
 }
 else {
     print("something's wrong")
}
#endif