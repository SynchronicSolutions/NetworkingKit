//
//  Completable.swift
//  CustomFrameworks
//
//  Created on 5/31/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation

public protocol Completable {
    var complete: (() -> Void)? { get set }
    func complete(closure: (() -> Void)?)
}

public protocol Succedable: Completable {
    associatedtype ReturnType: Returnable
    associatedtype ErrorType: NetworkErrorProtocol

    var success: ((ReturnType) -> Void)? { get set }
    func success(closure: @escaping (ReturnType) -> Void) -> Self

    var failure: (([ErrorType]) -> Void)? { get set }
    func failure(closure: @escaping ([ErrorType]) -> Void) -> Self
}
