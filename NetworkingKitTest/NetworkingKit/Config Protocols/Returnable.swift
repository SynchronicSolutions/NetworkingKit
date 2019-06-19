//
//  Returnable.swift
//  Networking
//
//  Created on 6/4/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation
import CoreData

public protocol Returnable {
    init()
}

extension Dictionary: Returnable where Key == String, Value == Any {}
extension Array: Returnable where Element == JSONObject {}
extension String: Returnable {}
extension Int: Returnable {}

public struct VoidType: Returnable {
    public init() {}
}
