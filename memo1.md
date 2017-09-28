# 上传下载客户端 iOS - 原生操作

开发环境：

Xcode 9.0
iOS 11
Swift 4.0

以下代码的位置在 UpDownload/NetworkUtils.swift 中，由 ListViewModel 负责调用

## 原生 URLSession

使用 URLSession 进行网络请求的步骤一般是：

1. 创建一个 URLRequest 对象，在这个对象中，配置的东西包括但不限于：
    - 设置 HTTP 方法，GET, POST 等
    - 配置请求的 URL. 在原始的 URL 之上，将参数拼接成 `?key1=value1&key2=value2&...` 的形式，再拼接到原始的 URL 后
2. 创建一个 URLSession 对象，一般情况下会直接使用 `let session = URLSession.shared` 来获取一个 URLSession 实例
3. 使用 1 中的创建的 URLRequest 请求对象，和 2 中的 URLSession 会话对象，生成一个 URLSessionTask 实例，这个 URLSessionTask 是请求任务的基类，包括了：
    - URLSessionDataTask 下载响应数据，并将这些数据直接存储到内存中，不支持后台运行
    - URLSessionUploadTask 上传数据，一般使用的 HTTP 方法为 POST/PUT，支持后台运行
    - URLSessionDownloadTask 下载数据，将数据保存到文件，支持后台运行，也支持当 App 被挂起或已经不在运行的状态下进行
    - URLSessionStreamTask 直接基于 TCP/IP 协议使用的，不多说了
4. 也是最重要的一步，对于 3 中生成的 URLSessionTask 实例，一定要调用 `resume()` 方法，否则请求并不会发出去

## 检索文件 - 泛用型数据请求

1. 构造 URLRequest 请求对象

    ```swift
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
    ```
    
    这里面，做的事情有：
    
    - 生成一个 URLRequest 对象
    - 结合参数，生成最后请求用的 URL
    - 配置请求的 HTTP 方法

2. 创建一个 task 并发起请求

    ```swift
    static func GETData(with request: URLRequest, completion: @escaping ((Data?, HTTPURLResponse?, Error?) -> ())) {
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            completion(data, response as? HTTPURLResponse, error)
        }
        task.resume()
    }
    ```
    
    这里面，做的事情有：
    
    - 生成一个 URLSession 对象
    - 根据 URLSession 和 URLRequest, 生成一个 URLSessionDataTask 对象
    - 调用 `resume()` 使请求继续

## 下载文件 - 泛用型下载

1. 构造 URLRequest 请求对象

    可以直接调用检索文件中的构造请求的方法来生成一个 URLRequest 对象

2. 创建一个 task 并发起请求

```swift
static func downloadData(with request: URLRequest, downloadDelegate: URLSessionDownloadDelegate) -> URLSessionDownloadTask {
    let defaultConfiguration = URLSessionConfiguration.default
    let session = URLSession(configuration: defaultConfiguration, delegate: downloadDelegate, delegateQueue: nil)
    let task = session.downloadTask(with: request)
    task.resume()
    return task
}
```

这里做的事情有：

- 生成一个创建 URLSession 会用到的 URLSessionConfiguration 对象
- 通过 URLSessionConfiguration 创建一个 URLSession
- 由于在下载的过程中，我们一般都会希望能监控到下载的进度，因此，在创建 URLSession 时，需要指定一个 delegate, 下载的过程中，系统会不间断地调用这个 delegate 中的方法来回传进度
- 根据 URLSession 和 URLRequest, 生成一个 URLSessionDownloadTask 对象
- 要监控下载进度，就需要有一个类来实现 `URLSessionDownloadDelegate` 协议，同时这个类里面需要实现2个方法
    - 监控下载的进度

        ```swift
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
        ```

    - 监控下载完成的事件，同时会获得一个临时存放下载文件的路径

        ```swift
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
        ``` 


> 要注意的是
> 
> 在监控下载进度的时候，totalBytesWritten 和 totalBytesExpectedToWrite 是 Int64 类型，要获取到百分比形式的进度，需要分别将它们转为 Float 类型后再相处，即
> 
> `let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)`
> 
> 否则，得出的进度只会永远是 0 或 1


## 上传文件 - 泛用型上传

1. 构造 URLRequest 请求对象

    由于上传文件使用的 HTTP 方法是 POST 方法，同时，请求体里面包含了文件数据，所以不能复用之前的 URLRequest 对象生成的方法，需要另外再写一个方法


    ```swift
    static func uploadRequest(with url: URL, params: [String: String]?, uploadingFilePaths: [URL]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    ```
    
    这里做的事情有：
    
    - 根据给定的 URL 生成一个 URLRequest 对象
    - 设置 request 的 HTTP 请求方法
    - 设置 request 的请求头部，由于上传文件的需要，我们将 MIME type 设置为 `multipart/form-data;`, 同时，要设置一个 boundary 分割符来隔离体中不同的内容


    > Multipart types 表示细分领域的文件类型的种类，经常对应不同的 MIME类型。这是 复合文 件的一种表现方式


2. 创建请求主体

    由于 POST 方法的请求体会比较复杂，因此额外再写一个方法用来生成这个请求体

    ```swift
    
    static func uploadBody(with params: [String: String]?, uploadingFilePaths: [URL]) throws -> Data {
        // 1
        var data = Data()
        
        // 2
        if let p = params {
            for (key, value) in p {
                data.append("--\(boundary)\r\n")
                data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                data.append("\(value)\r\n\r\n")
            }
        }
        
        // 3
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
        
        // 4
        data.append("--\(boundary)--\r\n")
        
        return data
    }
    ```
    
    这里做的事情有：
    
    - 第一部分，创建一个可变的 Data 对象，再后面将会不断向它添加数据
    - 第二部分，遍历传进来的参数，并且手动将它们添加到 `data` 中
        1. 需要添加分割符 `--\(boundary)\r\n`, 在这里，分割符定义为了 `abcdefghijklmnopgrstuv1234567890`
        2. 添加参数内容类型 `Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n`
        3. 添加参数值 `\(value)\r\n\r\n`
    
        这里还存在了一个方法，自动将字符串转化为 Data 类型并拼接到一个 Data 对象中
    
        ```swift
        extension Data {
            mutating func append(_ aString: String) {
                if let data = aString.data(using: .utf8) {
                    append(data)
                }
            }
        }
        ```
        
    - 第三部分，遍历传进来的文件路径，读取文件数据并添加到 `data` 中
        1. 读取文件数据
            
            ```swift
            let fileData = try Data(contentsOf: path)
            ```
        2. 确定这个文件数据的 MIME type
    
            ```swift
            let mimetype = mimeType(for: path)
            ```
            
            确定 MIME type 的方法
            
            ```swift
            static func mimeType(for url: URL) -> String {
                let pathExtension = url.pathExtension
                
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
                    if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                        return mimetype as String
                    }
                }
                return "application/octet-stream";
            } 
            ```
        3. 添加分割符
    
            ```swift
            data.append("--\(boundary)\r\n")
            ```
        
        4. 添加参数内容类型
    
            ```swift
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
            ```
            
        5. 添加参数值的内容协商值
    
    
            ```swift
            data.append("Content-Type: \(mimetype)\r\n\r\n")
            ```
        
        6. 添加参数值，即文件数据
    
    
            ```swift
            data.append(fileData)
            ```
    
        7. 添加该部分内容的结束标志
    
            ```swift
            data.append("\r\n")
            ```
    
    - 第四部分，添加整个请求体的结束标志
    
        ```swift
        data.append("--\(boundary)--\r\n")
        ```
        
        > 若没有添加请求体的结束标志，将会报错：
        > 
        > ```
        > Error: MultipartParser.end(): stream ended unexpectedly: state = START_BOUNDARY
        > ```

3. 创建一个 task 并发起请求

```swift
static func uploadData(_ data: Data, request: URLRequest, uploadDelegate: URLSessionTaskDelegate) -> URLSessionUploadTask {
    let defaultConfiguration = URLSessionConfiguration.default
    let session = URLSession(configuration: defaultConfiguration, delegate: uploadDelegate, delegateQueue: nil)
    let task = session.uploadTask(with: request, from: data)
    task.resume()
    return task
}
```
    
这里做的事情有：

- 生成一个创建 URLSession 会用到的 URLSessionConfiguration 对象
- 通过 URLSessionConfiguration 创建一个 URLSession
- 由于在上传的过程中，我们一般都会希望能监控到上传的进度，因此，在创建 URLSession 时，需要指定一个 delegate, 上传的过程中，系统会不间断地调用这个 delegate 中的方法来回传进度
- 根据 URLSession 和 URLRequest, 生成一个 URLSessionDownloadTask 对象
- 要监控上传进度，就需要有一个类来实现 `URLSessionTaskDelegate` 协议，同时这个类里面需要实现2个方法
    - 监控上传的进度

        ```swift
        func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
        ```

    - 监控上传完成的事件

        ```swift
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
        ```


## References

- [MDN 关于 Content-Disposition 的介绍](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Content-Disposition)
- [Stack Overflow 上关于上传文件的写法](https://stackoverflow.com/a/26163136/5211544)

