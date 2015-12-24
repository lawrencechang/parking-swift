//
//  LawAnnotation.swift
//  lsp3
//
//  Created by Lawrence Chang on 12/22/15.
//  Copyright © 2015 Lawrence Chang. All rights reserved.
//

import Foundation
import MapKit

class LawAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var parkingAllowed : Bool?
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
    override convenience init() {
        self.init(coordinate: CLLocationCoordinate2DMake(10, 10), title: "default title", subtitle: "default subtitle");
    };
    
    func setParkingAllowed(allowed: Bool) { parkingAllowed = allowed }
    
    func isParkingAllowed() -> Bool { return parkingAllowed! }
    
}
