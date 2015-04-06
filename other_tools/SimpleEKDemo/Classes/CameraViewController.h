//
//  CameraViewController.h
//  SimpleEKDemo
//
//  Created by Rui Yang on 4/3/15.
//
//

#import <UIKit/UIKit.h>

@interface CameraViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView * cameraView;

- (IBAction)captureTapped:(UIButton *)sender;
@end
