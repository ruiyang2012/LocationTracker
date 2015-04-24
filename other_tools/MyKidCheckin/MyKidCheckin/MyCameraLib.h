//
//  ProxCameraLib.h
//  ProxCameraLib
//
//  Created by rui yang on 3/14/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


typedef enum {
  SCAN, TAKE, DONETAKE
} CAMERA_TYPE;


typedef enum {
  CAMERA_ONLY, CAMERA_QR, CAMERA_SCAN, SCAN_ONLY, SCAN_FACE, CAMERA_PROX_QR,
} CAMERA_SCAN_MODE;

typedef void (^MYCAMERACALLBACK)(UIImage*, CAMERA_TYPE, NSString*);

@interface MyCameraLib : NSObject

- (void) setup:(UIView*)previewContainer done:(MYCAMERACALLBACK)block;

- (void) addImg:(UIImage*) newImg;

- (void) cleanup;

- (void) undoLastPicture;

- (void) scan;

- (void) stopScan;

- (void) take:(BOOL) saveCopyInGallery;

- (void) donePhoto:(BOOL) saveCopyInGallery;

- (void) reset;

- (void) setCameraScanMode:(CAMERA_SCAN_MODE) mode;

- (void) setTorchMode:(AVCaptureTorchMode) mode;

- (void) setFlasMode:(AVCaptureFlashMode) mode;

- (BOOL) supportTorch;


@end
