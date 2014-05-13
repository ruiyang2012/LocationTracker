//
//  ProxViewController.h
//  LocationTracker
//
//  Created by rui yang on 5/11/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface ProxViewController : UIViewController <MKMapViewDelegate>

@property (nonatomic, strong) IBOutlet MKMapView *mapView;

@end
