//
//  MyApi.h
//  MyKidCheckin
//
//  Created by Rui Yang on 4/28/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyApi : NSObject

+ (void) api:(NSString *) path param:(NSDictionary *) request;

@end
