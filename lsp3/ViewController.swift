//
//  ViewController.swift
//  lsp3
//
//  Created by Lawrence Chang on 11/10/15.
//  Copyright © 2015 Lawrence Chang. All rights reserved.
//

import UIKit
import SwiftyJSON
import CoreData
import MapKit
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    var locations = [NSManagedObject]()
    // Notes:
    // Quite choppy at 3k annotations
    let MAX_ANNOTATIONS = 1000;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.mapView.delegate = self;
        initialize();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        locations.removeAll();
    }
/*
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated);
        
    }
*/
    
    // func - if num elements in core data is 0, load from JSON
    //        else load to array?
    func initialize() {
        print ("Checking for existing data in Core Data.");
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext
        
        let fetchRequest = NSFetchRequest(entityName: "Location")
        
        do {
            let results = try managedContext.executeFetchRequest(fetchRequest)
            locations = results as! [NSManagedObject]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        if locations.count == 0 {
            print("Core data was empty. Loading JSON. This will take a while.");
            loadJson();
        }
        else {
            print("Core data populated already. Loaded "+String(locations.count)+" locations.");
        }

        centerMap();
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.annotations();
        }
    }
    
    
    // func - load from JSON, save into core data
    func loadJson() {
        var currentID : Int;
        var latitude : Double;
        var longitude : Double;
        var text : String;
        let filename = "signs_parking";
        let filetype = "geojson";
        
        // For saving to Core Data
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate;
        let managedContext = appDelegate.managedObjectContext;
        
        if let path = NSBundle.mainBundle().pathForResource(filename, ofType: filetype) {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                print("Opening JSON file.");
                let jsonObj = JSON(data: data)
                print ("Done");
                if jsonObj != JSON.null {
                    if let features = jsonObj["features"].array {
                        // Create array of points
                        var counter = 0;
                        print("Saving locations from geojson.");
                        for feature in features {
                            /*
                            if counter < 500 {
                            }
                            else {
                                //break;
                            }
                            */
                            counter++;
                            currentID = feature["properties"]["OBJECTID"].int!;
                            latitude = feature["properties"]["LATITUDE"].double!;
                            longitude = feature["properties"]["LONGITUDE"].double!;
                            text = feature["properties"]["LIB__DESCR"].string!;
                            
                            // Save to core data
                            saveLocations(currentID,latitude: latitude,longitude: longitude,text: text,
                                mapDelegate: appDelegate, managedContext: managedContext);
                        }
                        print("Done.");
                    }
                } else {
                    print("could not get json from file, make sure that file contains valid json.")
                }
                
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
    }
    
    func saveLocations(currentID : Int, latitude: Double, longitude: Double, text: String, mapDelegate : AppDelegate, managedContext : NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Location", inManagedObjectContext: managedContext);
        let currentLocation = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedContext);
            
        currentLocation.setValue(currentID, forKey: "objectid");
        currentLocation.setValue(latitude, forKey: "latitude");
        currentLocation.setValue(longitude, forKey: "longitude");
        currentLocation.setValue(text, forKey: "text");
        
        do {
            try managedContext.save();
        } catch let error as NSError {
            print ("Could not save into core data: \(error), \(error.userInfo)");
            print ("location: "+String(currentID));
        }
    }
    
    // func - add annotations to map
    func annotations() {
        print("Creating annotations.");
        
        var annotations = [MKAnnotation]();
        for location in self.locations {
            let annotation = MKPointAnnotation();
            annotation.coordinate = CLLocationCoordinate2DMake(location.valueForKey("latitude") as! Double, location.valueForKey("longitude") as! Double);
            annotation.title = location.valueForKey("text") as? String;
            annotation.subtitle = String(location.valueForKey("objectid") as! Int);
            annotations.append(annotation);
            if annotations.count >= MAX_ANNOTATIONS {
                break;
            }
        }
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.rawValue), 0)) {
            self.mapView.addAnnotations(annotations);
            print("Done adding annotations.");
        }
    }
    
    func centerMap() {
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(34.026008, -118.479254), 12000, 12000)
        mapView.setRegion(region, animated: true)
    }
}

extension ViewController : MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotationSlow annotation: MKAnnotation) -> MKAnnotationView? {
        // simple and inefficient example
        let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "reuse identifier string");
        if Int(annotation.subtitle! as String!)! % 2 == 0 {
            annotationView.pinTintColor = UIColor.purpleColor();
        } else {
            annotationView.pinTintColor = UIColor.orangeColor();
        }
        //annotationView.animatesDrop = true; // For fun :)
        annotationView.canShowCallout = true; // For title pop up
        return annotationView
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("reuse");
        if annotationView != nil {
            annotationView!.annotation = annotation;
        } else {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "reuse");
        }
        /*
        if Int(annotation.subtitle! as String!)! % 2 == 0 {
            annotationView.pinTintColor = UIColor.purpleColor();
        } else {
            annotationView.pinTintColor = UIColor.orangeColor();
        }
        */
        //annotationView.canShowCallout = true; // For title pop up
        return annotationView
    }
}

