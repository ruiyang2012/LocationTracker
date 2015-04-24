//
//  ChildQrController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/22/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "ChildQrController.h"
#import "MyCameraLib.h"

@interface ChildQrController () {
    MyCameraLib * camLib;
}
@property (weak, nonatomic) IBOutlet UIView *myQrContainer;

@end

@implementation ChildQrController

@synthesize delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"This is simulator mode....");
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTap:)];
    [self.myQrContainer addGestureRecognizer:singleFingerTap];
    
#else
    NSLog(@"This is device mode....");
    camLib = [[MyCameraLib alloc] init];
    [camLib setCameraScanMode:CAMERA_QR];
    MYCAMERACALLBACK block =  ^(UIImage* img, CAMERA_TYPE t, NSString* v) {
        NSLog(@"type is: %d -- %@", t, v);
        [self handleQrResult:v];
    };
    [camLib setup:self.myQrContainer done:block];
    [camLib scan];
#endif

}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    //CGPoint location = [recognizer locationInView:[recognizer.view superview]];
    [self handleQrResult:@"{\"code\" : \"parentId,childId\" }"];
    //Do stuff here...
}

- (void) handleQrResult:(NSString *) code {
    NSData *jsonData = [code dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&e];
    NSString * qrStr = [json objectForKey:@"code"];
    NSArray * myIds = [qrStr componentsSeparatedByString:@","];
    [[NSUserDefaults standardUserDefaults] setObject:myIds[0] forKey:@"parentId"];
    [[NSUserDefaults standardUserDefaults] setObject:myIds[1] forKey:@"childId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate onQrDone:myIds[1]];
    }];
    
    
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
