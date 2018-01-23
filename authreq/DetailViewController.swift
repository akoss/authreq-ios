//
//  DetailViewController.swift
//  authreq-ios
//
//  Created by Akos Szente on 23/01/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!


    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            if let label = detailDescriptionLabel {
                label.text = detail.timestamp!.description
            }
            self.title = detail.short_title
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var detailItem: SignatureRequest? {
        didSet {
            // Update the view.
            configureView()
        }
    }


}

