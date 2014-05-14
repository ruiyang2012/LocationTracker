//
//  OfflineManager.h
//  clientApiLib
//
//  Created by rui yang on 11/13/13.
//  Copyright (c) 2013 rui yang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol ProxApiDelegate <NSObject>
@required
- (void) networkRequest:(NSString*) method path:(NSString*) path type:(NSString* )aType params:(NSDictionary*)p
                   done:(void (^)(NSString*, NSString*, NSDictionary *, BOOL))block;
@end

@interface OfflineManager : NSObject {
    // Delegate to respond back
  id <ProxApiDelegate> _delegate;
  
}

@property (nonatomic,strong) id delegate;

- (void) setUserId:(NSInteger) userId;

- (BOOL) isOffline;

- (void) pushNetOperation:(NSString*) method objId:(NSString*) objId path:(NSString*) path params:(NSDictionary*)dict;

- (void) storeObject:(NSString*) objId type:(NSString*) type value:(NSDictionary*) value weak:(BOOL) weak local:(BOOL)local;
- (NSString*) getObject:(NSString*) objId;
- (void) makeObjAsDeleted:(NSString*) oId;
- (void) purgeAllDeleted;
- (NSMutableArray*) getObjectsByType:(NSString*) type  page:(int) page pageSize:(int) pageSize extraFilter:(NSString*) filter;
- (NSDictionary *) getLocalReceiptsForUserProject:(NSString*) publicId page:(int) page pageSize:(int) pageSize;

- (void) updateReceiptGroupRelation:(BOOL) isDel rid:(NSString*) rid publicId:(NSString*) publicId;
- (void) updateAllReceiptWithGroupChange:(BOOL) isDel publicId:(NSString*) publicId;

-(void) retry;

- (void) correctObjForCurUser;

- (void) setObjTypeNS:(NSString*) objTypeNs;

- (void) setLoc:(NSString*)loc type:(NSString*) type time:(NSNumber*)time;

- (NSString*) getLongestOvernightLocation;

- (NSArray*) getTodayLocations;

- (void) calDeltaInTimeSeries;

- (void) updateTimeSeriesType:(NSString*) newType key:(NSString*) key;

- (NSArray*) getAllUnconfirmedGeo;
- (NSArray*) getAllLocationCloseTo:(CLLocation*)cl radius:(double) radius;

- (NSArray*) getLongestStayOfAllTime:(int) minStaySeconds;

- (NSString *) getObjType:(NSString*) objTypeName;

- (NSString*) updateDisplayAddr:(NSString*) bucket lat:(double) lat lon:(double) lon name:(NSString*) name street:(NSString*) street
                      city:(NSString*)city state:(NSString*) state country:(NSString*) country zip:(NSString*) zip;
@end
