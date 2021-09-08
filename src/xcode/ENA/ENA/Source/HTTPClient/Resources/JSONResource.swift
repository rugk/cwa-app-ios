//
// 🦠 Corona-Warn-App
//

import Foundation

/// helper to define en empty request body
struct EmptyRequestResource: RequestResource {

	typealias Model = Void

	var model: Void?

	func encode() -> Result<Data?, ResourceError> {
		return .success(nil)
	}
}

struct JSONResource<M: Codable>: ResponseResource {

	// MARK: - Init

	// MARK: - Overrides

	// MARK: - Protocol ResponseResource

	typealias ReqModel = EmptyRequestResource
	typealias Model = M

	var requestResource: EmptyRequestResource?
	var locator: Locator
	var type: ResourceType = .default
/*
	let resourceLocator: ResourceLocator = ResourceLocator(
		endpoint: .dataDonation,
		paths: URL(staticString: "http://"),
		method: .get,
		headers: ["Content-Type": "application/json"]
	)
*/

	func urlRequest(environmentData: EnvironmentData, customHeader: [String: String]? = nil) -> Result<URLRequest, ResourceError> {
		let endpointURL = locator.endpoint.url(environmentData)
		let url = locator.paths.reduce(endpointURL) { result, component in
			result.appendingPathComponent(component, isDirectory: false)
		}
		var urlRequest = URLRequest(url: url)
		locator.headers.forEach { key, value in
			urlRequest.setValue(value, forHTTPHeaderField: key)
		}

		customHeader?.forEach { key, value in
			urlRequest.setValue(value, forHTTPHeaderField: key)
		}

		return .success(urlRequest)
	}

	func decode(_ data: Data?) -> Result<M, ResourceError> {
		guard let data = data else {
			return .failure(.missingData)
		}
		do {
			let model = try decoder.decode(M.self, from: data)
			return .success(model)
		} catch let DecodingError.keyNotFound(key, context) {
			Log.debug("missing key: \(key.stringValue)", log: .client)
			Log.debug("Debug Description: \(context.debugDescription)", log: .client)
		} catch let DecodingError.valueNotFound(type, context) {
			Log.debug("Type not found \(type)", log: .client)
			Log.debug("Debug Description: \(context.debugDescription)", log: .client)
		} catch let DecodingError.typeMismatch(type, context) {
			Log.debug("Type mismatch found \(type)", log: .client)
			Log.debug("Debug Description: \(context.debugDescription)", log: .client)
		} catch let DecodingError.dataCorrupted(context) {
			Log.debug("Debug Description: \(context.debugDescription)", log: .client)
		} catch {
			Log.debug("Failed to parse JSON answer - unhandled error", log: .client)
		}
		return .failure(.decoding)
	}

	func encode(_ model: Model) -> Result<Data, ResourceError> {
//		guard <#condition#> else {
//			<#statements#>
//		}
//
//		let payload =


		return Result.failure(.missingData)
	}

	// MARK: - Public

	// MARK: - Internal

	// MARK: - Private

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

}
