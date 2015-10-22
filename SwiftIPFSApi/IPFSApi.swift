//
//  IPFSApi.swift
//  SwiftIPFSApi
//
//  Created by Teo on 20/10/15.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
import SwiftMultiaddr
import SwiftMultihash

public protocol IpfsApiClient {
    var baseURL: String { get }
}

protocol ClientSubCommand {
    var parent: IpfsApiClient? { get set }
}

extension IpfsApiClient {
    
    func fetchData(path: String, completionHandler: (NSData) -> Void) throws {
        
        let fullURL = baseURL + path
        guard let url = NSURL(string: fullURL) else { throw IPFSAPIError.InvalidURL }
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) in
            do {
                if error != nil { throw IPFSAPIError.DataTaskError(error!) }
                guard let data = data else { throw IPFSAPIError.NilData }
                
                print("The data:",NSString(data: data, encoding: NSUTF8StringEncoding))
                
                completionHandler(data)
            
            } catch {
                print("Error ", error, "in completionHandler passed to fetchData ")
            }
        }
        
        task.resume()
    }
}

public enum PinType {
    case all
    case direct
    case indirect
    case recursive
}

enum IPFSAPIError : ErrorType {
    case InvalidURL
    case NilData
    case DataTaskError(NSError)
    case JSONSerializationFailed
    case SwarmError(String)
}

public class IPFSApi : IpfsApiClient {

    public var baseURL: String = ""
    
    public let host: String
    public let port: Int
    public let version: String
    
    /// Second Tier commands
    public let repo = Repo()
    public let pin = Pin()
    public let swarm = Swarm()

/**
    public convenience init(addr: Multiaddr) throws {
        /// Get the host and port number from the Multiaddr
        let addString = addr.string()
        self.init(addr.)
    }

    public convenience init(addr: String) throws {
        try self.init(addr: newMultiaddr(addr))
    }
*/
    public init(host: String, port: Int, version: String = "/api/v0/") throws {
        self.host = host
        self.port = port
        self.version = version
        
        baseURL = "http://\(host):\(port)/\(version)"
        
        /** All of IPFSApi's properties need to be set before we can use self which
            is why we can't just init the sub commands with self */
        repo.parent = self
        pin.parent = self
        swarm.parent = self
        
    }
    
    
    /// Tier 1 commands
    
    public func add(file :NSURL) throws -> MerkleNode {
        return try MerkleNode(hash: "")
    }
    
    public func add(files: [NSURL]) throws -> [MerkleNode] {
        return []
    }
    
    public func ls(hash: Multihash, completionHandler: ([MerkleNode]) -> Void) throws {
        let hashString = b58String(hash)
        try fetchData("ls/"+hashString) {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IPFSAPIError.JSONSerializationFailed
                }
                guard let objects = json["Objects"] as? [AnyObject] else {
                    throw IPFSAPIError.SwarmError("ls error: No Objects in JSON data.")
                }
                
                let merkles = try objects.map {
                    rawJSON in
                    return try merkleNodeFromJSON(rawJSON)
                }
//                guard let objects = json["Objects"] where objects.count == 1 else {
//                    throw IPFSAPIError.SwarmError("ls error: No Objects in JSON data.")
//                }

//                let merkles = try merkleNodeFromJSON(objects[0])

                completionHandler(merkles)
                
            } catch {
                print("ls Error")
            }
        }
    }
    
    public func cat(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        let hashString = b58String(hash)
        try fetchData("cat/"+hashString) {
            (data: NSData) in
            
            /// Convert the data to a byte array
            let count = data.length / sizeof(UInt8)
            // create an array of Uint8
            var bytes = [UInt8](count: count, repeatedValue: 0)

            // copy bytes into array
            data.getBytes(&bytes, length:count * sizeof(UInt8))
            
            completionHandler(bytes)
        }
        return
    }
    
    public func get(hash: Multihash) throws -> [UInt8] {
        return []
    }
    
    public func refs(hash: Multihash, recursive: Bool) throws -> [String : String] {
        return [:]
    }
    
    public func resolve(scheme: String, hash: Multihash, recursive: Bool) throws -> [String : String] {
        return [:]
    }
    
    public func dns(domain: String) throws -> String {
        return ""
    }
    
    public func mount(ipfsRoot: NSFileHandle, ipnsRoot: NSFileHandle) throws -> [String : String] {
        return [:]
    }
}


/// Move these to own file

public class Pin : ClientSubCommand {
    
    var parent: IpfsApiClient?

    public func add() {
        
    }
    
    public func ls() {
        
    }

    public func rm() {
        
    }

}




public class Repo : ClientSubCommand {
    var parent: IpfsApiClient?
}

public class IPFSObject {
    
}

public class Swarm : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func peers(completionHandler: ([Multiaddr]) -> Void) throws {
        try parent!.fetchData("swarm/peers?stream-channels=true") {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : [String]] else { throw IPFSAPIError.JSONSerializationFailed
                }
                
                guard let stringsData = json["Strings"] else {
                    throw IPFSAPIError.SwarmError("Swarm.peers error: No Strings key in JSON data.")
                }
                
                var addresses: [Multiaddr] = []
                for entry in stringsData as [String] {
                    addresses.append(try newMultiaddr(entry))
                }
                /// convert the data into a Multiaddr array and pass it to the handler
                completionHandler(addresses)
            } catch {
                print("Swarm peers error serializing JSON",error)
            }
        }
    }
    
    public func addrs(completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchData("swarm/addrs?stream-channels=true") {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IPFSAPIError.JSONSerializationFailed
                }
                guard let addrsData = json["Addrs"] else {
                    throw IPFSAPIError.SwarmError("Swarm.addrs error: No Addrs key in JSON data.")
                }
                completionHandler(addrsData as! [String : [String]])
            } catch {
                print("Swarm addrs error serializing JSON",error)
            }
        }
    }
    
    public func connect(multiAddr: String, completionHandler: (String) -> Void) throws {
        try parent!.fetchData("swarm/connect?arg="+multiAddr) {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IPFSAPIError.JSONSerializationFailed
                }
                /// Ensure we've only got one string as a result.
                guard let result = json["Strings"] where result.count == 1 else {
                    throw IPFSAPIError.SwarmError("Swarm.connect error: No Strings key in JSON data.")
                }

                completionHandler(result[0] as! String)
            } catch {
                print("Swarm addrs error serializing JSON",error)
            }
        }
        
    }
}

public struct Bootstrap {
    
}

public struct Block {
    
}

public struct Diag {
    
}

public struct Config {
    
}

public struct Refs {
    
}

public struct Update {
    
}

public struct DHT {
    
}

public struct File {
    
}

public struct Stats {
    
}

public struct Name {
    
}