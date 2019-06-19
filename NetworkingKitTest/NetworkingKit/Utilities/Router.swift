//
//  Router.swift
//  Networking
//
//  Created on 6/1/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation
import Alamofire

public class Router {
    public static let instance = Router()

    private init() {}

    var activeGroups: [GroupRequest] = []

    var groupQueue: [DispatchQueue: GroupRequest] = [:]

    public static let defaultNetworkError: (NetworkErrorProtocol?) -> Void = { error in
        print("Network Error: \(error?.description ?? "No description")")
    }

    public static let defaultNetworkErrors: ([NetworkErrorProtocol]?) -> Void = { errors in
        errors?.forEach { Router.defaultNetworkError($0) }
    }

    public static let defaultError: (Error) -> Void = { error in
        print("Error: \(error)")
    }

    public static let defaultErrors: ([Error]) -> Void = { errors in
        errors.forEach { Router.defaultError($0) }
    }

    @discardableResult public static func makeGroup(groupedRequests: @escaping () -> Void) -> GroupRequest {
        let group = GroupRequest()
        group.dispatchGroup = DispatchGroup()

        Router.instance.activeGroups.append(group)

        let dispatchQueue = DispatchQueue(label: "group", qos: .background)

        Router.instance.groupQueue[dispatchQueue] = group

        dispatchQueue.async {
            groupedRequests()

            group.dispatchGroup?.notify(queue: .main) {
                group.complete?()

                var index: Int = 0
                for activeGroup in Router.instance.activeGroups {
                    if group === activeGroup {
                        Router.instance.activeGroups.remove(at: index)
                        Router.instance.groupQueue.removeValue(forKey: dispatchQueue)
                        break
                    }
                    index += 1
                }
            }
        }

        return group
    }

    /// Factory method to create Alamofire request from Requestable instance
    ///
    /// - Parameter request: Requestable instance
    /// - Returns: Alamofire DataRequest
    static func setup<T: Requestable>(request: T) -> DataRequest {
        let mergedParameters = request.endPoint.defaultParameters
            .merging(request.endPoint.parameters) { (left, _) in left }
        let mergedHeaders = request.endPoint.defaultHeaders
            .merging(Alamofire.SessionManager.defaultHTTPHeaders) { (left, _) in left }

        let httpMethod = Alamofire.HTTPMethod(rawValue: request.endPoint.method.rawValue) ?? .get

        let encoding: ParameterEncoding = httpMethod == .get ? URLEncoding.default :
                                                               JSONEncoding(options: .prettyPrinted)
        let alamoRequest = Alamofire.request(request.endPoint.fullURL,
                                             method: httpMethod,
                                             parameters: mergedParameters,
                                             encoding: encoding,
                                             headers: mergedHeaders)

        switch request.endPoint.authorization {
        case .basic(let username, let password): alamoRequest.authenticate(user: username,
                                                                           password: password)
        default: break
        }

        return alamoRequest
    }

    static func setupMultipart<T: Requestable>(request: T,
                                               requestCompletion: @escaping (UploadRequest) -> Void) {
        let mergedParameters = request.endPoint.defaultParameters
            .merging(request.endPoint.parameters) { (left, _) in left }

        var mergedHeaders = request.endPoint.defaultHeaders
            .merging(Alamofire.SessionManager.defaultHTTPHeaders) { (left, _) in left }

        mergedHeaders["Content-type"] = "multipart/form-data"

        Alamofire.upload(multipartFormData: { (multipartFormData) in
            for (key, value) in mergedParameters {
                if let value = value as? UIImage, let imageData = value.jpegData(compressionQuality: 0.4) {
                    multipartFormData.append(imageData,
                                             withName: "photo",
                                             fileName: key + ".jpg",
                                             mimeType: "image/jpeg")

                } else if let valueData = "\(value)".data(using: .utf8) {
                    multipartFormData.append(valueData, withName: key)
                }
            }

        }, usingThreshold: UInt64(),
           to: request.endPoint.fullURL,
           method: .post,
           headers: mergedHeaders,
           encodingCompletion: { (result) in
            switch result {
            case .success(let uploadRequest, _, _):
                switch request.endPoint.authorization {
                case .basic(let username, let password):
                    uploadRequest.authenticate(user: username, password: password)
                    requestCompletion(uploadRequest)
                default:
                    requestCompletion(uploadRequest)
                }
            case .failure(let error):
                Router.defaultError(error)
            }
        })

    }

    static func handleResponse<RequestType: Requestable, ResponseType: Returnable,
                                   ErrorType: NetworkErrorProtocol>(response: DataResponse<Any>,
                                                                    retryManager: RetryManager<RequestType>,
                                                                    groupQueue: DispatchGroup? = nil,
                                                                    shouldDelayCompletion: Bool = false,
                                                                    completionHandler: CompleteHandler<ResponseType,
                                                                                                           ErrorType>) {
        defer {
            if !shouldDelayCompletion {
                completionHandler.complete?()
                if let groupQueue = groupQueue {
                    groupQueue.leave()
                }

            } else {
                let oldCompletion = completionHandler.complete
                completionHandler.complete = {
                    oldCompletion?()
                    if let groupQueue = groupQueue {
                        groupQueue.leave()
                    }
                }
            }

        }

        guard
            let successValue = response.value as? ResponseType,
            isStatusOK(status: response.response?.statusCode ?? 500) else {

            let networkErrors: [ErrorType] = parseErrors(response: response)

            retryManager.retryIfShould(handler: completionHandler, errors: networkErrors) { (retryPolicy) in
                retryManager.request.retryPolicy = retryPolicy
            }
            return
        }

        completionHandler.success?(successValue)
    }

    private static func parseErrors<ErrorType: NetworkErrorProtocol>(response: DataResponse<Any>) -> [ErrorType] {
        var networkErrors: [ErrorType] = []
        switch response.result {
        case .success(let json):
            if let json = json as? JSONObject, let errors = json["errors"] as? [JSONObject] {
                for errorJSON in errors {
                    let code = (errorJSON["code"] as? String) ?? "Error code missing"
                    let description = (errorJSON["desc"] as? String) ?? "Description missing"
                    let title = (errorJSON["title"] as? String) ?? "Title missing"
                    networkErrors.append(ErrorType(code: code, title: title, desc: description))
                }
            }

        case .failure(let error):
            let code: Int
            if let error = error as? URLError {
                code = error.errorCode

            } else {
                code = response.response?.statusCode ?? 0
                networkErrors = [
                    ErrorType(code: "\(response.response?.statusCode ?? 0)",
                        title: "Network Error",
                        desc: error.localizedDescription)]
            }

            networkErrors = [ErrorType(code: "\(code)",
                title: "Network Error",
                desc: error.localizedDescription)]
        }

        return networkErrors
    }

    private static func isStatusOK(status: Int) -> Bool {
        return 200..<300 ~= status
    }
}

public enum HTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}

public protocol NetworkErrorProtocol: Error {
    var code: String { get set }
    var title: String { get set }
    var description: String { get set }

    init(code: String, title: String, desc: String)
}
