//
//  MainViewController.swift
//  UpDownload
//
//  Created by Mon on 21/09/2017.
//  Copyright © 2017 wenyongyang. All rights reserved.
//

import UIKit
import SnapKit

private let CellID = "cell"

enum RequestType {
    case native
    case alamofire
}

class MainViewController: UIViewController {
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.rowHeight = 48
        view.dataSource = self
        view.delegate = self
        view.register(UITableViewCell.self, forCellReuseIdentifier: CellID)
        return view
    }()
    
    override func loadView() {
        view = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        title = "Main"
        view.backgroundColor = .white
        if #available(iOS 11, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func somethingElseTest() {
        let aView = UIView()
        aView.backgroundColor = .orange
        view.addSubview(aView)
        
        let bView = UIView()
        bView.backgroundColor = .yellow
        view.addSubview(bView)
        
        let cView = UIView()
        cView.backgroundColor = .blue
        view.addSubview(cView)
        
        aView.snp.makeConstraints { (make) in
            make.left.right.equalTo(view)
            make.top.equalTo(view)
            make.bottom.equalTo(view)
        }
        
        bView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 100, height: 100))
            if #available(iOS 11, *) {
                make.top.equalTo(aView.safeAreaLayoutGuide.snp.top)
            } else {
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
            }
        }
        
        cView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 100, height: 100))
            if #available(iOS 11, *) {
                make.bottom.equalTo(aView.safeAreaLayoutGuide.snp.bottom)
            } else {
                make.bottom.equalTo(self.bottomLayoutGuide.snp.bottom)
            }
        }
    }
}

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID, for: indexPath)
        cell.textLabel?.text = indexPath.row == 0 ? "Native" : "Alamofire"
        return cell
    }
}

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = ListViewController()
        vc.requestType = indexPath.row == 0 ? .native : .alamofire
        navigationController?.pushViewController(vc, animated: true)
    }
}
