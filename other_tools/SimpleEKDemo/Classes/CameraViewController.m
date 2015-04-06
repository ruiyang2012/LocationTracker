//
//  CameraViewController.m
//  SimpleEKDemo
//
//  Created by Rui Yang on 4/3/15.
//
//

#import "CameraViewController.h"
#import "ProxCameraLib.h"

@interface CameraViewController () {
    ProxCameraLib * camLib;
}

@end

@implementation CameraViewController

@synthesize cameraView;

- (void)viewDidLoad {
    [super viewDidLoad];

    UIButton * btn = nil;
    for (UIView* subView in cameraView.subviews) {
        if ([subView isKindOfClass:[UIButton class]]) {
            btn = (UIButton *) subView;
        }
    }
    // Do any additional setup after loading the view.
    camLib = [[ProxCameraLib alloc] init];
    [camLib setCameraScanMode:CAMERA_ONLY];
    PROXCALLBACK block =  ^(UIImage* img, CAMERA_TYPE t, NSString* v) {
        NSLog(@"type is: %d -- %@", t, v);
        if (!v) v = @"";
        NSDictionary * dict = @{ @"txt" : v, @"img" : img };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ocrRecognized" object:dict];
        
    };
    [camLib setup:cameraView done:block];
    if (btn) {
        [cameraView bringSubviewToFront:btn];
    }
    [camLib scan];
    
   
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)captureTapped:(UIButton *)sender {
    [camLib ocrCapture];
    [self dismissViewControllerAnimated:YES completion:nil];
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
