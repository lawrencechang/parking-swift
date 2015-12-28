//
//  Timer.swift
//  lsp3
//
//  Created by Lawrence Chang on 12/28/15.
//  Copyright © 2015 Lawrence Chang. All rights reserved.
//

import Foundation

class Timer {
    var timer = NSTimer();
    var callBackFunction : () -> Void;
    
    init(callBackFunction : () -> Void) {
        self.callBackFunction = callBackFunction;
    }
    
    func run() {
        
    }
}