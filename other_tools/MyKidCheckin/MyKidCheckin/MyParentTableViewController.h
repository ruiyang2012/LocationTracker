//
//  MyParentTableViewController.h
//  MyKidCheckin
//
//  Created by Rui Yang on 4/9/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MyParentTableViewController;
@protocol MyParentTableViewControllerDelegate
- (void) onReset;
@end

@interface MyParentTableViewController : UITableViewController

@property (nonatomic, assign) id  delegate;

@end


