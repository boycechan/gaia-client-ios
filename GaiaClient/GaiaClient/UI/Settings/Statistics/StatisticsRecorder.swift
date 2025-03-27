//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

protocol StatisticsRecorderProtocol {
    func isRecording() -> Bool // Any
    func isRecording(category: StatisticCategories) -> Bool
    func startRecording(category: StatisticCategories) -> Bool
    func stopRecording(category: StatisticCategories) ->Bool
    func stopAllRecording()
    func eraseAllExpired()
}

public extension Notification.Name {
    static let StatisticsRecorderNotification = Notification.Name("StatisticsRecorderNotification")
}

public struct StatisticsRecorderNotification: GaiaNotification {
    public enum Reason {
        case fileClosed
    }

    public var sender: GaiaNotificationSender
    public var payload: StatisticsCategoryID
    public var reason: Reason

    public static var name: Notification.Name = .StatisticsRecorderNotification
}

class StatisticsRecorder: GaiaNotificationSender {
    struct FileInfo {
        let handle: FileHandle
        let path: URL
        var lines: UInt
    }

    static let sharedRecorder = StatisticsRecorder()

    private let MaxFileAge: Double = 200 //60 * 60 * 24 // 1 Day
    private let MaxLinesInFile: Int = 1000

    private var openFiles = Dictionary<StatisticsCategoryID, FileInfo>()

    private(set) var observerTokens = [ObserverToken]()

    private var device: GaiaDeviceProtocol?
    private var previousDeviceID: String?

    private var statisticsPlugin: GaiaDeviceStatisticsPluginProtocol? {
        return device?.plugin(featureID: .statistics) as? GaiaDeviceStatisticsPluginProtocol
    }

    func injectDevice(device newDevice: GaiaDeviceProtocol?) {
        if newDevice?.id == device?.id {
            return
        }

        if newDevice?.id == nil {
            // Probably a disconnection. Save old ID
            previousDeviceID = device?.id
        } else {
            if device?.id == nil {
                // Connection
                if (previousDeviceID != newDevice?.id) {
                    // Connection of different device
                    stopAllRecording()
                }
            }
        }

        device = newDevice
    }

    init() {
        eraseAllExpired()
        observerTokens.append(NotificationCenter.default.addObserver(forType: GaiaDeviceStatisticsPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.statisticsNotificationHandler(notification) }))
    }

    deinit {
        closeAllOpenFiles()
    }
}

extension StatisticsRecorder: StatisticsRecorderProtocol {
    func isRecording() -> Bool {
        return openFiles.count > 0
    }

    func isRecording(category: StatisticCategories) -> Bool {
        return getFileInfo(category: category) != nil
    }

    @discardableResult
    func startRecording(category: StatisticCategories) -> Bool {
        guard
            let url = filePath(category: category),
            getFileInfo(category: category) == nil
        else {
            return false
        }

        eraseAllExpired()
        do {
        	try NSData().write(to: url, options: [])
        } catch let e {
            print(e.localizedDescription)
            return false
        }

        if let handle = FileHandle(forUpdatingAtPath: url.path) {
            let fileInfo = FileInfo(handle: handle, path: url, lines: 1) // 1 as we're writing one line here
            openFiles[category.rawValue] = fileInfo

            handle.seekToEndOfFile()

            // Write titles

            let statistics = category.allStatistics()
            let timestamp = "Timestamp"
            var values = [timestamp]
            for statistic in statistics {
                let value = statistic.userVisibleName()
                values.append(value)
            }

            let row = values.joined(separator: ",") + "\n"
            if let data = row.data(using: .utf8) {
                handle.write(data)
                handle.synchronizeFile()
                return true
            }
        }
		return false
    }

    @discardableResult
    func stopRecording(category: StatisticCategories) -> Bool {
        guard let fileInfo = getFileInfo(category: category) else {
            return false
        }

        do{
            try fileInfo.handle.close()
        	openFiles[category.rawValue] = nil

            let notification = StatisticsRecorderNotification(sender: self,
                                                              payload: category.rawValue,
                                                              reason: .fileClosed)
            NotificationCenter.default.post(notification)
            return true
        } catch let e {
            print ("Error closing file: \(e.localizedDescription)")
            return false
        }
    }

    func stopAllRecording() {
        closeAllOpenFiles()
    }

    @discardableResult
    func addRow(category: StatisticCategories) -> Bool {
        guard let plugin = statisticsPlugin,
              let fileInfo = getFileInfo(category: category) else {
            return false
        }

        let statistics = category.allStatistics()
        let timestamp = "\(Date().timeIntervalSince1970)"
        var values = [timestamp]
        for statistic in statistics {
            let value = statistic.userVisibleValue(plugin: plugin) ?? ""
            values.append(value)
        }

        let row = values.joined(separator: ",") + "\n"
        if let data = row.data(using: .utf8) {
            fileInfo.handle.write(data)
            fileInfo.handle.synchronizeFile()
        }

        let newFileInfo = FileInfo(handle: fileInfo.handle, path: fileInfo.path, lines: fileInfo.lines + 1)
        openFiles[category.rawValue] = newFileInfo

        if newFileInfo.lines >= MaxLinesInFile {
            print("File too long - Closing \(newFileInfo.path)")
            stopRecording(category: category)
        }

        return true
    }

    func eraseAllExpired() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let enumerator = FileManager.default.enumerator(atPath: url.path)
        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".csv") {
                let fullPath = url.appendingPathComponent(file)
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: fullPath.path)
                    if let creationDate = attrs[.modificationDate] as? Date {
                        let fileAge = abs(creationDate.timeIntervalSinceNow)
                        print ("File: \(fullPath) Age: \(fileAge)")
                        if  fileAge > MaxFileAge {
                            print("removing file: \(fullPath)")
                            try FileManager.default.removeItem(atPath: fullPath.path)
                        }
                    }
                } catch let e {
                    print ("File error: \(e.localizedDescription)")
                }
            }
        }
    }
}

private extension StatisticsRecorder {
    func convertToValidFileName(filename: String) -> String {
        let invalidSet = CharacterSet.newlines.union(.illegalCharacters).union(.controlCharacters).union(CharacterSet(charactersIn: ":/"))
        return filename.components(separatedBy: invalidSet).joined(separator: "-")
    }

    func filePath(category: StatisticCategories) -> URL? {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let title = category.userVisibleName()

            let timestamp = "-\(Date().timeIntervalSince1970)"
            let filename = title + timestamp
            let normalisedFilename = convertToValidFileName(filename: filename)
            return url.appendingPathComponent(normalisedFilename).appendingPathExtension("csv")
        } else {
            return nil
        }
    }

    func closeAllOpenFiles() {
        let openFilesCopy = openFiles
        openFiles.removeAll()

        for (category, info) in openFilesCopy {
            info.handle.closeFile()
            let notification = StatisticsRecorderNotification(sender: self,
                                                              payload: category,
                                                              reason: .fileClosed)
            NotificationCenter.default.post(notification)
        }

    }

    func getFileInfo(category: StatisticCategories) -> FileInfo? {
        return openFiles[category.rawValue]
    }
}

private extension StatisticsRecorder {
    func statisticsNotificationHandler(_ notification: GaiaDeviceStatisticsPluginNotification) {
        switch notification.reason {
        case .statisticUpdated(let req, let moreComing):
            if !moreComing {
                guard let category = StatisticCategories(rawValue: req.category) else {
                    return
                }
                if isRecording(category: category) {
                    addRow(category: category)
                }
            }
        default:
            break
        }
    }
}
