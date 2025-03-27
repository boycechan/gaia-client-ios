//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

/// File Providers are used to provide the binary files used in DFU. There are two protocols and currently two concrete implementations.
/// The two protocols differ in that GaiaUpdateFilePickerProvider is for those occasions where a system picker is used to select the file, whereas
/// GaiaUpdateFileListProvider is used where the app itself handles the selection of the file. Both protocols ultimately provide the DFU file contents in a Data
/// object.
protocol GaiaUpdateFileProvider {
/// Does the file provider show it's own picker.
    var showsOwnPicker: Bool { get }
}

typealias FilePickerCompletionClosure = (Result<(info: UpdateEntry,data: Data), Error>) -> ()
typealias FilePickerCancellationClosure = () -> ()

/// Protocol to describe those File Providers that use a system picker to select a DFU file.
protocol GaiaUpdateFilePickerProvider: GaiaUpdateFileProvider {
/// Show the relevant system picker to select the file. The data of any selected file is provided to the completion block.
/// - Parameter viewController: The view controller that will be used to present the picker.
/// - Parameter completion: The block that will be invoked when the selection has been made. If a file was selected and the file contenst were retrievable then the file data is passed to the block. If no selection was made or the file data is unavailable nil is passed to the block.
    func showPicker(viewController: UIViewController, completion: @escaping FilePickerCompletionClosure, cancellation: @escaping FilePickerCancellationClosure)
}

/// Update Entry describes an available DFU file.
struct UpdateEntry: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let chipname: String
    let date: Date
    let filters: [String]
    let hardwareVersions: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case chipname = "chipFamily"
        case date = "createdOn"
        case filters = "tags"
        case hardwareVersions
    }

    init(id: String, title: String, description: String = "", chipname: String = "", date: Date = Date(), filters: [String] = [String](), hardwareVersions: [String] = [String]()) {
        self.id = id
        self.title = title
        self.description = description
        self.chipname = chipname
        self.date = date
        self.filters = filters
        self.hardwareVersions = hardwareVersions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? String(localized: "No Title", comment: "Default for unknown title")
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? String(localized: "No Description", comment: "Default for unknown description")
        self.chipname = try container.decodeIfPresent(String.self, forKey: .chipname) ?? String(localized: "Unknown Platform", comment: "Default for unknown chipname")
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.filters = try container.decodeIfPresent([String].self, forKey: .filters) ?? [String]()
        self.hardwareVersions = try container.decodeIfPresent([String].self, forKey: .hardwareVersions) ?? [String]()
    }
}


/// Protocol to describe those File Providers that do not use a system picker to select a file. Instead these providers provide a list of files and the application itself should handle presentation and selection.
protocol GaiaUpdateFileListProvider: GaiaUpdateFileProvider {
/// Provides a list of the available update files
/// - Parameter completion: Block invoked to provide list of available DFU files. This provided array may be empty.
    func availableUpdates(completion: @escaping ([UpdateEntry]) -> ())
    /// Provides the binary contents of the chosen update file.
    /// - Parameter completion: Block invoked to provide list of available DFU files. This provided array may be empty.
    func dataForUpdateEntry(_ entry: UpdateEntry, completion: @escaping FilePickerCompletionClosure, cancellation: @escaping FilePickerCancellationClosure)
}
