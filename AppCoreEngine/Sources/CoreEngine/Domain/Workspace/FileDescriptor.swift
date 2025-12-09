import Foundation

public struct FileID: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum FileType: String, Codable, Sendable {
    case file
    case directory
}

/// Pure, UI-free workspace node representation.
public struct FileDescriptor: Codable, Sendable, Hashable {
    public let id: FileID
    public let name: String
    public let type: FileType
    public let canonicalPath: String
    public let language: String?
    public let size: Int
    public let hash: String
    public let children: [FileID]

    /// Backwards-compatible initializer; callers should migrate to provide canonical metadata.
    public init(
        id: FileID = FileID(),
        name: String,
        type: FileType,
        children: [FileID] = [],
        canonicalPath: String = "",
        language: String? = nil,
        size: Int = 0,
        hash: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.canonicalPath = canonicalPath
        self.language = language
        self.size = size
        self.hash = hash
        self.children = children
    }

    public static func hashFor(contents: Data) -> String {
        return StableHasher.sha256(data: contents)
    }
}

// Minimal SHA256 (pure Swift) for deterministic hashing without external deps.
enum StableHasher {
    static func sha256(data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: data)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct SHA256 {
    private var message: [UInt8] = []
    private var h: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    mutating func update(data: Data) {
        message += data
    }

    mutating func finalize() -> [UInt8] {
        var msg = message
        let bitLength = UInt64(msg.count * 8)
        msg.append(0x80)
        while (msg.count % 64) != 56 { msg.append(0) }
        msg.append(contentsOf: bitLength.bytes)

        for chunk in msg.chunked(into: 64) {
            process(chunk)
        }
        return h.flatMap { $0.bytes }
    }

    private mutating func process(_ chunk: ArraySlice<UInt8>) {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            let offset = chunk.startIndex + i * 4
            w[i] = UInt32(chunk[offset]) << 24
                | UInt32(chunk[offset + 1]) << 16
                | UInt32(chunk[offset + 2]) << 8
                | UInt32(chunk[offset + 3])
        }
        for i in 16..<64 {
            let s0 = w[i - 15].rotateRight(7) ^ w[i - 15].rotateRight(18) ^ (w[i - 15] >> 3)
            let s1 = w[i - 2].rotateRight(17) ^ w[i - 2].rotateRight(19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }

        var a = h[0], b = h[1], c = h[2], d = h[3]
        var e = h[4], f = h[5], g = h[6], hVal = h[7]

        for i in 0..<64 {
            let s1 = e.rotateRight(6) ^ e.rotateRight(11) ^ e.rotateRight(25)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = hVal &+ s1 &+ ch &+ k[i] &+ w[i]
            let s0 = a.rotateRight(2) ^ a.rotateRight(13) ^ a.rotateRight(22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 &+ maj

            hVal = g
            g = f
            f = e
            e = d &+ temp1
            d = c
            c = b
            b = a
            a = temp1 &+ temp2
        }

        h[0] &+= a
        h[1] &+= b
        h[2] &+= c
        h[3] &+= d
        h[4] &+= e
        h[5] &+= f
        h[6] &+= g
        h[7] &+= hVal
    }

    private let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152,
        0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138,
        0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70,
        0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa,
        0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
}

private extension Array where Element == UInt8 {
    func chunked(into size: Int) -> [ArraySlice<UInt8>] {
        stride(from: 0, to: count, by: size).map { i in
            self[i..<Swift.min(i + size, count)]
        }
    }
}

private extension UInt64 {
    var bytes: [UInt8] {
        (0..<8).reversed().map { UInt8((self >> (UInt64($0) * 8)) & 0xff) }
    }
}

private extension UInt32 {
    var bytes: [UInt8] {
        (0..<4).reversed().map { UInt8((self >> (UInt32($0) * 8)) & 0xff) }
    }

    func rotateRight(_ n: UInt32) -> UInt32 {
        (self >> n) | (self << (32 - n))
    }
}

