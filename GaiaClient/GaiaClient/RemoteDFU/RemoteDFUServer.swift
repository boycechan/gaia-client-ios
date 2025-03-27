//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

import GaiaCore

class RemoteDFUServer {
    enum FilterState: Encodable {
        case none
        case required
        case excluded
    }

    struct FilterKey : CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    struct PropertyFilter: Encodable {
        let id: String
        let description: String
        let state: FilterState
    }

    struct DateFilter: Encodable {
        let id: String
        let description: String
        let date: Date
    }

    enum Filter: Encodable {
        case property(PropertyFilter)
        case date(DateFilter)
    }

    struct UpdateRequest: Encodable {
        let id: String
        let applicationVersion: String
        let hardwareVersion: String
        let filters: [Filter]

        enum CodingKeys: String, CodingKey {
            case id, applicationVersion, hardwareVersion
            case filters = "filter"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(applicationVersion, forKey: .applicationVersion)
            try container.encode(hardwareVersion, forKey: .hardwareVersion)

            var keyContainer = container.nestedContainer(keyedBy: FilterKey.self, forKey: .filters)

            var reqdTruePropertyFilters = [String]()
            var reqdFalsePropertyFilters = [String]()
            for filter in filters {
                switch filter {
                case .property(let property):
                    switch property.state {
                    case .required:
                        reqdTruePropertyFilters.append(property.id)
                    case .excluded:
                        reqdFalsePropertyFilters.append(property.id)
                    default:
                        break
                    }
                case .date(let date):
                    let key = FilterKey(stringValue: date.id)!
                    try keyContainer.encode(date.date, forKey: key)
                }
            }
            try keyContainer.encode(reqdTruePropertyFilters, forKey: FilterKey(stringValue: "trueTags")!)
            try keyContainer.encode(reqdFalsePropertyFilters, forKey: FilterKey(stringValue: "falseTags")!)
        }
    }

    struct UpdateResponse: Decodable {
        let builds: [UpdateEntry]
    }


    typealias ProgressCallback = (Int, Int) -> ()

    public static let shared = RemoteDFUServer()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var baseServerURL: String?

    var supported: Bool {
        baseServerURL != nil
    }
    
    var filters = [Filter]()

    enum DateError: String, Error {
        case format
    }

    init() {

		baseServerURL = defaultServer()
		filters = defaultFilters()

        encoder.outputFormatting = [.prettyPrinted , .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = .current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateStr) {
                return date
            }

            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: dateStr) {
                return date
            }

            throw DateError.format
        })
    }


    func checkForUpdatesNow(buildId: String, appId: String, hardwareId: String) async throws -> [UpdateEntry] {
        guard let baseServerURL,
              Reachability.shared.isReachable else {
            throw RemoteServerError.connectivity
        }

        let reqInfo = UpdateRequest(id: buildId,
                                    applicationVersion: appId,
                                    hardwareVersion: hardwareId,
                                    filters: filters)
        var reqData: Data
        do {
            reqData = try encoder.encode(reqInfo)
        } catch {
            throw RemoteServerError.format
        }

        var tokenStr = ""
        if let token = getToken() {
            tokenStr = "?token=\(token)"
        }
        let concat = baseServerURL + "/builds" + tokenStr
        guard let url = URL(string: concat) else {
            throw RemoteServerError.configuration
        }

        print ("JSON: \(String(decoding: reqData, as: UTF8.self))")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("\(reqData.count)", forHTTPHeaderField: "Content-Length")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = reqData

        var (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let error {
            print ("\(error)")
            throw RemoteServerError.connectivity
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            var errorResponse: ErrorResponse
            do {
                errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            } catch {
                let strValue = String(decoding: data, as: UTF8.self)
                let resp = ErrorResponse(status: "\((response as? HTTPURLResponse)?.statusCode ?? 0)",
                                         id: "UNKNOWN",
                                         message: strValue)
                throw RemoteServerError.errorResponse(resp)
            }
            throw RemoteServerError.errorResponse(errorResponse)
        }

        do {
            let decodedResponse: UpdateResponse = try decoder.decode(UpdateResponse.self, from: data)
            return decodedResponse.builds
        } catch let error {
            print ("Error: \(error)")
            throw RemoteServerError.format
        }
    }


	// Note callback is called on main queue.
    func fetchUpdate(id: String, progress callback: ProgressCallback?) async throws -> Data {
        guard let _ = baseServerURL,
              Reachability.shared.isReachable else {
            throw RemoteServerError.connectivity
        }

        let url = try buildDownloadURL(id: id)

        var (asyncBytes, response): (URLSession.AsyncBytes, URLResponse)

        do {
            (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        } catch {
            throw RemoteServerError.connectivity
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            // Get the error JSON
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"

            var (errorData, errorResponse): (Data, URLResponse)
            do {
                (errorData, errorResponse) = try await URLSession.shared.data(for: urlRequest)
            } catch let error {
                print ("\(error)")
                throw RemoteServerError.connectivity
            }

            var error: ErrorResponse
            do {
                error = try decoder.decode(ErrorResponse.self, from: errorData)
            } catch {
                let strValue = String(decoding: errorData, as: UTF8.self)
                let resp = ErrorResponse(status: "\((errorResponse as? HTTPURLResponse)?.statusCode ?? 0)",
                                         id: "UNKNOWN",
                                         message: strValue)
                throw RemoteServerError.errorResponse(resp)
            }
            throw RemoteServerError.errorResponse(error)
        }

        let expectedLength = Int(response.expectedContentLength)
        var data = Data(capacity: expectedLength)

        if expectedLength == 0 {
            return data
        }

        do {
            for try await byte in asyncBytes {
                data.append(byte)
                let receivedCount = data.count

                if Task.isCancelled {
                    break
                }

                if let callback = callback {
                    if receivedCount % 1024 == 0 || receivedCount == expectedLength { // Throttle the callback
                        Task {
                            await MainActor.run {
                                callback(receivedCount, expectedLength)
                            }
                        }

                    }
                }
            }
        } catch {
            throw RemoteServerError.connectivity
        }


        if data.count != expectedLength {
            throw RemoteServerError.format
        }
        return data

    }

    private func buildDownloadURL(id: String) throws -> URL {
        guard let baseServerURL,
              !id.isEmpty,
              let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            throw RemoteServerError.configuration
        }

        var query = "id=\(encoded)"

        if let token = getToken() {
            query += "&token=\(token)"
        }
        
        let concat = baseServerURL + "/download?\(query)"
        guard let url = URL(string: concat) else {
            throw RemoteServerError.configuration
        }
        return url
    }

    private func defaultFilters() -> [Filter] {
        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date.now) ?? Date.now
        let dateFilterDate = calendar.startOfDay(for: threeMonthsAgo)
        let dateFilter = Filter.date(DateFilter(id: "createdAfter",
                                                description: String(localized: "Since", comment: "Update created after"),
                                                date: dateFilterDate))

        guard let descriptions: Array<Dictionary<String, String>>
                = Bundle.main.plistValue(key: "GAIAUpdateServerFilterDescriptions") else {
            return [dateFilter]
        }

        var filters: [Filter] = descriptions.compactMap({
            if let serverKey = $0["ServerKey"],
               let descriptionKey = $0["DescriptionKey"] {
                return Filter.property(PropertyFilter(id: serverKey,
                                                      description: String(localized: String.LocalizationValue(descriptionKey), comment: "Server Filter"),
                                                      state: .none))
            }
            return nil
        })

        filters.append(dateFilter)
        return filters
    }

    private func defaultServer() -> String? {
        if let customKeyValue: String = Bundle.main.plistValue(key: "GAIAUpdateServerFQDN") {
            return customKeyValue
        }

        return nil
    }

    private func getToken() -> String? {
        if let customKeyValue: String = Bundle.main.plistValue(key: "GAIAUpdateServerToken") {
            return customKeyValue
        }

        return nil
    }
}
