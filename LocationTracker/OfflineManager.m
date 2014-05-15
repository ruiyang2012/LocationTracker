//
//  OfflineManager.m
//  clientApiLib
//
//  Created by rui yang on 11/13/13.
//  Copyright (c) 2013 rui yang. All rights reserved.
//

#import "OfflineManager.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "Reachability.h"
#import "ProxUtils.h"

#define DB_NAME @"prox.db"

#define GET_ONE_NET_OPS @"select * from netops limit 1;"
#define DEL_ONE_NET_OPS @"delete from netops where id=%d;"
#define GET_PROX_OBJ @"select * from proxobj where oid='%@';"
#define GET_PROX_OBJ_LIST @"select * from proxobj where otype='%@' and deleted = 0 and user_id=%ld %@ order by %@ desc %@;"
#define ADD_OBJ @"INSERT INTO proxobj (oid, otype, local, deleted, json, modified, created, user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
#define ADD_NET_OP @"INSERT INTO netops (oid, method, path, params, created, user_id) VALUES (?, ?, ?, ?, ?, ?);"
#define MARK_OBJ_DELETE @"update  proxobj set deleted = 1 where oid='%@';"
#define UPD_OBJ_MODIFIED @"update  proxobj set modified = %@ where oid='%@';"
#define PURGE_ALL @"delete from proxobj where deleted=1"
#define UPD_PROOBJ_VALUE @"UPDATE proxobj set json='%@', user_id='%ld', created='%ld' where oid='%@';"
#define CORRECT_USER_ID_MODIFIED @"UPDATE  proxobj set user_id = %ld where user_id=0;"
#define DB_SCHEMA_VER @"1.3"
#define FIND_MATCH_HISTOGRAM @"SELECT count(1) as c FROM histogram where bucket='%@'"
#define INIT_HISTOGRAM @"INSERT INTO histogram (bucket) VALUES ('%@');"
#define UPD_HISTOGRAM @"UPDATE histogram set sums=sums + %d where bucket='%@';"
#define INSERT_TIME_SERIES @"INSERT INTO time_series_data (time, t_type, t_value, speed) VALUES (?,?,?,?)"
#define GROUP_BY_LARGEST_TIME @"SELECT t_value, sum(delta) as s from time_series_data where t_type='apple_map' and  time > %d and time < %d group by t_value order by s desc limit 1"
#define TODAY_LOCATIONS @"select bucket, display, sums, time, sum(delta) as d from histogram , time_series_data where t_value = bucket and time > %d  group by bucket  order by time"
#define UPDATE_DELTA @"UPDATE time_series_data set delta= %d where time = %d"
#define UPDATE_TIME_DATA_TYPE @"UPDATE time_series_data set t_type= '%@' where t_value = '%@'"
  // use max working speed 3 as filter
#define GET_ALL_UNCONFIRMED_TIME @"select t_value, time from time_series_data where t_type='raw_data' and speed < 3"
#define GET_ALL_AGGREGATE_TIME @"select t_value, sum(delta) as s from time_series_data where t_type='%@' and time >= %ld group by t_value"
#define CAL_DELTA @"SELECT B.time, (A.time - B.time) as diff from time_series_data A INNER JOIN time_series_data B on A.ID > B.ID and A.t_type like 'raw_data%@' and B.t_type like 'raw_data%@'  and A.time > %ld group by A.ID"
#define GET_LATEST_RAW_TIME @"select time, delta from time_series_data where t_type like 'raw_data%' order by time desc limit 1"
#define GET_MAX_HISTOGRAM @"select max(sums) as s, bucket, display from histogram"
#define GET_TOP_HISTOGRAM @"select bucket, display, sums from histogram where sums > %d order by sums desc limit %d"
#define UPD_HISTOGRAM_DISPLAY @"UPDATE histogram set display = '%@' where bucket = '%@'"

@interface OfflineManager () {
  NSString *databasePath;
  Reachability *internetReachability;
  BOOL isOffline;
  FMDatabase * db;
  OfflineManager* __weak weakSelf;
  NSInteger _userId;
  NSDateFormatter * dateFormatter;
  NSString* _objTypeNs;
}

@end


@implementation OfflineManager

- (id) init {
  self = [super init];
  _objTypeNs = @"";
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
  internetReachability = [Reachability reachabilityForInternetConnection];
  [internetReachability startNotifier];
  isOffline = (internetReachability.currentReachabilityStatus == NotReachable);
  
  NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentDir = [documentPaths objectAtIndex:0];
  databasePath = [documentDir stringByAppendingPathComponent:DB_NAME];
  
  [self createAndCheckDatabase];
  db = [FMDatabase databaseWithPath:databasePath];
  [self openDB];
  weakSelf = self;
  _userId = 0;
  dateFormatter = [[NSDateFormatter alloc] init] ;
  dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
  [self performSelector:@selector(notifyNetworkStatus) withObject:nil afterDelay:0];
  return self;
}

- (void) notifyNetworkStatus {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ProxOfflineStatusChange" object:nil];
}

- (void) setObjTypeNS:(NSString*) objTypeNs {
  if (objTypeNs) _objTypeNs = objTypeNs;
}

- (NSString *) getObjType:(NSString*) objTypeName {
  return [_objTypeNs stringByAppendingString:objTypeName];
}

- (void) openDB {
  [db open];
}

- (void) closeDB {
  [db close];
}

- (void) dealloc {
  [self closeDB];
}

- (void) setUserId:(NSInteger) userId {
  _userId = userId;
}

-(void) createAndCheckDatabase
{
  BOOL success;
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString * ver =[defaults objectForKey:@"proxdbversion"];
  success = [fileManager fileExistsAtPath:databasePath];
  
  NSDictionary * dict = nil;
  
  if(success && [DB_SCHEMA_VER isEqualToString:ver]) {
    dict = [fileManager attributesOfItemAtPath:databasePath error:nil];
    unsigned long long fileSize = [[dict objectForKey:NSFileSize] longLongValue];
    if (fileSize > 0) return;
    NSLog(@"Copy DB file to docucments folder");
  }
  [defaults setObject:DB_SCHEMA_VER forKey:@"proxdbversion"];
  [defaults synchronize];
  
  NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DB_NAME];
  [fileManager removeItemAtPath:databasePath error:nil];
  [fileManager copyItemAtPath:databasePathFromApp toPath:databasePath error:nil];
}


/*!
 * Called by Reachability whenever status changes.
 */
- (void) reachabilityChanged:(NSNotification *)note {
  isOffline = (internetReachability.currentReachabilityStatus == NotReachable);
  if (!isOffline) {
    [self retry];
  }
  [self notifyNetworkStatus];
}

- (BOOL) isOffline {
  return isOffline;
}

-(void) pushNetOperation:(NSString*) method objId:(NSString*) objId path:(NSString*) path params:(NSDictionary*)dict {
  NSString * json = @"";
  if (dict != nil) {
    json = [ProxUtils getJsonStrFromJsonObj:dict];
  };
  NSLog(@"offline, push one write operation to stack %@ -- %@ -- %@", method, objId, path);
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  @synchronized(db) {
   [db executeUpdate:ADD_NET_OP, objId, method, path, json, [NSNumber numberWithInteger:now], [NSNumber numberWithInteger:_userId]];
  }
}

- (NSTimeInterval) getIntFromDateStr:(NSDictionary*) dict dateField:(NSString*) field {
  NSString* v = [dict objectForKey:field];
  if (v == nil) return 0;
  NSTimeInterval ret = [[dateFormatter dateFromString:v] timeIntervalSince1970];
  if (ret <=0) {
    ret = [[dateFormatter dateFromString:[NSString stringWithFormat:@"%@Z", v]] timeIntervalSince1970];
  }
  return (ret < 0) ? 0 : ret;
}

- (void) updProxObj:(NSDictionary *) json sortTime:(NSInteger)sortOrder objectId:(NSString*) oid {
  NSString * newJson = [[ProxUtils getJsonStrFromJsonObj:json] stringByReplacingOccurrencesOfString:@"'" withString:@"&quot;"];
  NSString * sql = [NSString stringWithFormat:UPD_PROOBJ_VALUE, newJson, (long)_userId, (long)sortOrder, oid];
    //NSLog(@"sql to run %@", sql);
  @synchronized(db) {
    [db executeUpdate:sql];
  }
}

- (void) correctObjForCurUser {
  if (_userId == 0) return;
  NSString * sql = [NSString stringWithFormat:CORRECT_USER_ID_MODIFIED, (long)_userId];
    //NSLog(@"sql to run %@", sql);
  @synchronized(db) {
    [db executeUpdate:sql];
  }
}

-(void) storeObject:(NSString*) objId type:(NSString*) type value:(NSDictionary*) value weak:(BOOL) weak local:(BOOL)local{
    // merge if oid exist, otherwise insert.
  if ([ProxUtils isEmptyString:objId] || !value || [value count] == 0) {
    NSLog(@"Warning! trying to set an empty object id locally!!! type: %@ \n", type);
    return;
  }
  [self updateObjModified:objId];
  NSString* cachedValue = [self getObject:objId];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSTimeInterval transTime = [self getIntFromDateStr:value dateField:@"trans_date"];
  NSTimeInterval localTransTime = [self getIntFromDateStr:value dateField:@"local_trans_date"];
  if (transTime == 0) transTime = localTransTime;
  NSTimeInterval created = [self getIntFromDateStr:value dateField:@"created"];
  NSTimeInterval modified = [self getIntFromDateStr:value dateField:@"modified"];
  if (local) {
      // reset trans time for non-receipt.
    if (![self isReceiptType:type]) { transTime = modified; }
    modified = now;
  }
  
  NSTimeInterval sortTime = (transTime > 0) ? transTime :  (created > 0) ? created : now;

  
  if ([ProxUtils isEmptyString:cachedValue]) {
    NSString * json = [[ProxUtils getJsonStrFromJsonObj:value] stringByReplacingOccurrencesOfString:@"'" withString:@"&quot;"];
    @synchronized(db) {
      [db executeUpdate:ADD_OBJ, objId, type, [NSNumber numberWithBool:local], [NSNumber numberWithBool:NO],
         json, [NSNumber numberWithInteger:now], [NSNumber numberWithInteger:sortTime], [NSNumber numberWithInteger:_userId]];
    }
  } else if (!weak) {
    [self updProxObj:value sortTime:sortTime objectId:objId];
  }else {
      // TODO, merge object?, current stragedy is to trust localy only, remote data will be discarded if there is a local one.
      // also some field need to be override by remote always, like data_structured field.
    NSMutableArray * whiteList = [NSMutableArray arrayWithObjects:@"local_trans_date", @"sub_total", @"grand_total", @"currency", @"tax",
                     @"has_img",@"has_data_txt", @"store_address", @"trans_date", @"status", @"tz_offset", @"store_logo_url",
                     @"store_name", @"store", @"items", @"title", @"receipt_type", @"canonical_store_name", @"crm_contact",
                     @"num_receipts", @"count", @"store_geo", @"return_expire_date", @"warranty_expire_date", nil];
    NSMutableDictionary * newDict = [ProxUtils getJsonObjFromJsonStr:cachedValue];

    NSTimeInterval localModified = [self getIntFromDateStr:newDict dateField:@"modified"];

    if (localModified < modified) {
      [whiteList addObject:@"name"];
      [whiteList addObject:@"color_code"];
      [whiteList addObject:@"modified"];
      [whiteList addObject:@"userprojects"];
    }
      // will copy non-exist key from remote to local as well.
    for (id k in value) {
      if ([newDict objectForKey:k] == nil) {
        [whiteList addObject:k];
      }
    }

    BOOL isDirty = NO;
    for (id key in whiteList) {
      id newValue = [value objectForKey:key];
      if (!newValue) continue;
      if ([newValue isKindOfClass:[NSString class]] && [ProxUtils isEmptyString:newValue]) continue;
      [newDict setValue:newValue forKey:key];
      isDirty = YES;
    }
    NSNumber* remoteDeleted = [value objectForKey:@"user_deleted"];
    if ([remoteDeleted boolValue] == YES) {
      isDirty = YES;
      [newDict setValue:[NSNumber numberWithBool:YES] forKey:@"user_deleted"];
    }

    if (isDirty) {
      [self updProxObj:newDict sortTime:sortTime objectId:objId];
    }
  }
}


-(NSString*) getObject:(NSString*) objId {
  FMResultSet * r = nil;
  NSString* result = nil;
  @synchronized(db) {
    r = [db executeQuery:[NSString stringWithFormat:GET_PROX_OBJ, objId]];
    if ([r next]) {
      result = [[r stringForColumn:@"json"] stringByReplacingOccurrencesOfString:@"&quot;" withString:@"'"];
      [r close];
    }
  }
  return result;
}

- (BOOL) isReceiptType:(NSString*) type {
  return ([type rangeOfString:@"receipt"].location != NSNotFound);
}

- (NSMutableArray*) getObjectsByType:(NSString*) type page:(int) page pageSize:(int) pageSize extraFilter:(NSString*) filter{
  NSMutableArray * array = [[NSMutableArray alloc] init];
  NSString * limit = @"";
  if (page >0) {
    limit = [NSString stringWithFormat:@"limit %d, %d", (page - 1) * pageSize, pageSize];
  }
  FMResultSet * r = nil;
  NSString * order = @"modified";
  if ([self isReceiptType:type]) {
    order = @"created";
  }
  @synchronized(db) {
    NSString* sql = [NSString stringWithFormat:GET_PROX_OBJ_LIST, type, (long)_userId, filter,order, limit];
    r = [db executeQuery:sql];
    while ([r next]) {
      NSString* json = [[r stringForColumn:@"json"] stringByReplacingOccurrencesOfString:@"&quot;" withString:@"'"];
      if (![ProxUtils isEmptyString:json]) {
        [array addObject:[ProxUtils getJsonObjFromJsonStr:json]];
      }
    }
    [r close];
  }
    // TODO, use a readonly copy here if we come to a conficts.
  return array;
}

- (void) makeObjAsDeleted:(NSString*) oId {
  @synchronized(db) {
    [db executeUpdate:[NSString stringWithFormat:MARK_OBJ_DELETE, oId]];
  }
}

- (void) purgeAllDeleted {
  @synchronized(db) {
    [db executeUpdate:PURGE_ALL];
  }
}

-(void) retry {
    // for each netops, resent the request, if failed, stop and break.
  FMResultSet * r = nil;
  BOOL needPurge = NO;
  @synchronized(db) {
    r = [db executeQuery:GET_ONE_NET_OPS];
    if ([r next]) {
      NSLog(@"found one buffered network operation");
        // NSString* oid = [r stringForColumn:@"oid"];
      NSString* json = [r stringForColumn:@"params"];
      NSDictionary *p = [ProxUtils getJsonObjFromJsonStr:json];
      int i = [r intForColumn:@"id"];
      [self.delegate networkRequest:[r stringForColumn:@"method"] path:[r stringForColumn:@"path"] type:@"retry" params:p
                               done:^(NSString* type, NSString* value, NSDictionary * result, BOOL b){
                                   // to do error check here, only proceed when we resovle the error
                                 @synchronized(db) {
                                   [db executeUpdate:[NSString stringWithFormat:DEL_ONE_NET_OPS, i]];
                                 }
                                 [weakSelf retry];
                               }];
      [r close];
    } else {
      needPurge = YES;
    }

  }
  
  if (needPurge) { [self purgeAllDeleted]; }
  

}

- (int) receiptInGroup:(NSDictionary*) r publicId:(NSString* ) publicId {
  NSArray * projects = [r objectForKey:@"userprojects"];
  if (projects == nil || [projects count] == 0) return -1;
  int i = 0;
  for (id p in projects) {
    NSString* pId = [p objectForKey:@"public_id"];
    if ([publicId isEqualToString:pId]) {
      return i;
    }
    i++;
  }
  return -1;
}

- (NSDictionary *) getLocalReceiptsForUserProject:(NSString*) publicId page:(int) page pageSize:(int) pageSize {
  NSString * extraFilter = @"";
  if (![ProxUtils isEmptyString:publicId]) {
    extraFilter = [NSString stringWithFormat:@" and json like '%@%@%@'", @"%", publicId, @"%"];
  }
  
  NSMutableArray* r = [self getObjectsByType:[self getObjType:@"receipt" ] page:page pageSize:pageSize extraFilter:extraFilter];

  if ([r count] == 0) return nil;
    //if (pageSize <= 0) pageSize = 20;
  NSNumber *nextPage = [NSNumber numberWithInteger:page + 1];
  NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:r, @"results",
      [NSNumber numberWithInteger:[r count]], @"count", nextPage, @"nextPage", @"1", @"isLocalCache", nil];
  
  return dict;
}

- (void) updateReceiptObjWithGroup:(BOOL) isDel rid:(NSString*)rid receiptDict:(NSDictionary*) receipt publicId:(NSString*) publicId {
  if (receipt == nil) return;
  NSMutableArray * projects = [receipt objectForKey:@"userprojects"];
  
  if (projects == nil) projects = [[NSMutableArray alloc] init];
  
  if ([projects count] == 0 && isDel) return;
    //NSLog(@"number of projects from existing %ld", (long)[projects count]);
  
  NSDictionary * group = [ProxUtils getJsonObjFromJsonStr:[self getObject:publicId]];
    // TODO validate group here.
  
  int i = [self receiptInGroup:receipt publicId:publicId];
  if (i >=0) {
    [projects removeObjectAtIndex:i];
  }
  if (isDel) {
    
  } else if (group != nil) {
    [projects addObject:group];
      //NSLog(@"number of projects from new group %ld", (long)[projects count]);
  }
  [receipt setValue:projects forKey:@"userprojects"];
  [self updateObjModified:publicId];
  [self storeObject:rid type:[self getObjType:@"receipt" ] value:receipt weak:NO local:YES];
}

- (void) updateObjModified:(NSString * )oid {
  NSNumber * now = [NSNumber numberWithInteger:[[NSDate date] timeIntervalSince1970]];
  NSString* sql =[NSString stringWithFormat:UPD_OBJ_MODIFIED, [now description], oid];
  @synchronized(db) {
    [db executeUpdate:sql];
  }
}

- (void) updateReceiptGroupRelation:(BOOL) isDel rid:(NSString*) rid publicId:(NSString*) publicId {
  NSDictionary * receipt = [ProxUtils getJsonObjFromJsonStr:[self getObject:rid]];
  NSString * objId = [receipt objectForKey:@"rid"];
  if (![rid isEqualToString:objId]) {
    NSLog(@"No match object, something wrong! %@ -- %@", rid, objId);
    return;
  }
  [self updateReceiptObjWithGroup:isDel rid:rid receiptDict:receipt publicId:publicId];
}

- (void) updateAllReceiptWithGroupChange:(BOOL) isDel publicId:(NSString*) publicId {
  NSMutableArray* r = [self getObjectsByType:[self getObjType:@"receipt" ] page:0 pageSize:0 extraFilter:@""];
  for (id receipt in r) {
    NSString* rid = [receipt objectForKey:@"rid"];
    int i = [self receiptInGroup:receipt publicId:publicId];
    if (i >= 0) [self updateReceiptObjWithGroup:isDel rid:rid receiptDict:receipt publicId:publicId];
  }
}

- (NSArray*) getAllLocationCloseTo:(CLLocation*)cl radius:(double) radius {
  NSMutableArray* r = [self getObjectsByType:[self getObjType:@"location" ] page:0 pageSize:0 extraFilter:@""];
  NSMutableArray * result = [[NSMutableArray alloc] init];
  for (id row in r) {
    NSArray* val = [[row objectForKey:@"v"] componentsSeparatedByString:@"|"];
    if ([val count] == 3) {
      double lat = [val[0] doubleValue];
      double lon = [val[1] doubleValue];
      CLLocation * to = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
      double diff = [cl distanceFromLocation:to];
      if (diff < radius) {
        NSDictionary * item = [[NSDictionary alloc] initWithObjectsAndKeys:to, @"coordinate",
                               [NSNumber numberWithDouble:diff],@"distance", val[2], @"name", nil];
        [result addObject:item];
      }
    }
  }
  return result;
}


- (void) setLoc:(NSString*)loc type:(NSString*) type time:(NSNumber*)time speed:(NSNumber*)speed {
  @synchronized(db) {
    [db executeUpdate:INSERT_TIME_SERIES, time, type, loc, speed];
     
  }
}

- (void) updateTimeSeriesType:(NSString*) newType key:(NSString*) key {
  @synchronized(db) {
    [db executeUpdate:[NSString stringWithFormat:UPDATE_TIME_DATA_TYPE, newType, key]];
  }
}

- (void) aggregateHistogram:(NSString *)type  ts:(long)ts{
  FMResultSet * r = nil;
  NSString * sql = [NSString stringWithFormat:GET_ALL_AGGREGATE_TIME, type, ts];
  r = [db executeQuery:sql];
  while ([r next]) {
    NSString* val = [r stringForColumn:@"t_value"];
    int delta = [r intForColumn:@"s"];
    if (delta < 1) continue;
    FMResultSet * histRow = [db executeQuery:[NSString stringWithFormat:FIND_MATCH_HISTOGRAM, val]];
    if ([histRow next]) {
      int rowCount = [histRow intForColumn:@"c"];
      if (rowCount == 0) {
        NSString * initHistSql = [NSString stringWithFormat:INIT_HISTOGRAM, val];
        [db executeUpdate:initHistSql];
      }
    } else {
      NSLog(@"Error run select histogram count");
    }
    [db executeUpdate:[NSString stringWithFormat:UPD_HISTOGRAM, delta, val]];
    
  }
}

- (void) calDeltaInTimeSeries {
  long lastTime = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastDeltaTimeStamp"];
  long now = [[NSDate date] timeIntervalSince1970];
  BOOL hasData = NO;
  @synchronized(db) {
    FMResultSet * r = [db executeQuery:[NSString stringWithFormat:CAL_DELTA, @"%", @"%", lastTime]];

    while ([r next]) {
      int time = [r intForColumn:@"time"];
      int diff = [r intForColumn:@"diff"];
      [db executeUpdate:[NSString stringWithFormat:UPDATE_DELTA, diff, time]];
      hasData = YES;
    }
      // fix last record
    r = [db executeQuery:GET_LATEST_RAW_TIME];
    if ([r next]) {
      int time = [r intForColumn:@"time"];
      int delta = [r intForColumn:@"delta"];
      int diff = now - time;
      if (delta == 0) {
        [db executeUpdate:[NSString stringWithFormat:UPDATE_DELTA, diff, time]];
      }
    }
    if (hasData) [self aggregateHistogram:@"apple_map" ts:lastTime];
  }
  if (hasData) [[NSUserDefaults standardUserDefaults] setInteger:now forKey:@"lastDeltaTimeStamp"];
}

- (NSString*) getLongestOvernightLocation {
  FMResultSet * r = nil;
  
  @synchronized(db) {
    NSDate* td = [ProxUtils getYesterday];
    int start = [td timeIntervalSince1970] + 3600 * 18;
    int end = start + 3600 * 14;
    r = [db executeQuery:[NSString stringWithFormat:GROUP_BY_LARGEST_TIME, start, end]];
    if ([r next]) {
      NSString* bucket = [r stringForColumn:@"bucket"];
      NSArray * array = [bucket componentsSeparatedByString:@"|"];
      if (array) return [NSString stringWithFormat: @"%@,%@", array[0], array[1]];
    }
  }
  return nil;
}

- (NSArray*) getAllUnconfirmedGeo {
  NSMutableArray * result = [[NSMutableArray alloc] init];
  @synchronized(db) {
    FMResultSet * r = nil;
    r = [db executeQuery:GET_ALL_UNCONFIRMED_TIME];
    while ([r next]) {
      NSString* val = [r stringForColumn:@"t_value"];
      NSNumber* ts = [NSNumber numberWithInt:[r intForColumn:@"time"]];
      [result addObject:@[val, ts]];
    }
  }
  return result;
}

- (NSArray *) getLongestStayOfAllTime:(int) minStaySeconds limit:(int) limit{
  NSMutableArray * array = [[NSMutableArray alloc] init];
  @synchronized(db) {
    FMResultSet * r = [db executeQuery:[NSString stringWithFormat:GET_TOP_HISTOGRAM, minStaySeconds, limit]];
    while ([r next]) {
      NSString* bucket = [r stringForColumn:@"bucket"];
      NSString* display = [r stringForColumn:@"display"];
      [array addObject:display ? display : bucket];
    }
  }
  return array;
}

- (void) initHistogramIfNoData {
  FMResultSet * r = nil;
  r = [db executeQuery:GET_MAX_HISTOGRAM];
  double value = 0;
  if ([r next]) {
    value = [r doubleForColumn:@"s"];
  }
  if (value < 60) {
    [self aggregateHistogram:@"apple_map" ts:0];
  }
}

- (NSString*) updateDisplayAddr:(NSString*) bucket lat:(double) lat lon:(double) lon name:(NSString*) name
      street:(NSString*) street city:(NSString*)city state:(NSString*) state country:(NSString*) country
      zip:(NSString*) zip {
  NSString* latlon = [NSString stringWithFormat:@"%f|%f", lat, lon];
  if (!name) name = @"";
  if (!street) street = @"";
  if (!city) city = @"";
  if (!state) state = @"";
  if (!country) country = @"";
  if (!zip) zip = @"";
  NSArray * arr = @[latlon, name, street, city, state, country, zip];
  NSString * display = [arr componentsJoinedByString:@"|"];
  NSString * sql = [NSString stringWithFormat:UPD_HISTOGRAM_DISPLAY, display, bucket];
  @synchronized(db) {
    [db executeUpdate:sql];
  }
  return display;
}

- (NSDictionary *) decodeBucket:(NSString*) bucketString {
  NSArray* bucket = [bucketString componentsSeparatedByString:@"|"];

  NSDictionary * dict = [[NSDictionary alloc] initWithObjectsAndKeys:bucket[0], @"lat", bucket[1], @"lon",
    bucket[2], @"name", bucket[3], @"street", bucket[4], @"city", bucket[5], @"state", bucket[6], @"country",
    bucket[7], @"zip", bucketString, @"bucket", nil];
  return dict;
}

- (NSArray*) getLocationsSince:(int)seconds {
  FMResultSet * r = nil;
  
  @synchronized(db) {
    [self initHistogramIfNoData];

    NSMutableArray * arr = [[NSMutableArray alloc] init];
    r = [db executeQuery:[NSString stringWithFormat:TODAY_LOCATIONS, seconds]];
    while ([r next]) {
      NSString* bucket = [r stringForColumn:@"bucket"];
      NSString * display = [r stringForColumn:@"display"];
      BOOL hasDisplay = ![ProxUtils isEmptyString:display];
      NSDictionary * dict = [self decodeBucket: hasDisplay ? display : bucket];
      
      NSNumber* sum = [NSNumber  numberWithDouble:[r doubleForColumn:@"sums"] ];
      NSNumber* delta = [NSNumber  numberWithDouble:[r doubleForColumn:@"d"] ];
      NSNumber* time = [NSNumber  numberWithDouble:[r doubleForColumn:@"time"] ];
      NSMutableDictionary * addr = [[NSMutableDictionary alloc] initWithDictionary:dict];
      [addr setObject:[NSNumber numberWithBool:hasDisplay] forKey:@"hasConfirmedAddress"];
      [addr setObject:sum forKey:@"totalDuration"];
      [addr setObject:delta forKey:@"duration"];
      [addr setObject:time forKey:@"time"];
      [arr addObject:addr];
    }
    
    if ([arr count] > 0) {
      NSMutableDictionary * lastRow = [arr lastObject];
      NSNumber * lastTime = [lastRow objectForKey:@"time"];
      NSNumber * lastDelta = [lastRow objectForKey:@"duration"];
      NSNumber * diff = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] - [lastTime doubleValue]];
      if (lastDelta < diff) {
        [lastRow setObject:diff forKey:@"duration"];
      }
      return arr;
    }
  }
  return nil;
}

- (NSArray*) getLocationsHoursBefore:(int)hour {
  NSTimeInterval start = [[NSDate date] timeIntervalSince1970] - hour * 3600;
  return [self getLocationsSince:start];
}

- (NSArray*) getTodayLocations {
  NSDate* td = [ProxUtils getToday];
  int start = [td timeIntervalSince1970];
  return [self getLocationsSince:start];
}


@end
