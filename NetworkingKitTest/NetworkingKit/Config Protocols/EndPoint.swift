//
//  EndPoint.swift
//  CustomFrameworks
//
//  Created on 5/31/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation
import Alamofire

public protocol EndPoint {
    var baseURL: String { get }
    var path: String { get }
    var prePath: String { get }
    var method: HTTPMethod { get }
    var apiVersion: APIVersion { get }
    var parameters: JSONObject { get }
    var defaultParameters: JSONObject { get }
    var defaultHeaders: [String: String] { get }
    var authorization: AuthorizationType { get }
    var limit: Int? { get }
    var codeForNotAuthorizedError: String? { get }

    var shouldHandleRetry: Bool { get }
    func handleRetry<ErrorType: NetworkErrorProtocol>(error: ErrorType?,
                                                      retryAction: @escaping () -> Void,
                                                      cancelAction: @escaping () -> Void)
    func handleAuthenticationFailure<ErrorType: NetworkErrorProtocol>(errors: [ErrorType])
}

extension EndPoint {
    var fullURL: URL {
        if apiVersion != .none {
            let trimmedPrepath = prePath.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: baseURL + trimmedPrepath + "/" + apiVersion.rawValue + path)!

        } else {
            return URL(string: baseURL + path)!
        }
    }

    public var shouldHandleRetry: Bool { return true }

    public var codeForNotAuthorizedError: String? { return nil }
}

public enum AuthorizationType {
    case basic(username: String, password: String)
    case none
}

public enum APIVersion: String {
    case none
    case v1
    case v2
    case v3
    case v4
}
