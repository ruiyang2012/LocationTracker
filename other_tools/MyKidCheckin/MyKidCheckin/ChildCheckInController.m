//
//  ChildCheckInController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/22/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "ChildCheckInController.h"

@interface ChildCheckInController ()

@property (weak, nonatomic) IBOutlet UILabel *myCurrentLocation;
@end

@implementation ChildCheckInController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onCheckIn:(id)sender {
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
