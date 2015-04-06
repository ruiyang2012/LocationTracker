//
//  ProxCameraLib.h
//  ProxCameraLib
//
//  Created by rui yang on 3/14/14.
//  Copyright (c) 2014 Rui Yang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TesseractOCR.h"

typedef enum {
  SCAN, TAKE, DONETAKE, OCRTAKE
} CAMERA_TYPE;


typedef enum {
  CAMERA_ONLY, CAMERA_QR, CAMERA_SCAN, SCAN_ONLY, SCAN_FACE, CAMERA_PROX_QR,
} CAMERA_SCAN_MODE;

typedef void (^PROXCALLBACK)(UIImage*, CAMERA_TYPE, NSString*);

@interface ProxCameraLib : NSObject

- (void) setup:(UIView*)previewContainer done:(PROXCALLBACK)block;

- (void) addImg:(UIImage*) newImg;

- (void) cleanup;

- (void) undoLastPicture;

- (void) scan;

- (void) stopScan;

- (void) ocrCapture;

- (void) take:(BOOL) saveCopyInGallery;

- (void) donePhoto:(BOOL) saveCopyInGallery;

- (void) reset;

- (void) setCameraScanMode:(CAMERA_SCAN_MODE) mode;

- (void) setTorchMode:(AVCaptureTorchMode) mode;

- (void) setFlasMode:(AVCaptureFlashMode) mode;

- (BOOL) supportTorch;

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tr;
- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tr;

@end
