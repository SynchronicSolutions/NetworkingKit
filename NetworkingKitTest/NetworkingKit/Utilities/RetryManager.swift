//
//  RetryManager.swift
//  Networking
//
//  Created on 10/10/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation

class RetryManager<RequestType: Requestable> {
    var request: RequestType
    var isMultipart: Bool = false

    init(request: RequestType) {
        self.request = request
    }

    init(request: RequestType, isMultipart: Bool) {
        self.request = request
        self.isMultipart = isMultipart
    }

    func retryIfShould<ResponseType: Returnable,
                       ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>,
                                                        errors: [ErrorType],
                                                        retryPolicyChanged: @escaping (RequestRetryPolicy) -> Void) {

        let authenticationErrors = errors.filter { $0.code == request.endPoint.codeForNotAuthorizedError }

        guard authenticationErrors.isEmpty else {
            request.endPoint.handleAuthenticationFailure(errors: authenticationErrors)
            handler.failure?(errors)
            return
        }

        switch request.retryPolicy {
        case .none:
            Router.defaultNetworkErrors(errors)
            handler.failure?(errors)

        case .manual:
            showRetryDialog(handler: handler, errors: errors)

        case .automatic(let numberOfAttempts):

            let hasNoInternetConnectionError = !errors.filter { $0.code == "-1009" || $0.code == "-1001" }.isEmpty

            if numberOfAttempts > 0 && !hasNoInternetConnectionError {
                print("Retrying request: \(type(of: request.endPoint)) \(request.endPoint.fullURL)" +
                    "...\nAttempts remaining \(numberOfAttempts)...")
                retryPolicyChanged(.automatic(numberOfAttempts - 1))
                retry(with: handler)()

            } else {
                showRetryDialog(handler: handler, errors: errors)
                handler.finishDelayIfExists()
            }
        }
    }

    func retry<ResponseType: Returnable,
               ErrorType: NetworkErrorProtocol>(with handler: CompleteHandler<ResponseType, ErrorType>)
        -> () -> Void {

        // Deliberately capturing self, so it can outlive the scope
        // It will get released as soon as `retryAction` block releases
        // i.e. UIAlertViewAction gets released
        return {
            if self.isMultipart {
                _ = self.request.startMultipart(handler: handler)
            } else {
                _ = self.request.start(handler: handler, shouldDelayCompletion: false)
            }
        }
    }

    private func showRetryDialog<ResponseType: Returnable,
                                 ErrorType: NetworkErrorProtocol>(handler: CompleteHandler<ResponseType, ErrorType>,
                                                                  errors: [ErrorType]) {
        Router.defaultNetworkErrors(errors)

        if request.endPoint.shouldHandleRetry {

            if RetryService.instance.requestsToRetry.isEmpty {
                RetryService.instance.requestsToRetry.append(retry(with: handler))

                request.endPoint.handleRetry(error: errors.first,
                                             retryAction: {
                                                RetryService.instance.requestsToRetry.forEach { $0() }
                                                RetryService.instance.requestsToRetry.removeAll()

                }, cancelAction: {
                    handler.failure?(errors)
                })
            } else {
                RetryService.instance.requestsToRetry.append(retry(with: handler))
            }

        } else {
            handler.failure?(errors)
        }
    }
}

class RetryService {
    static let instance = RetryService()

    var requestsToRetry: ThreadSafeQueue<(() -> Void)> = ThreadSafeQueue()
}

class ThreadSafeQueue<Element> {

    private var queue: [Element] = []

    private let accessQueue = DispatchQueue(label: "ThreadSafeQueue", attributes: .concurrent)

    var count: Int {
        return accessQueue.sync { queue.count }
    }

    var isEmpty: Bool {
        return accessQueue.sync { queue.isEmpty }
    }

    func append(_ element: Element) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.queue.append(element)
        }
    }

    func removeAll() {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.queue.removeAll()
        }
    }

    func forEach(_ closure: (Element) -> Void) {
        accessQueue.sync {
            queue.forEach { closure($0) }
        }
    }
}
