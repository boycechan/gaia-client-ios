//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import CryptoKit
import CommonCrypto

extension Data {
    func md5() -> Data {
        if #available(iOS 13, *) {
            let digest = Insecure.MD5.hash(data: self)
            return Data(digest)
        } else {
            let length = Int(CC_MD5_DIGEST_LENGTH)
            var digest = [UInt8](repeating: 0, count: length)

            let _ = withUnsafeBytes {
                CC_MD5($0.baseAddress, CC_LONG(count), &digest)
            }
            return Data(digest)
        }
    }
}
