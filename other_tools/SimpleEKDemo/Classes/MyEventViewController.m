//
//  MyEventViewController.m
//  SimpleEKDemo
//
//  Created by Rui Yang on 4/3/15.
//
//

#import "MyEventViewController.h"

@interface MyEventViewController () {
    UIImageView * _imgView;
}

@end

@implementation MyEventViewController

- (void) setImage:(UIImage *) img {
    if (!_imgView) {
        CGFloat w = [UIScreen mainScreen].bounds.size.width;
        CGFloat h = [UIScreen mainScreen].bounds.size.height;
        CGRect fr = CGRectMake(0, h / 3, w, h / 2);
        _imgView = [[UIImageView alloc] initWithFrame:fr];
        //_imgView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;

        [self.view addSubview:_imgView];
    }
    
    [_imgView setImage:img];
    [self.view bringSubviewToFront:_imgView];
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
