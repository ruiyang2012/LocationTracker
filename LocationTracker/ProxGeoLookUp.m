//
//  ProxGeoLookUp.m
//  LocationTracker
//
//  Created by rui yang on 5/12/14.
//  Copyright (c) 2014 Linc. All rights reserved.
//
#import "ProxUtils.h"
#import "ProxGeoLookUp.h"


#define FOURSQUARE_CLIENT_ID     @"XESFJ1BM2GLVKIR0E05DNJWQLIWJXE2YIH15XYBQS0SL5DDB"
#define FOURSQUARE_CLIENT_SECRET @"S02H4GVQCHPOSUB2G4XXZFHWX2RERYDMWA1H0VL2ZEZDYDHZ"

@implementation ProxGeoLookUp {
  NSDictionary *categories;
  NSURLSession * session;
}

- (id) init {
  self = [super init];
  categories = @{@"Arts & Entertainment": @"4d4b7104d754a06370d81259",
                 //@"College & University": @"4d4b7105d754a06372d81259",
                 @"Event": @"4d4b7105d754a06373d81259",
                 @"Food": @"4d4b7105d754a06374d81259",
                 @"Nightlife Spot": @"4d4b7105d754a06376d81259",
                 //@"Outdoors & Recreation": @"4d4b7105d754a06377d81259",
                 @"Shop & Service": @"4d4b7105d754a06378d81259"
                 //@"Travel & Transport": @"4d4b7105d754a06379d81259"
                 };
  session = [NSURLSession sharedSession];
  return self;
}

- (NSString *)foursquareCategories {
  return [[categories allValues] componentsJoinedByString:@","];
}

- (void) fourSquareLookup:(CLLocationCoordinate2D) coord filterByCategory:(BOOL) fbc done:(PROX_GEO_CALLBACK) callback {
  NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
  parameters[@"client_id"] = FOURSQUARE_CLIENT_ID;
  parameters[@"client_secret"]= FOURSQUARE_CLIENT_SECRET;
  parameters[@"ll"] = [NSString stringWithFormat:@"%f,%f", coord.latitude, coord.longitude];
  parameters[@"intent"] = @"checkin";
  parameters[@"limit"] = @"4";
  parameters[@"v"] = @"20140418";
  parameters[@"radius"] = @"100";
  if (fbc) parameters[@"categoryId"] = [self foursquareCategories];
  
  NSString *queryString = [ProxUtils dictionaryToQueryString:parameters];
  NSString *urlString = [NSString stringWithFormat:@"https://api.foursquare.com/v2/venues/search?%@", queryString];
  NSURL *url = [[NSURL alloc] initWithString:urlString];
    //NSLog(@"%@", urlString);
  
  [[session dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (error) {
                NSLog(@"Failed to load four square result %@", [error localizedDescription]);
              } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode != 200) {
                  NSLog(@"Failed to get response from server: %ld", (long)httpResponse.statusCode);
                } else {
                  NSError *jsonError = nil;
                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                  if (jsonError != nil) {
                    NSLog(@"Failed to retrieve json object for invitation code: %@", [jsonError localizedDescription]);
                  } else {
                    callback(json);
                  }
                }
              }
              
            }] resume];
  
}

@end
