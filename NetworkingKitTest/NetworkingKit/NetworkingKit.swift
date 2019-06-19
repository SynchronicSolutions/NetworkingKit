//
//  Networking.swift
//  Networking
//
//  Created on 3/28/19.
//  Copyright © 2019 Human Dx, Ltd. All rights reserved.
//

import Foundation
import Alamofire

public enum ConnectionType {
    case ethernetOrWiFi
    case wwan
}

public enum ReachabilityStatus: Equatable {
    case notReachable
    case unknown
    case reachable(ConnectionType)
}

public class NetworkingKit {
    public static let instance = NetworkingKit()

    let reachabilityManager = NetworkReachabilityManager(host: "apple.com")

    deinit {
        reachabilityManager?.stopListening()
    }

    public static var reachabilityStatus: ReachabilityStatus {
        guard let reachabilityManager = NetworkingKit.instance.reachabilityManager else {
            return .notReachable
        }

        if reachabilityManager.isReachableOnEthernetOrWiFi {
            return .reachable(.ethernetOrWiFi)
        } else if reachabilityManager.isReachableOnWWAN {
            return .reachable(.wwan)
        } else if !reachabilityManager.isReachable {
            return .notReachable
        }

        return .unknown
    }

    public func registerForReachabilityChanges(changes: @escaping (ReachabilityStatus) -> Void) {
        reachabilityManager?.listener = { (status) in
            switch status {
            case .notReachable:
                changes(.notReachable)

            case .unknown:
                changes(.unknown)

            case .reachable(let connectionType):
                switch connectionType {
                case .ethernetOrWiFi:
                    changes(.reachable(.ethernetOrWiFi))
                case .wwan:
                    changes(.reachable(.wwan))
                }
            }
        }

        reachabilityManager?.startListening()
    }
}
