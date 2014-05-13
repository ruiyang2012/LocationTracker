//
//  ProxUtils.m
//  clientApiLib
//
//  Created by rui yang on 11/27/13.
//  Copyright (c) 2013 rui yang. All rights reserved.
//

#import "ProxUtils.h"
#import "NSData+Base64.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString* baseGuid = nil;

@implementation ProxUtils

+ (BOOL) isEmptyString:(NSString*)v {
  return (v == nil || v == NULL || [v isEqual:NSNull.null]  || [v length] == 0);
}


+ (NSString*) getJsonStrFromJsonObj:(NSDictionary *) dict {
  NSData * data =  [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSMutableDictionary*) getJsonObjFromJsonStr:(NSString*) json {
  if ([self isEmptyString:json]) {
    return [[NSMutableDictionary alloc] init];
  }
  return [NSJSONSerialization JSONObjectWithData: [json dataUsingEncoding:NSUTF8StringEncoding]
                                         options: NSJSONReadingMutableContainers
                                           error: nil];
 
}

+ (NSString*) getGUID {
  return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

+ (NSString*) generateRandomString {
  if (baseGuid == nil) {
    baseGuid = [ProxUtils getGUID];
  }
  return [[NSString stringWithFormat:@"PROX_RAND_%@_%02x", baseGuid, arc4random()] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

+ (NSString*) decodeB64String: (NSString*) b64String {
  NSData * result = [self decodeB64Data:b64String];
  if (result == nil) { return @""; }
  
  NSString *convertedString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
  return convertedString;
}

+ (NSString*) b64EncodeString: (NSString*) text {
  if (text == nil) { return @""; }
  NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
  return [self b64EncodeData:data];
}

+ (NSData*) decodeB64Data: (NSString*) b64String {
  if (b64String == nil) { return nil; }
	NSData *data = [b64String dataUsingEncoding:NSASCIIStringEncoding];
	size_t outputLength;
	void *outputBuffer = NewBase64Decode([data bytes], [data length], &outputLength);
	NSData *result = [NSData dataWithBytes:outputBuffer length:outputLength];
	free(outputBuffer);
  return result;
}

+ (NSString*) b64EncodeData: (NSData*) data {
	size_t outputLength = 0;
	char *outputBuffer =
  NewBase64Encode([data bytes], [data length], NO, &outputLength);
	
	NSString *result =
  [[NSString alloc]
   initWithBytes:outputBuffer
   length:outputLength
   encoding:NSASCIIStringEncoding];
	free(outputBuffer);
	return result;
}

+ (NSString*) b64EncodeImage: (UIImage*) image {
  NSData * d = UIImageJPEGRepresentation(image, 0.9f);
  NSString * b64 = [self b64EncodeData:d];
  return b64;
}


+ (UIImage *)generatePhotoThumbnail:(UIImage *)image size:(int) thumbSize{
    // Create a thumbnail version of the image for the event object.
	CGFloat ratio = MAX(10, MIN(thumbSize, 160));
  return [ProxUtils scaledCopyOfSizeForUIImage:image newSize:CGSizeMake(ratio, ratio)];

}

+ (UIImage *)scaledCopyOfSizeForUIImage:(UIImage*) img newSize:(CGSize) newSize{
  if (img == nil) return nil;
  
  CGImageRef imgRef = img.CGImage;
  
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
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

+ (NSDate*) getToday {
  return [ProxUtils getDaysFromToday:0];
}

+ (NSDate*) getYesterday {
  return [ProxUtils getDaysFromToday:1];
}

+ (NSUInteger) getNumberOfDaysForMonth:(NSDate*) date {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSRange daysRange =  [cal rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:date];
  return daysRange.length;
}

+ (NSDate*) getFirstDateOfMonthForDate:(NSDate*) date {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *components = [cal components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit )
                                        fromDate:date];
  [components setDay:1];
  return [[NSCalendar currentCalendar] dateFromComponents: components];
}

+ (NSDate*) getLastDateOfMonthForDate:(NSDate*) date {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *components = [cal components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit )
                                        fromDate:date];
  [components setDay:[self getNumberOfDaysForMonth:date]];
  return [[NSCalendar currentCalendar] dateFromComponents: components];
}

+ (NSDate*) getDaysFromToday:(int) days{
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *components = [cal components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit )
                                        fromDate:[[NSDate alloc] init]];
  
  [components setHour:-[components hour] - 24 * days];
  [components setMinute:-[components minute]];
  [components setSecond:-[components second]];
  return [cal dateByAddingComponents:components toDate:[[NSDate alloc] init] options:0];
}

+ (NSInteger) daysBetween:(NSDate*) from to:(NSDate *) to {
  NSDate *fromDate;
  NSDate *toDate;
  
  NSCalendar *calendar = [NSCalendar currentCalendar];
  
  [calendar rangeOfUnit:NSDayCalendarUnit
              startDate:&fromDate
               interval:NULL
                forDate:from];
  [calendar rangeOfUnit:NSDayCalendarUnit
              startDate:&toDate
               interval:NULL
                forDate:to];
  
  NSDateComponents *difference = [calendar components:NSDayCalendarUnit
                                             fromDate:fromDate
                                               toDate:toDate
                                              options:0];
  return [difference day];
}

+ (NSString*)sha1:(NSString*)input
{
  NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  CC_SHA1(data.bytes, (unsigned int)data.length, digest);
  
  NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
  for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
    [output appendFormat:@"%02x", digest[i]];
  }
  
  return output;
}

@end
