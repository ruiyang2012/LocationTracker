//
//  MyMapController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/16/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyMapController.h"


@interface MyMapController ()
@property (weak, nonatomic) IBOutlet MKMapView *myMapView;
@property (weak, nonatomic) IBOutlet UILabel *myLabel;

@end

@implementation MyMapController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (self.childLoc.latitude != 0 && self.childLoc.longitude != 0) {
        MKPointAnnotation *myAnnotation = [[MKPointAnnotation alloc] init];
        myAnnotation.coordinate = self.childLoc;
        myAnnotation.title = self.childName;
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(self.childLoc, 500, 500);
        MKCoordinateRegion adjustedRegion = [self.myMapView regionThatFits:viewRegion];
        [self.myMapView setRegion:adjustedRegion animated:YES];
        self.myMapView.showsUserLocation = YES;
        [self.myMapView addAnnotation:myAnnotation];
        [self.myMapView setCenterCoordinate:self.childLoc animated:YES];
    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
