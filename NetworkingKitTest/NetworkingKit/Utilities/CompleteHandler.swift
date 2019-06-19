//
//  CompleteHandler.swift
//  CustomFrameworks
//
//  Created on 5/31/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation

public class CompleteHandler<ResponseType: Returnable, ErrorType: NetworkErrorProtocol>: Succedable {

    public var complete: (() -> Void)?
    public var success: ((ResponseType) -> Void)?
    public var failure: (([ErrorType]) -> Void)?

    public var shouldDelay: Bool = false
    private var finishDelay: (() -> Void)?

    init() {}

    public func complete(closure: (() -> Void)?) {
        self.complete = closure
    }

    @discardableResult public func success(closure: @escaping (ResponseType) -> Void) -> Self {
        self.success = closure
        return self
    }

    @discardableResult public func success(closure: @escaping () -> Void) -> Self {
        self.success = { _ in
            closure()
        }

        return self
    }

    @discardableResult public func failure(closure: @escaping ([ErrorType]) -> Void) -> Self {
        self.failure = closure
        return self
    }

    func finishDelay(closure: @escaping () -> Void) {
        self.finishDelay = closure
    }

    public func finishDelayIfExists() {
        finishDelay?()
    }
}
