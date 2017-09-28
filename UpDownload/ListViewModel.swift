//
//  ListViewModel.swift
//  UpDownload
//
//  Created by Mon on 22/09/2017.
//  Copyright © 2017 wenyongyang. All rights reserved.
//

import Foundation
import Alamofire

enum ListViewModelError: Error {
    case none
    case local
    case server(errorCode: Int)
}

class ListViewModel: NSObject {
    var files = [File]()
    var requestType: RequestType = .native
    var didFetchData: ((ListViewModelError, [File]) -> Void)?
    var downloadProgress: ((_ progress: Float) -> Void)?
    var downloadComplete: ((_ destination: URL?) -> Void)?
    var uploadProgress: ((_ progress: Float) -> Void)?
    var uploadComplete: (() -> Void)?
    
    lazy var dataTasks = [TaskPresenter]()
    
    func fetchData() {
        requestType == .native ? fetchDataNativeWay() : fetchDataAlamofireWay()
    }
    
    func downloadFile(fileName: String) {
        requestType == .native ? downloadNativeWay(with: fileName) : downloadAlamofireWay(with: fileName)
    }
    
    func uploadFile(_ url: URL) {
        requestType == .native ? uploadFileNativeWay(url) : uploadFileAlamorefireWay(url)
    }
    
    private func fetchDataNativeWay() {
        let url = URL(string: "\(RemoteAddress)/files")!
        let request = NetworkUtils.GETRequest(with: url, params: nil)
        NetworkUtils.GETData(with: request) { [weak self] (data, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            
            guard let response = response else {
                strongSelf.didFetchData?(.local, strongSelf.files)
                return
            }
            
            guard response.statusCode == 200 else {
                print(error ?? "no error")
                strongSelf.didFetchData?(.server(errorCode: response.statusCode), strongSelf.files)
                return
            }
            
            do {
                let tmp = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? Dictionary<String, Any>
                guard let objects = tmp, let files = objects["files"] as? [String] else {
                    strongSelf.didFetchData?(.local, strongSelf.files)
                    return
                }
                
                let newFiles = files.map({ (file) -> File in
                    return File(fileName: file, remotePath: "")
                })
                
                strongSelf.files.append(contentsOf: newFiles)
                strongSelf.didFetchData?(.none, strongSelf.files)
                
            } catch {
                strongSelf.didFetchData?(.local, strongSelf.files)
            }
        }
    }
    
    private func fetchDataAlamofireWay() {
        Alamofire.request("\(RemoteAddress)/files").responseJSON { [weak self] (response) in
            guard let strongSelf = self else { return }
            
            guard let res = response.response else {
                strongSelf.didFetchData?(.local, strongSelf.files)
                return
            }
            
            guard res.statusCode == 200 else {
                strongSelf.didFetchData?(.server(errorCode: res.statusCode), strongSelf.files)
                return
            }
            
            if let json = response.result.value as? Dictionary<String, Any> {
                guard let files = json["files"] as? [String] else {
                    strongSelf.didFetchData?(.local, strongSelf.files)
                    return
                }
                
                let newFiles = files.map({ (file) -> File in
                    return File(fileName: file, remotePath: "")
                })
                
                strongSelf.files.append(contentsOf: newFiles)
                strongSelf.didFetchData?(.none, strongSelf.files)
            }
        }
    }

    private func downloadNativeWay(with fileName: String) {
        let url = URL(string: "\(RemoteAddress)/download/\(fileName)".addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!
        let request = NetworkUtils.GETRequest(with: url, params: nil)
        let task = NetworkUtils.downloadData(with: request, downloadDelegate: self)
        
        let taskP = TaskPresenter()
        taskP.name = fileName
        taskP.task = task
        dataTasks.append(taskP)
    }
    
    private func downloadAlamofireWay(with fileName: String) {
        let destination: DownloadRequest.DownloadFileDestination = {_, _ in
            let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentURL.appendingPathComponent(fileName, isDirectory: false)
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        let url = URL(string: "\(RemoteAddress)/download/\(fileName)".addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!
        Alamofire.download(url, method: .get, parameters: nil, headers: nil, to: destination)
            .downloadProgress { [weak self] (progress) in
                guard let strongSelf = self else { return }
                let percent = Float(progress.completedUnitCount) / Float(progress.totalUnitCount)
                strongSelf.downloadProgress?(percent)
            }
            .responseData { [weak self] (response) in
                guard let strongSelf = self else { return }
                strongSelf.downloadComplete?(response.destinationURL!)
            }
    }
    
    private func uploadFileNativeWay(_ imageURL: URL) {
        let url = URL(string: "\(RemoteAddress)/upload")!
        let request = NetworkUtils.uploadRequest(with: url, params: nil, uploadingFilePaths: [])
        let data = try! NetworkUtils.uploadBody(with: ["extra": "111"], uploadingFilePaths: [imageURL])
        let _ = NetworkUtils.uploadData(data, request: request, uploadDelegate: self)
    }
    
    private func uploadFileAlamorefireWay(_ imageURL: URL) {
        let url = URL(string: "\(RemoteAddress)/upload")!
        Alamofire.upload(multipartFormData: { (data) in
            data.append(try! Data(contentsOf: imageURL), withName: "file", fileName: imageURL.lastPathComponent, mimeType: NetworkUtils.mimeType(for: imageURL))
        }, to: url) { (result) in
            switch result {
            case .success(let upload, _, _):
                upload.uploadProgress(closure: { [weak self] (progress) in
                    guard let strongSelf = self else { return }
                    strongSelf.uploadProgress?(Float(progress.completedUnitCount) / Float(progress.totalUnitCount))
                })
                upload.responseData(completionHandler: { [weak self] (response) in
                    guard let strongSelf = self else { return }
                    strongSelf.uploadComplete?()
                })
            case .failure(let err):
                print(err)
            }
        }
    }
}

extension ListViewModel: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
//        print(String(format: "%.2f", progress * 100))
        uploadProgress?(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        uploadComplete?()
    }
}

extension ListViewModel: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        downloadProgress?(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let task = dataTasks.popLast() {
            let filePath = (DocumentFolder!.appending("/\(task.name!)"))
            if FileManager.default.fileExists(atPath: filePath) {
                try! FileManager.default.removeItem(atPath: filePath)
            }
            
            let destination = URL(fileURLWithPath: filePath, isDirectory: false)
            try! FileManager.default.moveItem(at: location, to: destination)
            
            downloadComplete?(destination)
        }
    }
    
}
