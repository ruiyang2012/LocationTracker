//
//  ProxUtils.h
//  clientApiLib
//
//  Created by rui yang on 11/27/13.
//  Copyright (c) 2013 rui yang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface ProxUtils : NSObject
+ (BOOL) isEmptyString:(NSString*)v;
+ (NSString*) getJsonStrFromJsonObj:(NSDictionary *) dict;
+ (NSMutableDictionary*) getJsonObjFromJsonStr:(NSString*) json;
+ (NSString*) getGUID;
+ (NSString *) genRid:(long) userID;
+ (NSString*) generateRandomString;
+ (NSString*) decodeB64String: (NSString*) b64String;
+ (NSString*) b64EncodeString: (NSString*) text;

+ (NSData*) decodeB64Data: (NSString*) b64String;
+ (NSString*) b64EncodeData: (NSData*) data;

+ (NSString*) b64EncodeImage: (UIImage*) image;

+ (UIImage *)generatePhotoThumbnail:(UIImage *)image size:(int) thumbSize;

+ (UIImage *)scaledCopyOfSizeForUIImage:(UIImage*) img newSize:(CGSize) newSize;

+ (NSDate*) getToday;
+ (NSDate*) getYesterday;
+ (NSDate*) getDaysFromToday:(int) days;
+ (NSDate*) getFirstDateOfMonthForDate:(NSDate*) date;
+ (NSDate*) getLastDateOfMonthForDate:(NSDate*) date;
+ (NSUInteger) getNumberOfDaysForMonth:(NSDate*) date;

+ (NSInteger) daysBetween:(NSDate*) from to:(NSDate *) to;

+ (NSString*)sha1:(NSString*)input;

+ (NSString *) getDocumentRootPath;

+ (NSDictionary *)queryStringToDictionary:(NSString *)queryString;
+ (NSString *)dictionaryToQueryString:(NSDictionary *)dictionary;

+ (NSData*) readBinary:(NSString*) fileName;
+ (NSString*) readText:(NSString*) fileName;

+ (void) writeText:(NSString*) fileName content:(NSString*) value;
+ (void) writeBinary:(NSString *) fileName content:(NSData*) value;

@end
