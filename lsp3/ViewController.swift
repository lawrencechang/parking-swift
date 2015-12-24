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

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

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
        
        mapView.delegate = self;
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
                    for (locationKey,subJson):(String,JSON) in jsonObj {
                        counter++;
                        if (counter % 100 == 0) {
                            print(counter);
                        }
                        if (counter >= MAX_ANNOTATIONS) {
                            break;
                        }
                        currentID = subJson["id"].int!;
                        latitude = subJson["latitude"].double!;
                        longitude = subJson["longitude"].double!;
                        text = subJson["time1"].string! + ", " + subJson["time2"].string!;
                        
                        let sundayBools = boolsFromTimesInJson("sun",jsonObject : subJson);
                        let mondayBools = boolsFromTimesInJson("mon",jsonObject : subJson);
                        let tuesdayBools = boolsFromTimesInJson("tues",jsonObject : subJson);
                        let wednesdayBools = boolsFromTimesInJson("wed",jsonObject : subJson);
                        let thursdayBools = boolsFromTimesInJson("thurs",jsonObject : subJson);
                        let fridayBools = boolsFromTimesInJson("fri",jsonObject : subJson);
                        let saturdayBools = boolsFromTimesInJson("sat",jsonObject : subJson);
                        
                        // Save to core data
                        saveLocations(currentID,latitude: latitude,longitude: longitude,text: text,
                            mapDelegate: appDelegate, managedContext: managedContext,
                            sundayBools: sundayBools,
                            mondayBools: mondayBools,
                            tuesdayBools: tuesdayBools,
                            wednesdayBools: wednesdayBools,
                            thursdayBools: thursdayBools,
                            fridayBools: fridayBools,
                            saturdayBools: saturdayBools
                        );
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

    func saveLocations(currentID : Int, latitude: Double, longitude: Double, text: String, mapDelegate : AppDelegate, managedContext : NSManagedObjectContext,
        sundayBools : Array<Bool>,
        mondayBools : Array<Bool>,
        tuesdayBools : Array<Bool>,
        wednesdayBools : Array<Bool>,
        thursdayBools : Array<Bool>,
        fridayBools : Array<Bool>,
        saturdayBools : Array<Bool>
    ) {
        let entityLocation = NSEntityDescription.entityForName("Location", inManagedObjectContext: managedContext);
        let currentLocation = NSManagedObject(entity: entityLocation!, insertIntoManagedObjectContext: managedContext);
        
        let entityTimesSun = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesSun = NSManagedObject(entity: entityTimesSun!, insertIntoManagedObjectContext: managedContext);
        let entityTimesMon = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesMon = NSManagedObject(entity: entityTimesMon!, insertIntoManagedObjectContext: managedContext);
        let entityTimesTues = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesTues = NSManagedObject(entity: entityTimesTues!, insertIntoManagedObjectContext: managedContext);
        let entityTimesWed = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesWed = NSManagedObject(entity: entityTimesWed!, insertIntoManagedObjectContext: managedContext);
        let entityTimesThurs = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesThurs = NSManagedObject(entity: entityTimesThurs!, insertIntoManagedObjectContext: managedContext);
        let entityTimesFri = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesFri = NSManagedObject(entity: entityTimesFri!, insertIntoManagedObjectContext: managedContext);
        let entityTimesSat = NSEntityDescription.entityForName("Times", inManagedObjectContext: managedContext);
        let currentTimesSat = NSManagedObject(entity: entityTimesSat!, insertIntoManagedObjectContext: managedContext);

        currentLocation.setValue(currentID, forKey: "objectid");
        currentLocation.setValue(latitude, forKey: "latitude");
        currentLocation.setValue(longitude, forKey: "longitude");
        currentLocation.setValue(text, forKey: "text");
        
        currentTimesSun.setValue(0,forKey:"day");
        currentTimesMon.setValue(0,forKey:"day");
        currentTimesTues.setValue(0,forKey:"day");
        currentTimesWed.setValue(0,forKey:"day");
        currentTimesThurs.setValue(0,forKey:"day");
        currentTimesFri.setValue(0,forKey:"day");
        currentTimesSat.setValue(0,forKey:"day");
        let times = timesArray("t", withColon: false);
        for (index,time) in times.enumerate() { currentTimesSun.setValue(sundayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesMon.setValue(mondayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesTues.setValue(tuesdayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesWed.setValue(wednesdayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesThurs.setValue(thursdayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesFri.setValue(fridayBools[index], forKey: time);}
        for (index,time) in times.enumerate() { currentTimesSat.setValue(saturdayBools[index], forKey: time);}
        
        let timesSet = NSMutableSet();
        timesSet.addObject(currentTimesSun);
        timesSet.addObject(currentTimesMon);
        timesSet.addObject(currentTimesTues);
        timesSet.addObject(currentTimesWed);
        timesSet.addObject(currentTimesThurs);
        timesSet.addObject(currentTimesFri);
        timesSet.addObject(currentTimesSat);
        currentLocation.setValue(timesSet, forKey: "times");
        
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
        
        //dispatch_async(dispatch_get_main_queue()) {
            var counter = 0;
            var annotations = [MKAnnotation]();
            let times = timesArray("t", withColon: false);
            let (currentDay,currentHour,currentMinute) = currentTimeRounded();
            let currentTimeFieldname = "t"+String(currentHour)+String(currentMinute);
            for location in self.locations {
                counter++;
                let annotation = LawAnnotation();
                annotation.coordinate = CLLocationCoordinate2DMake(location.valueForKey("latitude") as! Double, location.valueForKey("longitude") as! Double);
                
                let times = location.valueForKey("times")!;
                //print ("times has "+String(times.count)+" entries.");
                annotation.title = location.valueForKey("latitude") as? String;
                //if (times.allObjects[currentDay].valueForKey(currentTimeFieldname) as! Bool == true) {
                annotation.setParkingAllowed(false);
                if (times.allObjects[0].valueForKey(currentTimeFieldname) as! Bool == true) {
                    annotation.title = "allowed: "+currentTimeFieldname;
                    annotation.setParkingAllowed(true);
                }
                else { annotation.title = "not allowed: "+currentTimeFieldname; }
                annotation.subtitle = String(location.valueForKey("text"));
                annotations.append(annotation);
                if annotations.count >= self.MAX_ANNOTATIONS {
                    break;
                }
            }
            self.mapView.addAnnotations(annotations);
            print("Done adding " + String(counter) + " annotations.");
        //}
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
    
    func currentTimeRounded() -> (day: Int, hour: String, minute: String){
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Weekday, .Hour, .Minute], fromDate: date)
        let hour = components.hour
        let minute = components.minute
        let day = components.weekday
        if (minute < 15) { return (day,addLeadingZero(String(hour)),"00");}
        else if (minute < 30) {return (day,addLeadingZero(String(hour)),"15");}
        else if (minute < 45) {return (day,addLeadingZero(String(hour)),"30");}
        else {return (day,addLeadingZero(String(hour)),"45");}

    }
    
    func addLeadingZero(number : String) -> String {
        if (number.characters.count == 1) {
            return "0"+number;
        }
        return number;
    }
    
    // If given "fri", returns ["fri00:00","fri00:15",...,"fri23:45"]
    func timesArray(day : String, withColon : Bool) -> Array<String> {
        let hours = ["00","01","02","03","04","05","06","07","08","09","10","11",
            "12","13","14","15","16","17","18","19","20","21","22","23"];
        let minutes = ["00","15","30","45"];
        var colon : String;
        if withColon {
            colon = ":";
        } else {
            colon = "";
        }
        var currentString = "";
        var resultArray = [String]();
        for hour in hours {
            for minute in minutes {
                currentString = day+hour+colon+minute;
                resultArray.append(currentString);
            }
        }
        return resultArray;
    }
    
    // given a day designation, and a json object
    // Go through the fields corresponding to all times in that day
    // Fill in boolean array as we go
    // Return array
    func boolsFromTimesInJson(day : String, jsonObject : JSON) -> Array<Bool> {
        var result = [Bool]();
        var currentBool = false;
        let times = timesArray(day, withColon : true);
        for time in times {
            currentBool = (jsonObject[time].string! == "T") ? true : false;
            result.append(currentBool);
            //if (!currentBool) { print("Found F aka false in boolsFromTimesInJson.") }
        }
        return result;
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        // simple and inefficient example
        
        let annotationView = MKAnnotationView()
        annotationView.canShowCallout = true;
        
        annotationView.image = UIImage(named: "reddot.png");
        
        if let currentAnnotation = annotation as? LawAnnotation {
            if currentAnnotation.isParkingAllowed() {
                annotationView.image = UIImage(named: "greendot.png");
            }
        }
        else {
            return nil
        }
        
        
        
        return annotationView
    }
}

