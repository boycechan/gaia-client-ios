//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

private extension StatisticsStatisticValueRequest {
    func data() -> Data {
        var entry = self.category.data()
        entry.append(self.statistic)
        return entry
    }
}


public class GaiaDeviceStatisticsPlugin: GaiaDeviceStatisticsPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getSupportedCategories = 0
        case getAllStatisticsInCategory = 1
        case getStatisticValues = 2
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter


    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .statistics

    public var supportedCategories: Set<StatisticsCategoryID> {
        return Set<StatisticsCategoryID> (valuesMap.keys)
    }

    typealias StatisticsMap = Dictionary<StatisticsStatisticID, Data>
    private var valuesMap = Dictionary<StatisticsCategoryID, StatisticsMap> ()

    // MARK: init/deinit
    public required init(version: UInt8,
                  device: GaiaDeviceIdentifierProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    // MARK: Public Methods
    public func startPlugin() {
        fetchCategoriesIfNotLoaded()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        switch messageDescription {
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                LOG(.medium, "Stats Response for \(id): \(data.map { String(format: "%02x", $0) }.joined())")
                switch id {
                case .getSupportedCategories:
                    processGetSupportedCategoriesResponse(data: data)
                case .getAllStatisticsInCategory:
                    processGetAllStatisticsInCategoryResponse(data: data)
                case .getStatisticValues:
                    processGetStatisticsValuesResponse(data: data)
                }
            }
        case .error(let command, let code, _):
            if let id = Commands(rawValue: command) {
                LOG(.high, "**** Statistic command failed \(id) code: \(code)****")
            }
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

public extension GaiaDeviceStatisticsPlugin {
    func fetchCategoriesIfNotLoaded() {
        if valuesMap.count != 0 {
            return
        }

        let message = GaiaV3GATTPacket(featureID: .statistics,
                                       commandID: Commands.getSupportedCategories.rawValue,
                                       payload: UInt16(0).data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func fetchAllStats(category: StatisticsCategoryID) {
        fetchAllStats(category: category, lastStatisticID: 0)
    }

    func fetchStatisticsValues(_ requests: [StatisticsStatisticValueRequest]) {
        // We batch in groups
        let maxPerPacketSend = Int(connection.maxSendPayloadSizeForGaia / 3)
        let maxPerPacketReceive = max(Int(connection.maxReceivePayloadSizeForGaia - 1 / 9), 1)

        let maxPerRequest = min(maxPerPacketSend, maxPerPacketReceive)

        var numberInCurrentRequest = 0
        var payloads = [Data]()
        var currentPayload = Data()

        for currentRequest in requests {
            currentPayload.append(contentsOf: currentRequest.data())
            numberInCurrentRequest += 1
            if numberInCurrentRequest == maxPerRequest {
                payloads.append(currentPayload)
                numberInCurrentRequest = 0
                currentPayload = Data()
            }
        }

        if !currentPayload.isEmpty {
            payloads.append(currentPayload)
        }

        for payload in payloads {
            let message = GaiaV3GATTPacket(featureID: .statistics,
                                           commandID: Commands.getStatisticValues.rawValue,
                                           payload: payload)
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }

    func getStatisticValue<T>(_ request: StatisticsStatisticValueRequest, type: T.Type) -> T? where T : FixedWidthInteger {
        let typeSize = MemoryLayout<T>.size

        guard
            let statValue = valuesMap[request.category]?[request.statistic],
            statValue.count == typeSize
        else {
            return nil
        }

        var result: T = 0
        for i in 0..<typeSize {
            result = (result << 8) + T(statValue[i])
        }
        return result
    }
}

private extension GaiaDeviceStatisticsPlugin {
    func fetchAllStats(category: StatisticsCategoryID, lastStatisticID: StatisticsStatisticID) {
        var payload = category.data()
        payload.append(lastStatisticID)

        let message = GaiaV3GATTPacket(featureID: .statistics,
                                       commandID: Commands.getAllStatisticsInCategory.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func processGetSupportedCategoriesResponse(data: Data) {
        guard
            let _ = device,
            data.count > 1,
            data.count % 2 == 1
        else {
            return
        }

    	let more = data[0] > 0
        var currentLast: StatisticsCategoryID = 0
        for offset in stride(from: 1, to: data.count, by: 2) {
            if let id = StatisticsCategoryID.init(data: data, offset: offset, bigEndian: true),
            id > currentLast {
                currentLast = id
                valuesMap[id] = Dictionary<StatisticsStatisticID, Data> ()
            }
        }

        if more && currentLast > 0 {
            let message = GaiaV3GATTPacket(featureID: .statistics,
                                           commandID: Commands.getAllStatisticsInCategory.rawValue,
                                           payload: currentLast.data())
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        } else {
            let notification = GaiaDeviceStatisticsPluginNotification(sender: self,
                                                                      payload: device!,
                                                                      reason: .categoriesUpdated)
            notificationCenter.post(notification)
        }
    }

    func processGetAllStatisticsInCategoryResponse(data: Data) {
        guard
            let _ = device,
            data.count > 3
        else {
            return
        }

        let more = data[0] > 0
        let category = StatisticsCategoryID.init(data: data, offset: 1, bigEndian: true)!

        var currentLast: StatisticsStatisticID = 0
        var offset = 3

        var valuesToNotify = [StatisticsStatisticValueRequest]()

        while (offset + 2) < data.count {
            let statisticID = data[offset]
            currentLast = statisticID
            // let flags = data[offset + 1]
            let length = Int(data[offset + 2])

            var value = Data()
            if offset + 2 + length < data.count {
                value = data.subdata(in: (offset + 3)..<(offset + 3 + length))
            }

            valuesMap[category]?[statisticID] = value
            let req = StatisticsStatisticValueRequest(category: category, statistic: statisticID)
            valuesToNotify.append(req)

            offset += 3 + length
        }

        for index in 0..<valuesToNotify.count {
            let req = valuesToNotify[index]
            let moreToNotify = (index != valuesToNotify.count - 1) || (more && currentLast > 0)
            let notification = GaiaDeviceStatisticsPluginNotification(sender: self,
                                                                      payload: device!,
                                                                      reason: .statisticUpdated(request: req, moreComing: moreToNotify))
            notificationCenter.post(notification)
        }

        if more && currentLast > 0 {
            fetchAllStats(category: category, lastStatisticID: currentLast)
        }
    }

    func processGetStatisticsValuesResponse(data: Data) {
        guard
            let _ = device,
            data.count > 1
        else {
            return
        }

        var offset = 1

        var valuesToNotify = [StatisticsStatisticValueRequest]()

        while (offset + 4) < data.count {
            let categoryID = StatisticsCategoryID.init(data: data, offset: offset, bigEndian: true)!
            let statisticID = data[offset + 2]
            // let flags = data[offset + 3]
            let length = Int(data[offset + 4])

            var value = Data()
            if offset + 4 + length < data.count {
                value = data.subdata(in: (offset + 5)..<(offset + 5 + length))
            }

            valuesMap[categoryID]?[statisticID] = value
            let req = StatisticsStatisticValueRequest(category: categoryID, statistic: statisticID)
            valuesToNotify.append(req)

            offset += 5 + length
        }

        for index in 0..<valuesToNotify.count {
            let req = valuesToNotify[index]
            let more = index != valuesToNotify.count - 1
            let notification = GaiaDeviceStatisticsPluginNotification(sender: self,
                                                                      payload: device!,
                                                                      reason: .statisticUpdated(request: req, moreComing: more))
            notificationCenter.post(notification)
        }
    }
}

