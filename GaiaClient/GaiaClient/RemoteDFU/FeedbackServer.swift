//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore

struct FeedbackInfo: Encodable {
    struct ClientDescription: Encodable {
        let name: String
        let appVersion: String
        let system: String
        let systemVersion: String
        let device: String
    }

    struct DeviceDescription: Encodable {
        let applicationVersion: String
        let applicationBuildId: String?
        let hardwareVersion: String?
    }

    let title: String
    let description: String
    let reporter: String?
    let client: ClientDescription
    let device: DeviceDescription
}

class FeedbackServer {
    public struct FeedbackLinkResponse: Decodable {
        struct IssueDescription: Decodable {
            let id: String
            let link: String
            let title: String
        }

        let issue: IssueDescription
    }

    public static let shared = FeedbackServer()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var baseServerURL: String?

    var supported: Bool {
        baseServerURL != nil
    }

    init() {

        baseServerURL = defaultServer()

        encoder.outputFormatting = [.prettyPrinted , .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }


    func sendFeedback(_ feedback: FeedbackInfo) async throws -> FeedbackLinkResponse {
        guard let baseServerURL,
              Reachability.shared.isReachable else {
            throw RemoteServerError.connectivity
        }

        var reqData: Data
        do {
            reqData = try encoder.encode(feedback)
        } catch {
            throw RemoteServerError.format
        }

        var tokenStr = ""
    	if let token = getToken() {
            tokenStr = "?token=\(token)"
        }


        let concat = baseServerURL + "/feedback" + tokenStr
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
            let decodedResponse:FeedbackLinkResponse = try decoder.decode(FeedbackLinkResponse.self, from: data)
            return decodedResponse
        } catch {
            throw RemoteServerError.format
        }
    }

    private func defaultServer() -> String? {
        if let customKeyValue: String = Bundle.main.plistValue(key: "GAIAFeedbackServerFQDN") {
            return customKeyValue
        }

        return nil
    }

    private func getToken() -> String? {
        if let customKeyValue: String = Bundle.main.plistValue(key: "GAIAFeedbackServerToken") {
            return customKeyValue
        }

        return nil
    }
}
