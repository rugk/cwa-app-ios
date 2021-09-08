//
// 🦠 Corona-Warn-App
//

import Foundation

enum HTTP {
	enum Method: String {
		case get = "GET"
		case post = "POST"
		case put = "PUT"
		case delete = "DELETE"
		case patch = "PATCH"
	}
}

enum ResourceError: Error {
	case missingData
	case decoding
	case encoding
	case packageCreation
	case signatureVerification
	case notModified
	case undefined

}

enum ResourceType {
	case `default`
	case caching
	case wifiOnly
	case retrying
}

protocol ResponseResource {
	// Model is type of the model
	associatedtype Model
	associatedtype ReqModel: RequestResource

	var locator: Locator { get }
	var type: ResourceType { get }
	
	var requestResource: ReqModel? { get }

	func urlRequest(environmentData: EnvironmentData, customHeader: [String: String]?) -> Result<URLRequest, ResourceError>
	func decode(_ data: Data?) -> Result<Model, ResourceError>
}

protocol RequestResource {
	associatedtype Model

	var model: Model? { get }
	func encode() -> Result<Data?, ResourceError>
}

enum Resources {
	enum response {
		static let appConfiguration = ProtobufResource<SAP_Internal_V2_ApplicationConfigurationIOS>(.appConfiguration, .caching)
	}

	enum request {
		static func appConfiguration(model: SAP_Internal_V2_ApplicationConfigurationIOS) -> ProtobufResource<SAP_Internal_V2_ApplicationConfigurationIOS> {
			return ProtobufResource<SAP_Internal_V2_ApplicationConfigurationIOS>(.appConfiguration, .caching, model)
		}
	}

}
