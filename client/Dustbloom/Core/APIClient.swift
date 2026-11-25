import Foundation

/// Thin client for the Go server API (see server/internal/api/api.go).
struct APIClient {
    struct FarmResponse: Decodable {
        var farm: Farm
        var level: Int
        var serverTime: Date
        var harvest: HarvestResult?
        var sold: Int?
        var raid: RaidResult?
    }

    enum APIError: Error {
        case game(FarmError)
        case unauthorized
        case http(Int)
    }

    let baseURL: URL
    var token: String?

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Go writes RFC 3339 with optional fractional seconds.
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: s) ?? plain.date(from: s) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date \(s)"))
        }
        return d
    }()

    func guestLogin(deviceID: String) async throws -> String {
        struct Resp: Decodable { var token: String }
        let resp: Resp = try await send("POST", "/v1/auth/guest", body: ["deviceId": deviceID])
        return resp.token
    }

    func farm() async throws -> FarmResponse {
        try await send("GET", "/v1/farm", body: nil as [String: String]?)
    }

    func till(x: Int, y: Int) async throws -> FarmResponse {
        try await send("POST", "/v1/farm/till", body: TileBody(x: x, y: y, crop: nil))
    }

    func plant(x: Int, y: Int, crop: String) async throws -> FarmResponse {
        try await send("POST", "/v1/farm/plant", body: TileBody(x: x, y: y, crop: crop))
    }

    func harvest(x: Int, y: Int) async throws -> FarmResponse {
        try await send("POST", "/v1/farm/harvest", body: TileBody(x: x, y: y, crop: nil))
    }

    func sell(crop: String, count: Int) async throws -> FarmResponse {
        struct Body: Encodable { var crop: String; var count: Int }
        return try await send("POST", "/v1/farm/sell", body: Body(crop: crop, count: count))
    }

    func build(scarecrow: String) async throws -> FarmResponse {
        try await send("POST", "/v1/army/build", body: ["scarecrow": scarecrow])
    }

    func raid(_ id: String) async throws -> FarmResponse {
        try await send("POST", "/v1/raid", body: ["raid": id])
    }

    private struct TileBody: Encodable {
        var x: Int
        var y: Int
        var crop: String?
    }

    private struct ErrorBody: Decodable {
        var error: String
    }

    private func send<B: Encodable, R: Decodable>(_ method: String, _ path: String, body: B?) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 10
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            return try APIClient.decoder.decode(R.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 409:
            if let e = try? JSONDecoder().decode(ErrorBody.self, from: data), let code = FarmError(rawValue: e.error) {
                throw APIError.game(code)
            }
            throw APIError.http(status)
        default:
            throw APIError.http(status)
        }
    }
}
