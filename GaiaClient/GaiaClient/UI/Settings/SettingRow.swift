//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

enum SettingRow {
    case title(title: String, tapable: Bool)
    case titleAndSubtitle(title: String, subtitle: String, tapable: Bool)
    case titleAndSwitch(title: String, switchOn: Bool)
    case titleSubtitleAndSlider(title: String, subtitle: String, value: Int, min: Int, max: Int)
}

protocol SectionIdentifier { }

struct SettingSection {
    var identifier: SectionIdentifier?
    let title: String?
    let rows: [SettingRow]
}
