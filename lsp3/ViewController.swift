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

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    var locations = [NSManagedObject]()
    var locationManager = CLLocationManager();
    // Quite choppy at 3k annotations
    let MAX_ANNOTATIONS = 1000;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.rotateEnabled = false;
        mapView.pitchEnabled = false;
        userLocation();
        initialize();
        currentDayAndTime();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        locations.removeAll();
        initialize();
    }
    
    // User location stuff
    func userLocation() {
        locationManager.delegate = self;
        locationManager.requestWhenInUseAuthorization();
        mapView.showsUserLocation = true; // This seems to do nothing on its own
    }
    
    // If num elements in core data is 0, load from JSON
    // else load to array?
    func initialize() {
        centerMap();
        
        print ("Checking for existing data in Core Data.");
        loadFromCoreDataToArray();
        
        if locations.count == 0 {
            print("Core data was empty. Loading JSON. This will take a while.");
            loadJson();
            loadFromCoreDataToArray();
        }
        else {
            print("Core data populated already. Loaded "+String(locations.count)+" locations.");
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.annotations();
        }
    }
    
    func loadFromCoreDataToArray() {
        print("Loading from Core Data to array.");
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: "Location")
        do {
            let results = try managedContext.executeFetchRequest(fetchRequest)
            locations = results as! [NSManagedObject]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        print("Loaded.");
        
        // Debug
        /*
        print("number of elements in locations array: "+String(locations.count));
        if (locations.count <= 0) {
            
        } else {
            let currentLat = locations[0].valueForKey("latitude") as! Double;
            let currentLong = locations[0].valueForKey("longitude") as! Double;
            print("location[0]: " + String(currentLat) + " " + String(currentLong) );
        }
        */
        
    }
    
    // Load from geo JSON, save into core data
    func loadGeoJson() {
        var currentID : Int;
        var latitude : Double;
        var longitude : Double;
        var text : String;
        let filename = "signs_parking"; let filetype = "geojson";
        
        // For saving to Core Data
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate;
        let managedContext = appDelegate.managedObjectContext;
        
        if let path = NSBundle.mainBundle().pathForResource(filename, ofType: filetype) {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                print("Opening JSON file.");
                let jsonObj = JSON(data: data)
                print ("JSON file opened.");
                if jsonObj != JSON.null {
                    if let features = jsonObj["features"].array {
                        // Create array of points
                        var counter = 0;
                        print("Saving locations from geojson to Core Data.");
                        let startTime = NSDate();
                        for feature in features {
                            counter++;
                            
                            currentID = feature["properties"]["OBJECTID"].int!;
                            latitude = feature["properties"]["LATITUDE"].double!;
                            longitude = feature["properties"]["LONGITUDE"].double!;
                            text = feature["properties"]["LIB__DESCR"].string!;
                            
                            // Save to core data
                            saveLocations(currentID,latitude: latitude,longitude: longitude,text: text,
                                mapDelegate: appDelegate, managedContext: managedContext);
                        }
                        print("Data saved.");
                        let endTime = NSDate();
                        print("["+String(endTime.timeIntervalSinceDate(startTime))+" seconds elapsed.]");
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
    
    // Load from JSON, save into core data
    func loadJson() {
        var currentID : Int;
        var latitude : Double;
        var longitude : Double;
        var text : String;
        var description : String;
        let filename = "signs_locations"; let filetype = "json";
        
        // For saving to Core Data
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate;
        let managedContext = appDelegate.managedObjectContext;
        
        if let path = NSBundle.mainBundle().pathForResource(filename, ofType: filetype) {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                print("Opening JSON file: "+filename+"."+filetype);
                let jsonObj = JSON(data: data)
                print ("JSON file opened.");
                if jsonObj != JSON.null {
                    print("Saving locations from geojson to Core Data.");
                    let startTime = NSDate();
                    var counter = 0;
                    for (key,subJson):(String,JSON) in jsonObj {
                        counter++;
                        if (counter % 100 == 0) {
                            print(counter);
                        }
                        currentID = subJson["id"].int!;
                        latitude = subJson["latitude"].double!;
                        longitude = subJson["longitude"].double!;
                        text = subJson["time1"].string! + ", " + subJson["time2"].string!;
                        // Save to core data
                        saveLocations(currentID,latitude: latitude,longitude: longitude,text: text,
                            mapDelegate: appDelegate, managedContext: managedContext);
                    }
                    print("Data saved.");
                    let endTime = NSDate();
                    print("["+String(endTime.timeIntervalSinceDate(startTime))+" seconds elapsed.]");
                    print("We found "+String(counter)+" items.");
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
        
        dispatch_async(dispatch_get_main_queue()) {
            var counter = 0;
            var annotations = [MKAnnotation]();
            for location in self.locations {
                counter++;
                let annotation = MKPointAnnotation();
                annotation.coordinate = CLLocationCoordinate2DMake(location.valueForKey("latitude") as! Double, location.valueForKey("longitude") as! Double);
                annotation.title = location.valueForKey("text") as? String;
                annotation.subtitle = String(location.valueForKey("objectid") as! Int);
                annotations.append(annotation);
                if annotations.count >= self.MAX_ANNOTATIONS {
                    break;
                }
            }
            self.mapView.addAnnotations(annotations);
            print("Done adding " + String(counter) + " annotations.");
        }
    }
    
    func centerMap() {
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(34.026008, -118.479254), 12000, 12000)
        mapView.setRegion(region, animated: true)
    }
    
    func currentDayAndTime() {
        // From: http://stackoverflow.com/questions/24070450/how-to-get-the-current-time-and-hour-as-datetime/32445947#32445947
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Weekday, .Hour, .Minute], fromDate: date)
        let hour = components.hour
        let minute = components.minute
        let day = components.weekday
        print("Current day is: "+String(day));
        print("Current hour is: "+String(hour));
        print("Current minute is: "+String(minute));
    }
}
