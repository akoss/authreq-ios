//
//  DetailViewController.swift
//  authreq-ios
//
//  Created by Akos Szente on 23/01/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//

import UIKit
import AudioToolbox
import Piano

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var signatureStatusLabel: UILabel!
    @IBOutlet weak var declineButton: UIButton!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var timestampLabel: TopAlignedLabel!
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            if let item = titleLabel {
                item.text = detail.push_subtitle
            }
            if let item = detailDescriptionLabel {
                item.text = detail.push_text
            }
            
            if let item = timestampLabel {
                if let date = detail.timestamp as Date? {
                    item.text = date.getElapsedInterval()
                }
            }
            
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.long
            formatter.timeStyle = DateFormatter.Style.medium
            
            var dateString = ""
            
            if let ts = detail.reply_timestamp {
                dateString = formatter.string(from: ts as Date)
            }
            
            let expiryDateString = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(detail.expiry)) as Date)
            
            self.title = detail.short_title
            
            if(detail.reply_status == 0) {
                if(detail.isExpired()) {
                    acceptButton?.isHidden = true
                    declineButton?.isHidden = true
                    signatureStatusLabel?.text = "Expired at " + expiryDateString
                    imageView?.image = UIImage(named: "timeout")
                    imageView?.isHidden = false
                    signatureStatusLabel?.isHidden = false
                } else {
                    acceptButton?.isHidden = false
                    declineButton?.isHidden = false
                    signatureStatusLabel?.isHidden = true
                    imageView?.isHidden = true
                }
            } else {
                acceptButton?.isHidden = true
                declineButton?.isHidden = true
                
                if(detail.reply_status == 1) {
                    signatureStatusLabel?.text = "Signed at " + dateString
                    imageView?.image = UIImage(named: "tick")
                    imageView?.isHidden = false
                    signatureStatusLabel?.isHidden = false
                } else if(detail.reply_status == 2) {
                    signatureStatusLabel?.text = "Declined at " + dateString
                    imageView?.image = UIImage(named: "failure")
                    imageView?.isHidden = false
                    signatureStatusLabel?.isHidden = false
                }
            }
        }
    }
    
    @IBAction func acceptTap(_ sender: Any) {
        if let detail = detailItem {
            if(detail.sign()) {
                let symphony: [Piano.Note] = [
                    .sound(.asset(name: "payment_success")),
                    .hapticFeedback(.notification(.success))
                ]
                
                Piano.play(symphony)
            }
            configureView()
        }
    }
    @IBAction func declineTap(_ sender: Any) {
        if let detail = detailItem {
            detail.decline()
            let symphony: [Piano.Note] = [
                .hapticFeedback(.notification(.warning))
            ]
            Piano.play(symphony)
            configureView()
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

