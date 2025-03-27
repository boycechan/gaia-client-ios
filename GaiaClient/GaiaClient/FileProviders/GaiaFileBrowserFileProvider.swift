//
//  © 2020-2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

class GaiaFileBrowserFileProvider: NSObject, GaiaUpdateFilePickerProvider {
    let showsOwnPicker = true
    private var completedClosure: FilePickerCompletionClosure?
    private var cancellationClosure: FilePickerCancellationClosure?

    func showPicker(viewController: UIViewController,
                    completion: @escaping FilePickerCompletionClosure,
                    cancellation: @escaping FilePickerCancellationClosure) {
        completedClosure = completion
        cancellationClosure = cancellation
        var picker: UIDocumentPickerViewController!
        if #available(iOS 14, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.archive])
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["com.apple.macbinary-archive"], in: .open)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        viewController.present(picker, animated: true, completion: nil)
    }
}

extension GaiaFileBrowserFileProvider: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        precondition(completedClosure != nil)
        precondition(cancellationClosure != nil)

        guard
            // controller.documentPickerMode == .open,
            let url = urls.first
        else {
            cancellationClosure!()
            return
        }

        if !url.startAccessingSecurityScopedResource() {
            let reasonStr = String(localized: "Couldn't access security scoped resource.", comment: "General error reason")
            let error = NSError(domain: "com.qualcomm.qti.gaiaclient", code: 0, userInfo: [NSLocalizedDescriptionKey : reasonStr])
            completedClosure!(.failure(error))
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        var coordError: NSError? = nil
        var fetchError: Error? = nil
        var fileData: Data? = nil

        NSFileCoordinator().coordinate(readingItemAt: url, error: &coordError) { (readURL) in
            do {
                fileData = try Data(contentsOf: readURL)
            } catch {
                fetchError = error
            }
        }

        if let error = coordError {
            completedClosure!(.failure(error))
            return
        }

        if let error = fetchError {
            completedClosure!(.failure(error))
            return
        }

        if let data = fileData {
            let info = UpdateEntry(id: url.absoluteString,
                                   title: url.lastPathComponent,
                                   description: String(localized: "File from remote file service.", comment: "File from remote file service."))
            completedClosure!(.success((info: info, data: data)))
        } else {
            let reasonStr = String(localized: "Unknown error.", comment: "General error reason")
            let error = NSError(domain: "com.qualcomm.qti.gaiaclient", code: 0, userInfo: [NSLocalizedDescriptionKey : reasonStr])
            completedClosure!(.failure(error))
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        precondition(cancellationClosure != nil)
        controller.dismiss(animated: true, completion: nil)
        cancellationClosure!()
    }
}
