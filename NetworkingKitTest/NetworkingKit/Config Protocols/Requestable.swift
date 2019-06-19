//
//  Request.swift
//  CustomFrameworks
//
//  Created on 5/31/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation
import Alamofire

public enum RequestRetryPolicy {
    case none
    case manual
    case automatic(Int)
}

public protocol Requestable {
    associatedtype EndPointType: EndPoint
    init(endPoint: EndPointType, retryPolicy: RequestRetryPolicy)

    var endPoint: EndPointType { get set }
    var retryPolicy: RequestRetryPolicy { get set }

    func start<ResponseType: Returnable,
        ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>?,
                                         shouldDelayCompletion: Bool)
        -> CompleteHandler<ResponseType, ErrorType>
    func startMultipart<ResponseType: Returnable,
                        ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>?)
        -> CompleteHandler<ResponseType, ErrorType>
}

public extension Requestable {

}

open class Request<EndPointType: EndPoint>: Requestable {
    public var endPoint: EndPointType
    public var retryPolicy: RequestRetryPolicy

    required public init(endPoint: EndPointType, retryPolicy: RequestRetryPolicy = .automatic(5)) {
        self.endPoint = endPoint
        self.retryPolicy = retryPolicy
    }

    public func start<ResponseType: Returnable,
        ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>? = nil,
                                         shouldDelayCompletion: Bool = false)
        -> CompleteHandler<ResponseType, ErrorType> {

            let newHandler: CompleteHandler<ResponseType, ErrorType>
            if let handler = handler {
                newHandler = handler
            } else {
                newHandler = CompleteHandler<ResponseType, ErrorType>()
            }

            var activeGroup: GroupRequest?
            if !Router.instance.activeGroups.isEmpty {
                activeGroup = Router.instance.activeGroups.last
            }

            let groupQueue = activeGroup?.dispatchGroup
            let responseQueue = Router.instance.groupQueue.filter { $0.value === activeGroup }.keys.first

            groupQueue?.enter()

            print("📡📡📡📡 Request started: \(endPoint.fullURL)\n" +
            (endPoint.parameters.isEmpty ? "" : "Parameters: \(endPoint.parameters.toString(options: .prettyPrinted))"))
            let retryManager = RetryManager(request: self)
            Router.setup(request: self).responseJSON(queue: responseQueue ?? .main) { (response) in
                Router.handleResponse(response: response,
                                      retryManager: retryManager,
                                      groupQueue: groupQueue,
                                      shouldDelayCompletion: shouldDelayCompletion,
                                      completionHandler: newHandler)
            }

            return newHandler
    }

    public func startMultipart<ResponseType: Returnable,
        ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>? = nil)
        -> CompleteHandler<ResponseType, ErrorType> {

            let newHandler: CompleteHandler<ResponseType, ErrorType>
            if let handler = handler {
                newHandler = handler
            } else {
                newHandler = CompleteHandler<ResponseType, ErrorType>()
            }

            var activeGroup: GroupRequest?
            if !Router.instance.activeGroups.isEmpty {
                activeGroup = Router.instance.activeGroups.last
            }

            let groupQueue = activeGroup?.dispatchGroup
            let responseQueue = Router.instance.groupQueue.filter { $0.value === activeGroup }.keys.first

            groupQueue?.enter()
            let retryManager = RetryManager(request: self, isMultipart: true)
            Router.setupMultipart(request: self) { (uploadRequest) in
                uploadRequest.responseJSON(queue: responseQueue ?? .main) { (response) in
                    Router.handleResponse(response: response,
                                          retryManager: retryManager,
                                          groupQueue: groupQueue,
                                          completionHandler: newHandler)
                }
            }

            return newHandler
    }
}
