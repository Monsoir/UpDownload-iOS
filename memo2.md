# 上传下载客户端 iOS - Alamofire

开发环境

Xcode 9.0
iOS 11
Swift 4.0
Alamofire 4.0

以下代码位于 UpDownload/ListViewModel.swift 中，由 ListViewModel 负责调用

## 检索文件

```swift
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
```


通过 Alamorefire 请求 JSON 数据，简单地调用
    
    ```swift
    Alamofire.request("\(RemoteAddress)/files").responseJSON { (response) in
        // TODO...
    }
    ```

## 下载文件

```swift
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
```

使用 Alamofire 下载文件的步骤有：

1. 创建一个 `DownloadRequest.DownloadFileDestination` 对象，用来指定下载文件最终的保存位置，因为下载的文件是存放在一个暂存区域中
2. 可以看到，生成 `DownloadRequest.DownloadFileDestination` 对象的闭包里，返回的是一个 tuple, 这个 tuple 里面有两个元素
    - 最终保存位置的路径
    - 一个数组，存放着一些标记，针对旧文件与新文件的一些操作指示
3. 调用下载的 api, 传入之前生成的 `DownloadRequest.DownloadFileDestination` 对象

    ```swift
    Alamofire.download(url, method: .get, parameters: nil, headers: nil, to: destination)
    .downloadProgress { (progress) in
        // TODO...
    }
    .responseData { (response) in
        // TODO...
    }
    ```
    
    其中包含了下载进度的监控和下载完成之后的监控，而下载进度的监控，如果不需要的话，可以直接把 `downloadProgress` 这条链式调用去掉

## 上传文件

```swift
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
```

使用 Alamofire 上传文件，直接调用 api

```swift
Alamofire.upload(multipartFormData: { (data) in
    // 拼接上传数据
}, to: url) { (result) in
    switch result {
    case .success(let upload, _, _):
        upload.uploadProgress(closure: { (progress) in
            // 监控上传进度
        })
        upload.responseData(completionHandler: { (response) in
            // 监控上传完成事件
        })
    case .failure(let err):
        // 上传失败
    }
}
```

## References

- [Stack Overflow 上关于使用 Alamofire 上传文件的操作](https://stackoverflow.com/a/40521003/5211544)

