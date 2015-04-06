//
//  ProxCameraLib.m
//  ProxCameraLib
//
//  Created by rui yang on 3/14/14.
//  Copyright (c) 2014 Rui Yang. All rights reserved.
//

#import "ProxCameraLib.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>


static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;
static void * CapturingStillImageContext = &CapturingStillImageContext;

typedef NSUInteger UIBackgroundTaskIdentifier;
UIKIT_EXTERN const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid  NS_AVAILABLE_IOS(4_0);

@interface ProxCameraLib() <AVCaptureMetadataOutputObjectsDelegate, G8TesseractDelegate>

@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDevice *videoDevice;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic) AVCaptureMetadataOutput *captureMetadataOutput;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

  // Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@end

@implementation ProxCameraLib {
  CAMERA_SCAN_MODE _scanMode;
  AVCaptureTorchMode _torchMode;
  UIView * _preview;
  PROXCALLBACK _done;
  NSMutableArray* myImages;
  UIImageView * alignImage;
  UIImageView * previewImage;
  BOOL supportCamera;
  CGFloat effectiveScale;
  CGFloat beginGestureScale;
  NSString * rootPath;
  NSString * deviceId;
  CGPoint touchPoint;
  UIView *focusRect;

  G8Tesseract *tesseract;
    
}

- (id) init {
  self = [super init];
  supportCamera = ([[AVCaptureDevice devices] count] > 0);
  if (!supportCamera) {
    NSLog(@"no camera found");
    return self;
  }
  beginGestureScale = effectiveScale = 1.0f;
  _scanMode = CAMERA_PROX_QR;
  _torchMode = AVCaptureTorchModeOff;
  _preview = nil;
  myImages = [[NSMutableArray alloc] init];
  _done = ^(UIImage* img, CAMERA_TYPE t, NSString* code){
    NSLog(@"Empty Camera Callback!");
  };
	[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
		if (granted)
      {
        //Granted access to mediaType
			[self setDeviceAuthorized:YES];
      }
		else
      {
        //Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
                                    message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
      }
	}];
  rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  deviceId = [[[[UIDevice currentDevice] identifierForVendor] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
  return self;
}

- (void) setup:(UIView*)previewContainer done:(PROXCALLBACK)block {
  if (!supportCamera) return;
  _done = block;
  _preview = [[UIView alloc] initWithFrame:previewContainer.bounds];

  previewImage = [[UIImageView alloc] initWithFrame:previewContainer.bounds];
  previewImage.bounds = previewContainer.bounds;
  [previewImage setContentMode:UIViewContentModeScaleAspectFill];
  [previewImage setClipsToBounds:YES];
  [previewImage setHidden:YES];
  
  
  CGRect rect = CGRectMake(0, 0, previewContainer.bounds.size.width, 50);
  alignImage = [[UIImageView alloc] initWithFrame:rect];
  alignImage.clipsToBounds = YES;
  [alignImage setAlpha:0.7f];
  [alignImage setHidden:YES];

  [alignImage setContentMode:UIViewContentModeBottomLeft];
  [previewImage setContentMode:UIViewContentModeScaleAspectFit];
  [previewContainer addSubview:_preview];
  [previewContainer addSubview:alignImage];
  [previewContainer addSubview:previewImage];
  
  [self setSession:[[AVCaptureSession alloc] init]];
  self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
  self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

  self.previewLayer.frame = previewContainer.bounds;
  
  CALayer * rootLayer = [_preview layer];
  [rootLayer setMasksToBounds:YES];
  [rootLayer addSublayer:self.previewLayer];
  dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
  [self setSessionQueue:sessionQueue];
  
  UITapGestureRecognizer* tapScanner = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAtPoint:)];
  UIPinchGestureRecognizer * pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPin:)];
  
  [_preview addGestureRecognizer:pinchGesture];
  [_preview addGestureRecognizer:tapScanner];

  CGRect rect0 = CGRectMake(previewContainer.bounds.size.width / 2 - 50, previewContainer.bounds.size.height / 2 - 25, 100, 50);
  focusRect = [[UIView alloc] initWithFrame:rect0];
  focusRect.layer.borderColor = [UIColor orangeColor].CGColor;
  focusRect.layer.borderWidth = 1;
  focusRect.tag = 99;
  [_preview addSubview:focusRect];
    
  tesseract = [[G8Tesseract alloc] initWithLanguage:@"eng"];
  tesseract.delegate = self;
  tesseract.maximumRecognitionTime = 2.0;
    
  tesseract.charWhitelist = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
  
  dispatch_async(sessionQueue, ^{
    [self onSessionReady];
  });
  
}

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tr {
    NSLog(@"progress: %lu", (unsigned long)tr.progress);
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tr {
    return NO;  // return YES, if you need to interrupt tesseract before it finishes
}

- (void) cleanup {
  if (!supportCamera) return;
  [self stopScan];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
  [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
  
  
  [myImages removeAllObjects];
  [_preview removeFromSuperview];
  
  [alignImage removeFromSuperview];
  
  [previewImage removeFromSuperview];
  
  
  _preview = nil;
  previewImage = nil;
  alignImage = nil;
  _done = nil;
  _scanMode = CAMERA_QR;
  _torchMode = AVCaptureTorchModeOff;
}

- (void) undoLastPicture {
  if (!supportCamera) return;
  [myImages removeLastObject];
  [self asyncSetImgView:alignImage image:[myImages lastObject]];
  [self scan];
}

- (void) scan {
  if (!supportCamera) return;
    // if ([self.session isRunning]) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    [[(AVCaptureVideoPreviewLayer *)self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [previewImage setHidden:YES];
    [alignImage setHidden:NO];
  });
  [[self session] startRunning];
}

- (void) stopScan {
  if (!supportCamera) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    [previewImage setHidden:NO];
    [alignImage setHidden:YES];
  });
  [[self session] stopRunning];
}

- (CGRect) getOcrCropRegion:(UIImage *) image {
    CGSize sz = image.size;
    CGRect rect = CGRectMake((touchPoint.x - 50) * sz.width / self.previewLayer.bounds.size.width, (touchPoint.y - 25) * sz.height / self.previewLayer.bounds.size.height, 220, 100);
    return rect;
    
}

- (void) ocrCapture {
    if (!supportCamera || _scanMode != CAMERA_ONLY) return;
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        [stillImageConnection setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)self.previewLayer connection] videoOrientation]];
        [stillImageConnection setVideoScaleAndCropFactor:effectiveScale];
        
        // Capture a still image.
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            if (imageDataSampleBuffer) {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                UIImage * img = [self scaledCopyOfSize:image newSize:CGSizeMake(0, 0)];
                CGRect rect = [self getCropRegionForImage:img bounding:self.previewLayer.bounds];
                UIImage * result = [self cropImage:img cropRegion:rect];
                CGRect ocrRect = [self getOcrCropRegion:img];
                UIImage * ocrImg = [self convertImageToGrayScale:[self cropImage:img cropRegion:ocrRect]];
                //UIImageWriteToSavedPhotosAlbum(ocrImg, nil, nil, nil);
                [self stopScan];
                tesseract.image = ocrImg;
                [tesseract recognize];
                [self invokeCallbackAsync:result type:OCRTAKE result:tesseract.recognizedText];

            }
        }];
    });
    
}

- (void) take:(BOOL) saveCopyInGallery {
  if (_scanMode == SCAN_ONLY) return;
  if (!supportCamera) return;
	dispatch_async([self sessionQueue], ^{
      // Update the orientation on the still image output video connection before capturing.
      AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
      [stillImageConnection setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)self.previewLayer connection] videoOrientation]];
      [stillImageConnection setVideoScaleAndCropFactor:effectiveScale];
    
        // Capture a still image.
      [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
          if (imageDataSampleBuffer) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            UIImage * img = [self scaledCopyOfSize:image newSize:CGSizeMake(0, 0)];
            CGRect rect = [self getCropRegionForImage:img bounding:self.previewLayer.bounds];
            UIImage * result = [self cropImage:img cropRegion:rect];
            [self stopScan];
            [self addImg:result];
            [self invokeCallbackAsync:result type:TAKE result:nil];
            if (saveCopyInGallery) UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil);
          }
		}];
	});
}

- (void) addImg:(UIImage*) newImg {
  UIImage * img = [newImg copy];
  [myImages addObject:img];
  [self asyncSetImgView:previewImage image:img];
  
  CGFloat w = previewImage.bounds.size.width ;
  CGFloat h = previewImage.bounds.size.height ;
  CGSize alignSize = CGSizeMake(w, h);
  UIImage * alignImg = [self scaledCopyOfSize:img newSize:alignSize];
  [self asyncSetImgView:alignImage image:alignImg];
}

- (void) donePhoto:(BOOL) saveCopyInGallery {
  if (!supportCamera) return;
  if (_scanMode == SCAN_ONLY) {
    NSLog(@"scan only mode, will not take picture.");
    return;
  }
  if (_done == nil) {
    NSLog(@"no call back is defined!");
    return;
  }
    // merge images in the self.myImages.
  if ([myImages count] == 0) {
    NSLog(@"image count is 0");
    return;
  }
  UIImage* r = nil;
  
  if ([myImages count] == 1) {
    r = [myImages firstObject];
  } else {
    CGSize imgSize =[[myImages firstObject] size];
    int offset = (imgSize.height <= 50) ? 0 : 50;
    int totalHeight = (imgSize.height - offset) * [myImages count] + offset;
    CGSize size = CGSizeMake(imgSize.width, totalHeight);
    UIGraphicsBeginImageContext(size);
    for (NSUInteger i = 0; i < [myImages count]; i++) {
      UIImage * img = [myImages objectAtIndex:i];
      long h = i * imgSize.height;
      CGPoint p = CGPointMake(0, (h <= offset) ? h : h - offset);
      [img drawAtPoint:p];
    }
    r = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }
  NSInteger uid = [[NSUserDefaults standardUserDefaults] integerForKey:@"currentLincUser"];
  NSInteger linc2UserId = [[NSUserDefaults standardUserDefaults] integerForKey:@"LincUserID"];
  if (uid ==0) uid = linc2UserId;
  NSString * rid = [NSString stringWithFormat:@"%ld-Linc_%@_%02x", (long)uid, deviceId, arc4random()];
  NSString * imgFile = [[rootPath stringByAppendingPathComponent:rid] stringByAppendingString:@".jpg"];
  [UIImageJPEGRepresentation(r, 1.0) writeToFile:imgFile atomically:YES];
  [self reset];
  [self invokeCallbackAsync:r type:DONETAKE result:rid];
  
  if (saveCopyInGallery) UIImageWriteToSavedPhotosAlbum(r, nil, nil, nil);
  r = nil;
}

- (void) reset {
  [myImages removeAllObjects];
}

- (void) setCameraScanMode:(CAMERA_SCAN_MODE) mode {
  _scanMode = mode;
  if (!supportCamera) return;
  [self updateCaptureMetadata];
}

- (void) setTorchMode:(AVCaptureTorchMode) mode {
  _torchMode = mode;
  
  NSError * error = nil;
  if ([self.videoDevice hasTorch] && [self.videoDevice isTorchModeSupported:mode]) {
    if ([self.videoDevice lockForConfiguration:&error]) {
      [self.videoDevice setTorchMode:mode];
      [self.videoDevice unlockForConfiguration];
    } else {
      NSLog(@"%@", error);
    }
  }
}

- (void) setFlasMode:(AVCaptureFlashMode) mode {
  NSError * error = nil;
  if ([self.videoDevice hasFlash] && [self.videoDevice isFlashModeSupported:mode]) {
    if ([self.videoDevice lockForConfiguration:&error]) {
      [self.videoDevice setFlashMode:mode];
      [self.videoDevice unlockForConfiguration];
    } else {
      NSLog(@"%@", error);
    }
  }
}

- (BOOL) supportTorch {
  return [self.videoDevice hasTorch];
}

  // private func
+ (AVCaptureDevice *)device
{
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  AVCaptureDevice *captureDevice = [devices firstObject];

  for (AVCaptureDevice *device in devices)
  {
    if ([device position] == AVCaptureDevicePositionBack)
    {
      captureDevice = device;
      break;
    }
  }

  return captureDevice;
}
    
+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
	return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == CapturingStillImageContext) {
    
  } else if (context == SessionRunningAndDeviceAuthorizedContext) {
    
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}
    
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode
    atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
  dispatch_async([self sessionQueue], ^{
    AVCaptureDevice *device = [[self videoDeviceInput] device];
    
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
      if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]) {
        [device setFocusMode:focusMode];
        [device setFocusPointOfInterest:point];
      }
      if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]) {
        [device setExposureMode:exposureMode];
        [device setExposurePointOfInterest:point];
      }
      [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
      [device unlockForConfiguration];
    } else {
      NSLog(@"%@", error);
    }
  });
}

- (void)subjectAreaDidChange:(NSNotification *)notification {
  CGPoint devicePoint = CGPointMake(.5, .5);
  [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}
    

- (BOOL)isSessionRunningAndDeviceAuthorized
{
	return [[self session] isRunning] && [self isDeviceAuthorized];
}

- (void) postActive {
	dispatch_async([self sessionQueue], ^{
		[self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		
    AVCaptureSession * session = self.session;
    dispatch_queue_t sessionQueue = self.sessionQueue;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:session queue:nil usingBlock:^(NSNotification *note) {
			dispatch_async(sessionQueue, ^{ [self scan];	});
		}]];
    
	});
  
}

- (void) onSessionReady {
  [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
  
  NSError *error = nil;
  
  [self setVideoDevice:[ProxCameraLib device]];
  AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];

  if (error) {
    NSLog(@"%@", error);
    return;
  }
  [self setFlasMode:AVCaptureFlashModeAuto];
  if ([self.session canAddInput:videoDeviceInput]) {
    [self.session addInput:videoDeviceInput];
    [self setVideoDeviceInput:videoDeviceInput];
  }
  
  if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
    [self.session setSessionPreset:AVCaptureSessionPreset1280x720];
  } else if ([self.session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
    [self.session setSessionPreset:AVCaptureSessionPresetMedium];
  }
  
  self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
  NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
  [self.stillImageOutput setOutputSettings:outputSettings];
  if ([self.session canAddOutput:self.stillImageOutput]) {
    [self.stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
    [self.session addOutput:self.stillImageOutput];
  }
  
  self.captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
  if ([self.session canAddOutput:self.captureMetadataOutput]) {
    [self.session addOutput:self.captureMetadataOutput];
  }
  [self.captureMetadataOutput setMetadataObjectsDelegate:self queue:self.sessionQueue];
  [self updateCaptureMetadata];
  
  [self performSelector:@selector(postActive) withObject:nil afterDelay:0.1];
}

- (UIImage *)scaledCopyOfSize:(UIImage*) img newSize:(CGSize) newSize{
  if (img == nil) return nil;
  NSLog(@"scale down image from camera");
  
  CGImageRef imgRef = img.CGImage;
  
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  if (newSize.height == 0) newSize.height = height;
  if (newSize.width ==0) newSize.width = width;
  
  CGAffineTransform transform = CGAffineTransformIdentity;
  CGRect bounds = CGRectMake(0, 0, width, height);
  if (width > newSize.width || height > newSize.height) {
    CGFloat ratio = width/height;
    if (ratio > 1) {
      bounds.size.width = newSize.width;
      bounds.size.height = floor(bounds.size.width / ratio);
    }
    else {
      bounds.size.height = newSize.height;
      bounds.size.width = floor(bounds.size.height * ratio);
    }
  }
  
  CGFloat scaleRatio = bounds.size.width / width;
  CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
  CGFloat boundHeight;
  UIImageOrientation orient = img.imageOrientation;
  switch(orient) {
      
    case UIImageOrientationUp: //EXIF = 1
      transform = CGAffineTransformIdentity;
      break;
      
    case UIImageOrientationUpMirrored: //EXIF = 2
      transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
      transform = CGAffineTransformScale(transform, -1.0, 1.0);
      break;
      
    case UIImageOrientationDown: //EXIF = 3
      transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
      transform = CGAffineTransformRotate(transform, M_PI);
      break;
      
    case UIImageOrientationDownMirrored: //EXIF = 4
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
      transform = CGAffineTransformScale(transform, 1.0, -1.0);
      break;
      
    case UIImageOrientationLeftMirrored: //EXIF = 5
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
      transform = CGAffineTransformScale(transform, -1.0, 1.0);
      transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
      break;
      
    case UIImageOrientationLeft: //EXIF = 6
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
      transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
      break;
      
    case UIImageOrientationRightMirrored: //EXIF = 7
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeScale(-1.0, 1.0);
      transform = CGAffineTransformRotate(transform, M_PI / 2.0);
      break;
      
    case UIImageOrientationRight: //EXIF = 8
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
      transform = CGAffineTransformRotate(transform, M_PI / 2.0);
      break;
      
    default:
      [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
      
  }
  
  UIGraphicsBeginImageContext(bounds.size);
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
    CGContextScaleCTM(context, -scaleRatio, scaleRatio);
    CGContextTranslateCTM(context, -height, 0);
  }
  else {
    CGContextScaleCTM(context, scaleRatio, -scaleRatio);
    CGContextTranslateCTM(context, 0, -height);
  }
  
  CGContextConcatCTM(context, transform);
  
  CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
  UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return imageCopy;
}

- (CGRect) getCropRegionForImage:(UIImage*) img bounding:(CGRect) bounds {
  CGSize sz = img.size;
  CGFloat scale = [[UIScreen mainScreen] scale];
  
  CGFloat previewW = CGRectGetWidth(bounds) * scale;
  CGFloat previewH = CGRectGetHeight(bounds) * scale;

  CGFloat factor = previewW / sz.width;
  if (previewH > factor * sz.height) {
    factor = previewH / sz.height;
  }
  CGFloat newW = MIN(sz.width, previewW / factor);
  CGFloat newH = MIN(sz.height, previewH / factor);
  
  CGFloat x = MAX(0, (sz.width - newW) / 2);
  CGFloat y = MAX(0, (sz.height - newH) / 2);
  return CGRectMake(x, y, newW, newH);
}

- (UIImage*) cropImage:(UIImage*) img cropRegion:(CGRect) cropRect {
  if (img == nil) return nil;
  UIImage * resultImg = nil;
  CGImageRef imageRef = CGImageCreateWithImageInRect([img CGImage], cropRect);
  resultImg = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  return resultImg;
}

- (NSString *) getJsonFromQRResult:(NSString*) text {
  if (text == nil) return nil;
  NSURL* url = [NSURL URLWithString:text];
  if (url == nil || ![[url host] hasSuffix:@"proximiant.com"]) return nil;
  NSString* query = [url query];
  if (!query) return nil;
  NSMutableDictionary *dict =  [[NSMutableDictionary alloc]init];
  NSArray *pairs = [query componentsSeparatedByString:@"&"];
  for (NSString *pair in pairs)
    {
    NSArray *elements = [pair componentsSeparatedByString:@"="];
    NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [dict setObject:val forKey:key];
    }
  
  NSString* rid = [dict objectForKey:@"rid"];
  if (rid == nil) { return nil; }
  
    // get SID
  NSArray *parts = [rid componentsSeparatedByString: @"-"];
  if ([parts count])
    {
    NSString* sidString = [parts objectAtIndex:0];
    [dict setObject:[NSNumber numberWithLongLong:[sidString longLongValue]] forKey:@"sid"];
    }
  NSData * result = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:nil];
  
  return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
  
}

- (void) asyncSetImgView:(UIImageView*) imgV image:(UIImage*) img {
  dispatch_async(dispatch_get_main_queue(), ^{
    [imgV setImage:img];
  });
}

- (void) invokeCallbackAsync:(UIImage*)img type:(CAMERA_TYPE) t result:(NSString*) r {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (_done) { _done(img, t, r); }
  });
  
}

- (void)onPin:(UIPinchGestureRecognizer *)gestureRecognizer {
  if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
    beginGestureScale = effectiveScale;
  } else {
    effectiveScale = beginGestureScale * gestureRecognizer.scale;
    if (effectiveScale < 1.0) effectiveScale = 1.0f;
    CGFloat maxScale = [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
    if (effectiveScale > maxScale) effectiveScale = maxScale;
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(effectiveScale, effectiveScale)];
    [CATransaction commit];
  }
}

- (void)focusAtPoint:(id) sender{
  touchPoint = [(UITapGestureRecognizer*)sender locationInView:_preview];
  double focus_x = touchPoint.x/self.previewLayer.frame.size.width;
  double focus_y = (touchPoint.y+66)/self.previewLayer.frame.size.height;
  NSError *error;
  
  AVCaptureDevice *device = [self videoDevice];
  NSLog(@"Device name: %@", [device localizedName]);
  if ([device hasMediaType:AVMediaTypeVideo] && [device position] == AVCaptureDevicePositionBack) {
    NSLog(@"Device position : back");
    CGPoint point = CGPointMake(focus_y, 1-focus_x);
    if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [device lockForConfiguration:&error]){
      [device setFocusPointOfInterest:point];
      CGRect rect = CGRectMake(touchPoint.x-50, touchPoint.y-25, 100, 50);
        [focusRect setFrame:rect];
      
//      UIView *focusRect = [[UIView alloc] initWithFrame:rect];
//      focusRect.layer.borderColor = [UIColor orangeColor].CGColor;
//      focusRect.layer.borderWidth = 1;
//      focusRect.tag = 99;
//      [_preview addSubview:focusRect];
//      [NSTimer scheduledTimerWithTimeInterval: 1
//                                       target: self
//                                     selector: @selector(dismissFocusRect)
//                                     userInfo: nil
//                                      repeats: NO];
      [device setFocusMode:AVCaptureFocusModeAutoFocus];
      [device unlockForConfiguration];
    }
  }
  
  
}

- (void) dismissFocusRect {
  for (UIView *subView in [_preview subviews]) {
    if (subView.tag == 99) { [subView removeFromSuperview]; }
  }
}

- (void) updateCaptureMetadata {
  if (!self.captureMetadataOutput) return;
  switch (_scanMode) {
    case CAMERA_QR:
    case CAMERA_PROX_QR:
      [self.captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects: AVMetadataObjectTypeQRCode, nil]];
      break;
    case SCAN_ONLY:
    case CAMERA_SCAN:
      [self.captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects: AVMetadataObjectTypeAztecCode,
            AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
            AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code,
            AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeUPCECode, nil]];
      break;
    case SCAN_FACE:
      [self.captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects: AVMetadataObjectTypeFace, nil]];
    default:
      [self.captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObjects: nil]];
      break;
  }
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
  if (_scanMode == CAMERA_ONLY || metadataObjects == nil || [metadataObjects count] == 0) return;
  AVMetadataMachineReadableCodeObject *readableObject = nil;
  NSString * proxJson = nil;
  for(AVMetadataObject *metadataObject in metadataObjects) {
    if([metadataObject.type isEqualToString:AVMetadataObjectTypeQRCode]) {
      if (_scanMode == CAMERA_QR) {
        readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
        break;
      } else if (_scanMode == CAMERA_PROX_QR) {
        readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
        proxJson = [self getJsonFromQRResult:readableObject.stringValue];
        if (proxJson) break;
      }
    } else {
      if (_scanMode != CAMERA_QR && _scanMode != CAMERA_PROX_QR) {
        readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
        break;
      }
    }
  }
  if (readableObject) {
    AudioServicesPlaySystemSound(1003);
    NSString * code = [readableObject.stringValue stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    NSString * result = [NSString stringWithFormat:@"{\"code\":\"%@\",\"type\":\"%@\"}",code, readableObject.type];
    if (proxJson && CAMERA_PROX_QR == _scanMode) result = proxJson;

    [self invokeCallbackAsync:nil type:SCAN result:result];
    [self stopScan];
  }
  
}

- (UIImage *)convertImageToGrayScale:(UIImage *)image {
    
    
    // Create image rectangle with current image width/height
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    // Grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // Create bitmap content with current image size and grayscale colorspace
    CGContextRef context = CGBitmapContextCreate(nil, image.size.width, image.size.height, 8, 0, colorSpace, kCGImageAlphaNone);
    
    // Draw image into current context, with specified rectangle
    // using previously defined context (with grayscale colorspace)
    CGContextDrawImage(context, imageRect, [image CGImage]);
    
    // Create bitmap image info from pixel data in current context
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    // Create a new UIImage object
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    
    // Release colorspace, context and bitmap information
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CFRelease(imageRef);
    
    // Return the new grayscale image
    return newImage;
}

@end
