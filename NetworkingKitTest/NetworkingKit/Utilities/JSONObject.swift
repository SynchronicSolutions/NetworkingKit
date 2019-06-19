//
//  JSONObject.swift
//  Networking
//
//  Created on 10/11/18.
//  Copyright © 2018 Human Dx, Ltd. All rights reserved.
//

import Foundation

public typealias JSONObject = [String: Any]

public extension Dictionary where Key == String, Value: Any {

    subscript(string: String) -> Any? {
        let stringParts: [String] = string.split(separator: ".").map { "\($0)" }

        if stringParts.count == 1 {
            return self[string]

        } else {

            var remainderDictionary = self

            for index in 0..<stringParts.count {
                let key = stringParts[index]
                if index == (stringParts.count - 1) {
                    return remainderDictionary[key]

                } else if let subDictionary = remainderDictionary[key] as? [Key: Value] {
                    remainderDictionary = subDictionary
                }
            }
        }

        return ""
    }

    func print() {
        do {
            let data: Data = try JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted])
            Swift.print(String(data: data, encoding: .utf8)!)

        } catch {
            Swift.print("Dictionary printing failed!\nDictionary: \(self)\nError:\(error)")
        }
    }

    func toString(options: JSONSerialization.WritingOptions = []) -> String {
        do {
            let data: Data = try JSONSerialization.data(withJSONObject: self, options: options)
            return String(data: data, encoding: .utf8) ?? ""

        } catch {
            Swift.print("Dictionary serialization failed!\nDictionary: \(self)\nError:\(error)")
        }

        return ""
    }
}

extension Array where Element == JSONObject {
    public func print() {
        self.forEach { $0.print() }
    }
}
