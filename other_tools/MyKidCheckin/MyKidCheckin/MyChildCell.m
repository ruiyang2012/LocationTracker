//
//  MyChildCell.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/10/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyChildCell.h"

@implementation MyChildCell

- (void)awakeFromNib {
    // Initialization code
    self.contentView.userInteractionEnabled = NO;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    self.contentView.userInteractionEnabled = NO;
    // Configure the view for the selected state
}
- (IBAction)onQrClicked:(id)sender {
    NSLog(@"onQrCode Clicked");
}

@end
