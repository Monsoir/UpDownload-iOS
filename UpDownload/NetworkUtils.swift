//
//  NetworkUtils.swift
//  UpDownload
//
//  Created by Mon on 22/09/2017.
//  Copyright © 2017 wenyongyang. All rights reserved.
//

import UIKit
import MobileCoreServices

private let boundary = "abcdefghijklmnopgrstuv1234567890"

class NetworkUtils: NSObject {
    static func request(with url: URL, httpMethod: String = "GET", params: [String: String]?) -> URLRequest {
        let body: String? = {
            guard let _ = params else { return nil }
            
            let pairs = params!.map({ (key, value) -> String in
                return "\(key)=\(value)"
            })
            return "?" + pairs.joined(separator: "&")
        }()
        
        let theURL = url.appendingPathComponent(body ?? "")
        
        let request: URLRequest = {
            var request = URLRequest(url: theURL)
            request.httpMethod = httpMethod
            return request
        }()
        
        return request
    }
    
    static func GETRequest(with url: URL, params: [String: String]?) -> URLRequest {
        return self.request(with: url, params: params)
    }
    
    static func GETData(with request: URLRequest, completion: @escaping ((Data?, HTTPURLResponse?, Error?) -> ())) {
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            completion(data, response as? HTTPURLResponse, error)
        }
        task.resume()
    }
    
    static func uploadRequest(with url: URL, params: [String: String]?, uploadingFilePaths: [URL]) -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    static func uploadBody(with params: [String: String]?, uploadingFilePaths: [URL]) throws -> Data {
        var data = Data()
        
        if let p = params {
            for (key, value) in p {
                data.append("--\(boundary)\r\n")
                data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                data.append("\(value)\r\n\r\n")
            }
        }
        
        for path in uploadingFilePaths {
            let fileName = path.lastPathComponent
            let fileData = try Data(contentsOf: path)
            let mimetype = mimeType(for: path)
            
            data.append("--\(boundary)\r\n")
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
            data.append("Content-Type: \(mimetype)\r\n\r\n")
            data.append(fileData)
            data.append("\r\n")
        }
        
        data.append("--\(boundary)--\r\n") // 注意这里
        
        /**
         Error: MultipartParser.end(): stream ended unexpectedly: state = START_BOUNDARY
 **/
        
        return data
    }
    
    static func uploadData(_ data: Data, request: URLRequest, uploadDelegate: URLSessionTaskDelegate) -> URLSessionUploadTask {
        let defaultConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: defaultConfiguration, delegate: uploadDelegate, delegateQueue: nil)
        let task = session.uploadTask(with: request, from: data)
        task.resume()
        return task
    }
    
    static func downloadData(with request: URLRequest, downloadDelegate: URLSessionDownloadDelegate) -> URLSessionDownloadTask {
        let defaultConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: defaultConfiguration, delegate: downloadDelegate, delegateQueue: nil)
        let task = session.downloadTask(with: request)
        task.resume()
        return task
    }
}

extension NetworkUtils {
    static func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
}

extension Data {
    mutating func append(_ aString: String) {
        if let data = aString.data(using: .utf8) {
            append(data)
        }
    }
}
