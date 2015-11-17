//
//  MyAnnotation.swift
//  lsp3
//
//  Created by Lawrence Chang on 11/13/15.
//  Copyright © 2015 Lawrence Chang. All rights reserved.
//

import Foundation
import MapKit

class MyAnnotation : NSObject, MKAnnotation {
    let coordinate : CLLocationCoordinate2D;
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate;
        super.init();
    }
}