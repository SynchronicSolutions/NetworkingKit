//
//  GroupRequest.swift
//  Networking
//
//  Created on 5/31/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation
import Alamofire

public class GroupRequest: Completable {
    var dispatchGroup: DispatchGroup?

    public var complete: (() -> Void)?

    public func complete(closure: (() -> Void)?) {
        self.complete = closure
    }
}
