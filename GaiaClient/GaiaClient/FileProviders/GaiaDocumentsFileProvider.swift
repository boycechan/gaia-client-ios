//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore

struct DocumentsFolder {
    func binFiles() -> [UpdateEntry] {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                        .userDomainMask,
                                                        true)
        guard let documentsDirectory = paths.first else {
            return []
        }

        do {
            let filePaths = try FileManager.default.subpathsOfDirectory(atPath: documentsDirectory)
            return filePaths
                .filter({ $0.hasSuffix(".bin") })
                .map({ UpdateEntry(id: documentsDirectory + "//\($0)", title: $0, description: String(localized: "File from Documents folder on this device.", comment: "File from Documents folder on this device.")) })
        } catch {
            return []
        }
    }
}

struct GaiaDocumentsFileProvider: GaiaUpdateFileListProvider {
    let showsOwnPicker = false
    func availableUpdates(completion: @escaping ([UpdateEntry]) -> ()) {
        let folder = DocumentsFolder()
        completion(folder.binFiles())
    }

    func dataForUpdateEntry(_ entry: UpdateEntry,
                            completion: @escaping FilePickerCompletionClosure,
                            cancellation: @escaping FilePickerCancellationClosure) {
        let url = URL(fileURLWithPath: entry.id)
        do {
            let data = try Data(contentsOf: url)
            completion(.success((info: entry, data: data)))
        } catch {
            completion(.failure(error))
        }
    }
}
