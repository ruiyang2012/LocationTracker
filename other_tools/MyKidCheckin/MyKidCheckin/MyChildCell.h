//
//  MyChildCell.h
//  MyKidCheckin
//
//  Created by Rui Yang on 4/10/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MyChildCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *myName;

@property (strong, nonatomic) NSString * childId;
@property (strong, nonatomic) NSString * parentId;
@end
