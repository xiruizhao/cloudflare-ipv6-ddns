//
//  main.swift
//  cloudflare_ipv6_ddns
//  Version 0.0.1
//
//  Created by Xirui Zhao on 2020-08-23.
//  Copyright © 2020 Xirui Zhao. All rights reserved.
//
import Alamofire
import Foundation
import os
import SwiftyJSON
import SystemConfiguration

// A semaphore is used to block until Alamofire requests finish. Closures in response handlers must be sent to another queue other than the .main queue to allow semaphores to unblock.
// Usually, a change in IP address triggers multiple DynamicStore notifications (something to do with SLAAC, perhaps)
// A semaphore is used to ensure that these notifications are processed sequentially rather than concurrently.
// This also incidentally results in retrying the request once.

let logger = Logger()
let semaphore = DispatchSemaphore(value: 0)
let bg_queue = DispatchQueue.global(qos: .background)

let config = try! JSON(data: NSData(contentsOfFile: "/usr/local/etc/cloudflare_ipv6_ddns.json") as Data)
let api_url = "https://api.cloudflare.com/client/v4/zones/\(config["ZONE_ID"])/dns_records/\(config["RECORD_ID"])"
let auth_header: HTTPHeaders = ["Authorization": "Bearer \(config["API_TOKEN"])"]
var dns_ipv6_addr = ""
AF.request(
    api_url,
    headers: auth_header
).validate().responseJSON(queue: bg_queue) { response in
    if case .success(let value) = response.result {
        dns_ipv6_addr = JSON(value)["result"]["content"].string!
    }
    semaphore.signal()
}
let watched_key = "State:/Network/Interface/\(config["NET_IF"])/IPv6" as CFString
let callback: SCDynamicStoreCallBack = { (_, _, _) in
    semaphore.wait()
    let ipv6_addr = local_ipv6_addr()
    if ipv6_addr != "" && ipv6_addr != dns_ipv6_addr {
        AF.request(
            api_url,
            method: .patch,
            parameters: ["content": ipv6_addr],
            encoder: JSONParameterEncoder.default,
            headers: auth_header
        ).validate().responseJSON(queue: bg_queue) { response in
            if case .success(let value) = response.result {
                dns_ipv6_addr = ipv6_addr
                logger.log("Updated \(JSON(value)["result"]["name"]) = \(ipv6_addr) to Cloudflare DNS")
            } else {
	        logger.error("Failed to update to Cloudflare DNS.")
	    }
            semaphore.signal()
        }
    }
    semaphore.signal()
}

let store = SCDynamicStoreCreate(nil, "cloudlflare_ipv6_ddns" as CFString, callback, nil)!
SCDynamicStoreSetNotificationKeys(store, [watched_key] as CFArray, nil)

func local_ipv6_addr() -> String {
    if let ipv6_dict = SCDynamicStoreCopyValue(store, watched_key) as? [String: [Any]] {
        for i in 0..<ipv6_dict["Addresses"]!.count {
            // gets the "autoconf secured" address
            if ipv6_dict["Flags"]![i] as! Int == 1088 {
                return ipv6_dict["Addresses"]![i] as! String
            }
        }
    }
    return ""
}

logger.info("Starting cloudlflare_ipv6_ddns.")
semaphore.wait()
let ipv6_addr = local_ipv6_addr()
if ipv6_addr != "" && ipv6_addr != dns_ipv6_addr {
    AF.request(
        api_url,
        method: .patch,
        parameters: ["content": ipv6_addr],
        encoder: JSONParameterEncoder.default,
        headers: auth_header
    ).validate().responseJSON(queue: bg_queue) { response in
        if case .success(let value) = response.result {
            dns_ipv6_addr = ipv6_addr
            logger.log("Updated \(JSON(value)["result"]["name"]) = \(ipv6_addr) to Cloudflare DNS")
        } else {
	    logger.error("Failed to update to Cloudflare DNS.")
	}
        semaphore.signal()
    }
}
semaphore.signal()

CFRunLoopAddSource(CFRunLoopGetCurrent(), SCDynamicStoreCreateRunLoopSource(nil, store, 0), CFRunLoopMode.defaultMode)
CFRunLoopRun()
