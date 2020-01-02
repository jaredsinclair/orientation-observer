//
//  ViewController.swift
//  SampleProject
//
//  Created by Jared Sinclair on 1/1/20.
//  Copyright © 2020 Nice Boy, LLC. All rights reserved.
//

import UIKit
import OrientationObserver
import Combine

extension UIInterfaceOrientation: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .landscapeLeft: return ".landscapeLeft"
        case .landscapeRight: return ".landscapeRight"
        case .portrait: return ".portrait"
        case .portraitUpsideDown: return ".portraitUpsideDown"
        default: return "<unknown>"
        }
    }
}

class ViewController: UIViewController {

    let observer = OrientationObserver()
    var subscriptions = Set<AnyCancellable>()

    @IBOutlet var label: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        observer.sink { [weak self] orientation in
            print("====================================\n\(orientation)\n====================================")
            self?.label.text = "\(orientation)"
        }.store(in: &subscriptions)
        observer.start()
    }

}
