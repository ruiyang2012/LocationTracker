//
//  MyKidViewDetailController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/10/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyKidViewDetailController.h"

@interface MyKidViewDetailController ()

@property (weak, nonatomic) IBOutlet UIImageView *myQRCode;

@end

@implementation MyKidViewDetailController

@synthesize delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.myText.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSArray * qrInfo =@[self.parentId, self.childId];
    NSString * qrStr = [qrInfo componentsJoinedByString:@","];
    NSData * qrData =[qrStr dataUsingEncoding:NSISOLatin1StringEncoding];
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [qrFilter setValue:qrData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    [self.myQRCode setImage:[UIImage imageWithCIImage:qrFilter.outputImage]];
    if (self.allowEdit) {
        UIBarButtonItem * doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(onDone:)];
        self.navigationItem.rightBarButtonItem = doneBtn;
    } else {
        self.myText.enabled = NO;
    }

}

- (IBAction) onDone:(id)sender {
    NSString * kidName =[self.myText.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([kidName length] == 0) {
        return;
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    [delegate onChild:@{ @"id" : self.childId, @"name" : self.myText.text }];

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
