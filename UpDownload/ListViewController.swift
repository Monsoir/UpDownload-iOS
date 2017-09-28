//
//  ListViewController.swift
//  UpDownload
//
//  Created by Mon on 22/09/2017.
//  Copyright © 2017 wenyongyang. All rights reserved.
//

import UIKit

private let CellID = "cell"

class ListViewController: UIViewController {
    
    let vm = ListViewModel()
    
    var requestType: RequestType {
        set {
            vm.requestType = newValue
        }
        get {
            return vm.requestType
        }
    }
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.rowHeight = UITableViewAutomaticDimension
        view.estimatedRowHeight = 48
        view.dataSource = self
        view.delegate = self
        view.register(UITableViewCell.self, forCellReuseIdentifier: CellID)
        return view
    }()
    
    lazy var lbPrompt: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.backgroundColor = .lightGray
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupViewModel()
        setupNavigationBar()
        setupSubviews()
        vm.fetchData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ListViewController {
    func setupViewModel() {
        vm.didFetchData = { [weak self] (error, [File]) in
            switch error {
            case .local:
                DispatchQueue.main.async {
                    self?.lbPrompt.text = "local error"
                }
            case .server(let code):
                DispatchQueue.main.async {
                    self?.lbPrompt.text = "server error: \(code)"
                }
            case .none:
                DispatchQueue.main.async {
                    self?.lbPrompt.text = "OK"
                    self?.tableView.reloadData()
                }
            }
        }
        
        vm.downloadProgress = { [weak self] (progress) in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.lbPrompt.text = "\(progress * 100)"
            }
        }
        
        vm.downloadComplete = { [weak self] (destination) in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.lbPrompt.text = ""
            }
        }
        
        vm.uploadProgress = { [weak self] (progress) in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.lbPrompt.text = String(format: "%.2f", progress)
            }
        }
        
        vm.uploadComplete = { [weak self] in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.lbPrompt.text = "Done"
            }
        }
    }
    
    func setupSubviews() {
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        view.addSubview(lbPrompt)
        
        lbPrompt.snp.makeConstraints { (make) in
            if #available(iOS 11, *) {
                make.left.right.equalTo(view.safeAreaLayoutGuide)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            } else {
                make.left.right.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
            }
            
            make.height.equalTo(48)
        }
        
        tableView.snp.makeConstraints { (make) in
            if #available(iOS 11, *) {
                make.left.right.equalTo(view.safeAreaLayoutGuide)
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            } else {
                make.left.right.equalTo(view)
                make.top.equalTo(self.topLayoutGuide.snp.top)
            }
            make.bottom.equalTo(lbPrompt.snp.top)
        }
    }
    
    func setupNavigationBar() {
        title = "Files"
        if #available(iOS 11, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
        
        let selectPhotoItem = UIBarButtonItem(title: "Choose", style: .plain, target: self, action: #selector(actionSelectPhoto))
        navigationItem.rightBarButtonItem = selectPhotoItem
    }
    
    @objc func actionSelectPhoto() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        
        present(picker, animated: true, completion: nil)
    }
}

extension ListViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print(info)
        if #available(iOS 11.0, *) {
            let imageURL = info[UIImagePickerControllerImageURL] as! URL
            vm.uploadFile(imageURL)
            picker.dismiss(animated: true, completion: nil)
        } else {
            // Fallback on earlier versions
        }
    }
}

extension ListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.vm.files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID, for: indexPath)
        cell.textLabel?.numberOfLines = 0
        let file = self.vm.files[indexPath.row]
        cell.textLabel?.text = file.fileName
        return cell
    }
}

extension ListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let fileName = vm.files[indexPath.row].fileName
        let alert = UIAlertController(title: "Sure to downlaod?", message: nil, preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let actionConfirm = UIAlertAction(title: "Confirm", style: .default) { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.vm.downloadFile(fileName: fileName)
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)
        present(alert, animated: true, completion: nil)
    }
}
