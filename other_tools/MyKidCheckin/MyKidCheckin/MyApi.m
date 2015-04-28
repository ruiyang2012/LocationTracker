//
//  MyApi.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/28/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyApi.h"

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

@end
