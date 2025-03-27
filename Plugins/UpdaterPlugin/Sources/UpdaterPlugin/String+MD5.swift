//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

extension String {
    func md5() -> String {
        let strData = Data(self.utf8)
        let digestData = strData.md5()
        return digestData.map { String(format: "%02x", $0) }.joined()
    }
}
