//
//  MyKidViewDetailController.h
//  MyKidCheckin
//
//  Created by Rui Yang on 4/10/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import <UIKit/UIKit.h>


@class MyKidViewDetailController;
@protocol MyKidViewDetailControllerDelegate

-(void) onChild:(NSDictionary *)childInfo;

@end

@interface MyKidViewDetailController : UIViewController
@property (strong, nonatomic) NSString * parentId;
@property (strong, nonatomic) NSString * childId;
@property (strong, nonatomic) NSString * childName;
@property (assign) BOOL allowEdit;
@property (nonatomic, assign) id  delegate;
@property (weak, nonatomic) IBOutlet UITextField *myText;
@end
