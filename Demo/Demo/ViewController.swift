//
//  ViewController.swift
//  Demo
//
//  Created by Alex Usbergo on 27/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var fooView: FooView = FooView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Do any additional setup after loading the view, typically from a nib.
        self.view.addSubview(fooView)
    }
    
    override func viewDidLayoutSubviews() {
        self.fooView.frame = self.view.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

