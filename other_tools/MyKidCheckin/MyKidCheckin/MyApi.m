//
//  MyApi.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/28/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyApi.h"
#import <MapKit/MapKit.h>

@implementation MyApi

+ (void) api:(NSString *) path param:(NSDictionary *) request {
    NSString * rootPath = [NSString stringWithFormat:@"https://secure-refuge-4882.herokuapp.com/%@?", path];

    NSMutableArray *parts = [NSMutableArray array];
    for (id key in request) {
        id value = [request objectForKey: key];
        NSString * k = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString * v = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *part = [NSString stringWithFormat: @"%@=%@", k, v];
        [parts addObject: part];
    }
    NSString * reqStr = [parts componentsJoinedByString: @"&"];
    NSString * urlStr = [rootPath stringByAppendingString:reqStr];
    // handle offline case?
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:[NSURL URLWithString:urlStr]
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {
                NSLog(@"response is %@", data);
                
            }] resume];
}

+ (void) updateUserInfo:(NSDictionary *) userInfo {
    NSMutableArray * objects = [MyApi loadObjects];
    CLGeocoder* geocoder = [CLGeocoder new];
    NSMutableDictionary * obj = nil;
    NSString * who = [userInfo objectForKey:@"who"];
    for (NSMutableDictionary * dict in objects) {
        if (who &&[who isEqualToString:[dict objectForKey:@"id"]]) {
            obj = dict;
        }
    }
    if (obj) {
        NSNumber * lat = [userInfo objectForKey:@"lat"];
        NSNumber * lng = [userInfo objectForKey:@"lng"];
        NSNumber * ts = [userInfo objectForKey:@"ts"];
        [obj setObject:lat forKey:@"lat"];
        [obj setObject:lng forKey:@"lng"];
        [obj setObject:[NSDate dateWithTimeIntervalSince1970:[ts doubleValue]] forKey:@"time"];
        CLLocation * loc = [[CLLocation alloc] initWithLatitude:[lat doubleValue] longitude:[lng doubleValue]];
        [geocoder reverseGeocodeLocation:loc completionHandler:^(NSArray *placemarks, NSError *error) {
            
            CLPlacemark* pl;
            if ([placemarks count] > 0) {
                pl = [placemarks lastObject];
                NSString * geo = [NSString stringWithFormat:@"%@, %@ %@", pl.name, pl.postalCode, pl.locality];
                [obj setObject:geo forKey:@"geo"];
                [MyApi saveObject:objects];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"myRemoteNofication" object:nil userInfo:userInfo];
            }
           
        }];
        
        [MyApi saveObject:objects];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"myRemoteNofication" object:nil userInfo:userInfo];
    }
    
}


+ (NSMutableArray *) loadObjects {
    NSMutableArray * objects = [[NSMutableArray alloc] init];
    objects = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
    NSError *error;
    NSString * fileName = [documentsDirectory stringByAppendingPathComponent:@"kids.info"];
    NSString *fileContents = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:&error];
    for (NSString *line in [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        // Do something
        NSData *objectData = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization JSONObjectWithData:objectData
                                                                                                           options:NSJSONReadingMutableContainers
                                                                                                             error:&error]];
        [objects addObject:json];
    }
    return objects;
}

+ (void) saveObject:(NSMutableArray *) objects {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
    NSError *error;
    NSMutableArray * result = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < [objects count]; i++) {
        id obj = [objects objectAtIndex:i];
        NSData * d = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
        NSString * r = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        [result addObject:r];
    }
    
    
    BOOL succeed = [[result componentsJoinedByString:@"\n"] writeToFile:[documentsDirectory stringByAppendingPathComponent:@"kids.info"]
        atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!succeed){
        // Handle error here
    }
}

@end
