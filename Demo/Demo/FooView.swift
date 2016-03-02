//
//  MyView.swift
//  Demo
//
//  Created by Alex Usbergo on 27/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import UIKit

class FooView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.didChangeAppearanceProxy()
    }
    
    func didChangeAppearanceProxy() {
        self.backgroundColor = self.appearanceProxy.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}