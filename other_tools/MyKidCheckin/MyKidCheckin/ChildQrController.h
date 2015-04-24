//
//  ChildQrController.h
//  MyKidCheckin
//
//  Created by Rui Yang on 4/22/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChildQrController;
@protocol ChildQrControllerDelegate

-(void) onQrDone:(NSString *)childId;

@end

@interface ChildQrController : UIViewController
@property (nonatomic, assign) id  delegate;
@end
