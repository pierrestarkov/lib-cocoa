//
//  PYConnection+Events.m
//  Pods
//
//  Created by Perki on 14.07.14.
//
//


#import "PYCachingController+Event.h"
#import "PYConnection+Events.h"
#import "PYClient.h"
#import "PYEventFilterUtility.h"
#import "PYEvent.h"
#import "PYAttachment.h"
#import "PYErrorUtility.h"
#import "PYkNotifications.h"


@interface PYConnection ()

- (void) eventFromReceivedDictionary:(NSDictionary*) eventDic
                              create:(void(^) (PYEvent*event))create
                              update:(void(^) (PYEvent*event))update
                                same:(void(^) (PYEvent*event))same;

@end

@implementation PYConnection (Events)


#pragma mark - Pryv API Events

- (void)eventsWithFilter:(PYFilter *)filter
               fromCache:(void (^) (NSArray *cachedEventList))cachedEvents
               andOnline:(void (^) (NSArray *onlineEventList, NSNumber *serverTime))onlineEvents
    onlineDiffWithCached:(void (^) (NSArray *eventsToAdd, NSArray *eventsToRemove, NSArray *eventModified))syncDetails
            errorHandler:(void (^)(NSError *error))errorHandler
{
    
    
    //Return current cached events and eventsToAdd, modyfiy, remove (for visual details)
    
#warning - we should remove the dispatch as soon as event is faster
    dispatch_async(dispatch_get_main_queue(), ^{
        
        
        NSArray *eventsFromCache = [self allEvents];
        
        
        
        __block NSArray *filteredCachedEventList = [PYEventFilterUtility filterEventsList:eventsFromCache
                                                                               withFilter:filter];
        
        
        
#warning - check that retain ... without it was crashing in the subblock ..
        [filteredCachedEventList retain];
        
        
        if (cachedEvents) {
            if ([eventsFromCache count] > 0) {
                //if there are cached events return it, when get response return in onlineList
                cachedEvents(filteredCachedEventList);
            }
        }
        
        //This method should retrieve always online events
        //In this method we should synchronize events from cache with ones online and to return current online list
        [self eventsOnlineWithFilter:filter
                      successHandler:^(NSArray *onlineEventList, NSNumber *serverTime, NSDictionary *details) {
                          NSDate *afx3 = [NSDate date];
                          if (onlineEvents) {
                              onlineEvents(onlineEventList, serverTime);
                          }
                          NSLog(@"*afx3 A %f", [afx3 timeIntervalSinceNow]);
                          
                          if (syncDetails) {
                              // give differences between cachedEvents and received events
                              
                              NSMutableSet *intersection = [NSMutableSet setWithArray:filteredCachedEventList];
                              [intersection intersectSet:[NSSet setWithArray:onlineEventList]];
                              NSMutableArray *removeArray = [NSMutableArray arrayWithArray:[intersection allObjects]];
                              
                              [PYEventFilterUtility sortNSMutableArrayOfPYEvents:removeArray sortAscending:YES];
                              
                              syncDetails([details objectForKey:kPYNotificationKeyAdd], removeArray,
                                          [details objectForKey:kPYNotificationKeyModify]);
                              filteredCachedEventList = nil;
                          }
                          NSLog(@"*afx3 B %f", [afx3 timeIntervalSinceNow]);
                      }
                        errorHandler:errorHandler
                  shouldSyncAndCache:YES];
    });
}



//GET /events

- (void)eventsOnlineWithFilter:(PYFilter*)filter
                successHandler:(void (^) (NSArray *eventList, NSNumber *serverTime, NSDictionary *details))successBlock
                  errorHandler:(void (^) (NSError *error))errorHandler
            shouldSyncAndCache:(BOOL)syncAndCache
{
    /*
     This method musn't be called directly (it's api support method). This method works ONLY in ONLINE mode
     This method doesn't care about current cache, it's interested in online events only
     It should retrieve always online events and need to cache (sync) online events (before caching sync unsyched, because we don't want to loose unsuc changes)
     */
    
    /*if there are events that are not synched with server, they need to be synched first and after that cached
     This method must be SYNC not ASYNC and this method sync events with server and cache them
     */
    if (syncAndCache == YES) {
# warning - change logic
        [self syncNotSynchedEventsIfAny:nil];
    }
    
    // shush if filter.onlyStreamIds = []
    if (filter && filter.onlyStreamsIDs && ([filter.onlyStreamsIDs count] == 0)) {
        NSLog(@"<WARNING> skipping online request filter.onlyStreamsIDs is empty");
        if (successBlock) {
            successBlock(@[], nil, @{kPYNotificationKeyAdd: @[],
                                     kPYNotificationKeyModify: @[],
                                     kPYNotificationKeyUnchanged: @[]});
        }
        return;
    }
    
    [self apiRequest:[PYClient getURLPath:kROUTE_EVENTS
                               withParams:[PYEventFilterUtility apiParametersForEventsRequestFromFilter:filter]]
              method:PYRequestMethodGET
            postData:nil
         attachments:nil
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *responseDict) {
                 
                 NSDate* afx2 = [NSDate date];
                 
                 NSArray *JSON = responseDict[kPYAPIResponseEvents];
                 
                 NSMutableArray *eventsArray = [[[NSMutableArray alloc] init] autorelease];
                 __block NSMutableArray* addArray = [[[NSMutableArray alloc] init] autorelease];
                 __block NSMutableArray* modifyArray = [[[NSMutableArray alloc] init] autorelease];
                 __block NSMutableArray* sameArray = [[[NSMutableArray alloc] init] autorelease];
                 
                 for (int i = 0; i < [JSON count]; i++) {
                     NSDictionary *eventDic = [JSON objectAtIndex:i];
                     
                     __block PYEvent* myEvent;
                     [self eventFromReceivedDictionary:eventDic
                                                create:^(PYEvent *event) {
                                                    myEvent = event;
                                                    [addArray addObject:event];
                                                } update:^(PYEvent *event) {
                                                    myEvent = event;
                                                    [modifyArray addObject:event];
                                                } same:^(PYEvent *event) {
                                                    myEvent = event;
                                                    [sameArray addObject:event];
                                                }];
                     
                     [eventsArray addObject:myEvent];
                 }
                 
                 NSLog(@"*afx2 A %f", [afx2 timeIntervalSinceNow]);
                 
                 [self.cache saveAllEvents];
                 //cacheEvents method will overwrite contents of currently cached file
                 [PYEventFilterUtility sortNSMutableArrayOfPYEvents:eventsArray sortAscending:YES];
                 [PYEventFilterUtility sortNSMutableArrayOfPYEvents:addArray sortAscending:YES];
                 [PYEventFilterUtility sortNSMutableArrayOfPYEvents:modifyArray sortAscending:YES];
                 [PYEventFilterUtility sortNSMutableArrayOfPYEvents:sameArray sortAscending:YES];
                 
                 NSDictionary* details = @{kPYNotificationKeyAdd: addArray,
                                           kPYNotificationKeyModify: modifyArray,
                                           kPYNotificationKeyUnchanged: sameArray};
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{kPYNotificationKeyAdd: addArray,
                                                                              kPYNotificationKeyModify: modifyArray,
                                                                              kPYNotificationKeyUnchanged: sameArray,
                                                                              kPYNotificationWithFilter: filter}];
                 if (successBlock) {
                     NSDictionary* meta = [responseDict objectForKey:@"meta"];
                     NSNumber* serverTime = [meta objectForKey:@"serverTime"];
                     successBlock(eventsArray, serverTime, details);
                     
                 }
                 NSLog(@"*afx2 B %f", [afx2 timeIntervalSinceNow]);
                 
             } failure:^(NSError *error) {
                 if (errorHandler) {
                     errorHandler (error);
                 }
             }];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (void) eventFromReceivedDictionary:(NSDictionary*) eventDic
                              create:(void(^) (PYEvent*event))create
                              update:(void(^) (PYEvent*event))update
                                same:(void(^) (PYEvent*event))same
{
    PYEvent* cachedEvent = [self.cache eventWithEventId:[eventDic objectForKey:@"id"]];
    if (cachedEvent == nil) // cache event
    {
        PYEvent *event = [PYEvent eventFromDictionary:eventDic onConnection:self];
        [self.cache cacheEvent:event addSaveCache:NO];
        // notify of event creation
        create(event);
        return;
    }
    cachedEvent.connection = self;
    
    // eventId is already known.. same event or modified ?
    NSNumber *modified = [eventDic objectForKey:@"modified"];
    if ([modified doubleValue] <= cachedEvent.modified) { // cached win
        same(cachedEvent);
        return;
    }
    [cachedEvent resetFromDictionary:eventDic];
    // notify of event update
    [self.cache cacheEvent:cachedEvent addSaveCache:NO];
    
    update(cachedEvent);
}

#pragma clang diagnostic pop
//POST /events
- (void)eventCreate:(PYEvent *)event
     successHandler:(void (^) (NSString *newEventId, NSString *stoppedId, PYEvent *event))successHandler
       errorHandler:(void (^)(NSError *error))errorHandler
{
    
    if (! event.connection) {
        event.connection = self;
    }
    if (event.connection != self)
    {
        return errorHandler([NSError
                             errorWithDomain:@"Cannot create PYEvent on API with an different connection"
                             code:500 userInfo:nil]);
    }
    if (event.eventId)
    {
        return errorHandler([NSError
                             errorWithDomain:@"Cannot create an already existing PYEvent"
                             code:500 userInfo:nil]);
    }
    
    
    // load filedata in attachment from cache if needed
    if (event.attachments) {
        for (PYAttachment* att in event.attachments) {
            if (! att.fileData || att.fileData.length == 0) {
                [self.cache dataForAttachment:att onEvent:event];
            }
        }
    }
    
    
    
    [self apiRequest:kROUTE_EVENTS
              method:PYRequestMethodPOST
            postData:[event dictionary]
         attachments:event.attachments
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *responseDict) {
                 NSDictionary* JSON = responseDict[kPYAPIResponseEvent];
                 
                 NSString *createdEventId = [JSON objectForKey:@"id"];
                 NSString *stoppedId = [JSON objectForKey:@"stoppedId"];
                 
#warning Hack until we get server time for untimed envent
                 if (event.eventDate == nil) {
                     [event setEventDate:[NSDate date]]; // now
                 }
                 
                 //--
                 [event resetFromDictionary:JSON];
                 
                 
                 event.synchedAt = [[NSDate date] timeIntervalSince1970];
                 event.eventId = createdEventId;
                 [event clearModifiedProperties]; // clear modified properties
                 [self.cache cacheEvent:event andCleanTempData:YES]; //-- remove eventual
                 
                 // notification
                 
                 // event is synchonized.. this mean it is already known .. so we advertise a modification..
                 NSString* notificationKey = event.isSyncTriedNow ? kPYNotificationKeyModify : kPYNotificationKeyAdd;
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{notificationKey: @[event]}];
                 
                 if (successHandler) {
                     successHandler(createdEventId, stoppedId, event);
                 }
                 
                 
             } failure:^(NSError *error) {
                 
                 if (! [PYErrorUtility isAPIUnreachableError:error]) { // this is an API error forward it
                     event.synchError = error; // set the event with
                     [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                         object:self
                                                                       userInfo:@{kPYNotificationKeySynchError: @[event]}];
                     
                     // if the event is at synch (already cached) and is faulty we should remove it from cache
                     if (event.isSyncTriedNow) [self.cache removeEvent:event];
                     
                     if (errorHandler) errorHandler(error);
                     return;
                 }
                 
                 // --- API Unreachable
                 
                 if (event.isSyncTriedNow) { // already synchronizing event creation -> skip
                     if (successHandler) successHandler (nil, @"", event);
                     return ;
                 }
                 
                 
                 // --- ADD to cache
                 
                 
                 if (! [event eventDate]) { // set a date if none
                     [event setEventDate:[NSDate date]]; // now
                 }
                 
                 
                 if (event.attachments.count > 0) {
                     for (PYAttachment *attachment in event.attachments) {
                         //  attachment.mimeType = @"mimeType";
                         attachment.size = [NSNumber numberWithUnsignedInteger:attachment.fileData.length];
                     }
                 }
                 [self.cache cacheEvent:event];
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{kPYNotificationKeyAdd: @[event]}];
                 
                 if (successHandler) {
                     successHandler (nil, @"", event);
                 }
             }
     
     ];
}

- (void)eventTrashOrDelete:(PYEvent *)event
            successHandler:(void (^)())successHandler
              errorHandler:(void (^)(NSError *error))errorHandler
{
    [event compareAndSetModifiedPropertiesFromCache];
    
    [self apiRequest:[NSString stringWithFormat:@"%@/%@",kROUTE_EVENTS, event.eventId]
              method:PYRequestMethodDELETE
            postData:nil
         attachments:nil
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, id responseValue) {
                 
                 if (event.trashed == YES) {
                     [self.cache removeEvent:event];
                 } else {
                     event.trashed = YES;
                     [self.cache cacheEvent:event];
                 }
                 
                 NSLog(@"It's event with server id because we'll never try to call this method if event has tempId");
                 
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{kPYNotificationKeyDelete: @[event]}];
                 
                 if (successHandler) {
                     successHandler();
                 }
                 
             } failure:^(NSError *error) {
                 
                 // tried to remove an unkown ressource
                 if ([@"unknown-resource" isEqualToString:[error.userInfo objectForKey:@"com.pryv.sdk:JSONResponseId"] ]) {
                     NSLog(@"<WARNING> tried to remove unkown object");
                     event.trashed = YES;
                     [self.cache removeEvent:event];
                     [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                         object:self
                                                                       userInfo:@{kPYNotificationKeyDelete: @[event]}];
                     
                     if (successHandler) successHandler();
                     return;
                 }
                 
                 
                 if (! [PYErrorUtility isAPIUnreachableError:error]) { // this is an API error forward it
                     event.synchError = error; // set the event with
                     [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                         object:self
                                                                       userInfo:@{kPYNotificationKeySynchError: @[event]}];
                     if (errorHandler) errorHandler(error);
                     return;
                 }
                 
                 if (event.isSyncTriedNow) { // skip if synchro is in course
                     if (errorHandler) errorHandler(error);
                     return;
                 }
                 
                 // -- edge case, we don't know (YET) how to synchronize events deleted offline, so we send an APIUnreachble Error
                 if (event.trashed) {
                     if (errorHandler) errorHandler(error);
                     NSLog(@"<WARNING> SDK doesn't know yet how to delete events offline");
                     return;
                 }
                 
                 
                 event.trashed = YES;
                 [self.cache cacheEvent:event];
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{kPYNotificationKeyDelete: @[event]}];
                 if (successHandler)  successHandler();
             }];
}

//PUT /events/{event-id}

- (void)eventSaveModifications:(PYEvent *)event
                successHandler:(void (^)(NSString *stoppedId))successHandler
                  errorHandler:(void (^)(NSError *error))errorHandler
{
    
    
    [event compareAndSetModifiedPropertiesFromCache];
    
#warning - attachments should be updated asside..
    
    [self apiRequest:[NSString stringWithFormat:@"%@/%@", kROUTE_EVENTS, event.eventId]
              method:PYRequestMethodPUT
            postData:[event dictionaryForUpdate]
         attachments:nil
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *responseDict) {
                 NSDictionary *JSON = responseDict[kPYAPIResponseEvent];
                 NSString *stoppedId = [JSON objectForKey:@"stoppedId"];
                 
                 event.synchedAt = [[NSDate date] timeIntervalSince1970];
                 [event clearModifiedProperties];
                 [self.cache cacheEvent:event ];
                 
                 [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                     object:self
                                                                   userInfo:@{kPYNotificationKeyModify: @[event]}];
                 
                 if (successHandler) {
                     NSString *stoppedIdToReturn;
                     if (stoppedId.length > 0) {
                         stoppedIdToReturn = stoppedId;
                     }else{
                         stoppedIdToReturn = @"";
                     }
                     successHandler(stoppedIdToReturn);
                 }
                 
             } failure:^(NSError *error) {
                 
                 
                 if (! [PYErrorUtility isAPIUnreachableError:error]) { // this is an API error forward it
                     event.synchError = error; // set the event with
                     [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                         object:self
                                                                       userInfo:@{kPYNotificationKeySynchError: @[event]}];
                     
                     // if the event is at synch (already cached) and is faulty we should remove it from cache
                     if (event.isSyncTriedNow) [self.cache removeEvent:event];
                     
                     if (errorHandler) errorHandler(error);
                     return;
                 }
                 
                 
                 if (event.isSyncTriedNow == NO) {
                     //Get current event with id from cache
                     [self.cache cacheEvent:event];
                     
                     [[NSNotificationCenter defaultCenter] postNotificationName:kPYNotificationEvents
                                                                         object:self
                                                                       userInfo:@{kPYNotificationKeyModify: @[event]}];
                     
                     if (successHandler) {
                         NSString *stoppedIdToReturn = @"";
                         successHandler(stoppedIdToReturn);
                         return ;
                     }
                     
                 }
                 
                 
                 if (errorHandler) {
                     errorHandler (error);
                 }
             }
     
     ];
}

//POST /events/start
- (void)eventStartPeriod:(PYEvent *)event
          successHandler:(void (^)(NSString *startedEventId))successHandler
            errorHandler:(void (^)(NSError *error))errorHandler
{
    [self apiRequest:[NSString stringWithFormat:@"%@/%@",kROUTE_EVENTS,@"start"]
              method:PYRequestMethodPOST
            postData:[event dictionary]
         attachments:event.attachments
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *responseDict) {
                 NSDictionary* JSON = responseDict[kPYAPIResponseEvent];
                 NSString *startedEventId = [JSON objectForKey:@"id"];
                 
                 if (successHandler) {
                     successHandler(startedEventId);
                 }
                 
             } failure:^(NSError *error) {
                 if (errorHandler) {
                     errorHandler (error);
                 }
             }];
    
}

//POST /events/stop
- (void)eventStopPeriodWithEventId:(NSString *)eventId
                            onDate:(NSDate *)specificTime
                    successHandler:(void (^)(NSString *stoppedEventId))successHandler
                      errorHandler:(void (^)(NSError *error))errorHandler
{
    
    NSMutableDictionary *postData = [[NSMutableDictionary alloc] init];
    
    [postData setObject:eventId forKey:@"id"];
    if (specificTime) {
        NSTimeInterval timeInterval = [specificTime timeIntervalSince1970];
        [postData setObject:[NSNumber numberWithDouble:timeInterval] forKey:@"time"];
        
    }
    
    [self apiRequest:[NSString stringWithFormat:@"%@/%@",kROUTE_EVENTS,@"stop"]
              method:PYRequestMethodPOST
            postData:[postData autorelease]
         attachments:nil
             success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *responseDict) {
                 NSString *stoppedEventId = responseDict[@"stoppedId"];
                 
                 if (successHandler) {
                     successHandler(stoppedEventId);
                 }
                 
             } failure:^(NSError *error) {
                 if (errorHandler) {
                     errorHandler (error);
                 }
             }];
    
}

# pragma mark - event attachment


- (void)dataForAttachment:(PYAttachment *)attachment
                  onEvent:(PYEvent *)event
           successHandler:(void (^) (NSData * filedata))success
             errorHandler:(void (^) (NSError *error))errorHandler
{
    
    //---- got it from cache
    
    NSData *cachedData = [self.cache dataForAttachment:attachment onEvent:event];
    if (cachedData && cachedData.length > 0) {
        success(cachedData);
        return;
    }
    
    
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@",kROUTE_EVENTS, event.eventId, attachment.attachmentId];
    NSString *urlPath = [path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    
    
    NSString* fullPath = [NSString stringWithFormat:@"%@://%@%@:%@/%@", self.apiScheme, self.userID, self.apiDomain, @(self.apiPort), urlPath];
    
    NSURL *url = [NSURL URLWithString:fullPath];
    
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
    [request setValue:self.accessToken forHTTPHeaderField:@"Authorization"];
    [request setURL:url];
    [request setHTTPMethod:@"GET"];
    request.timeoutInterval = 60.0f;
    
    [PYClient apiRawRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSMutableData *result) {
        if (success) {
            NSLog(@"*66 %@ %@", @([result length]), url);
            success(result);
            
            attachment.fileData = result;
            [self.cache saveDataForAttachment:attachment onEvent:event];
        }
    } failure:errorHandler];
}

- (void)previewForEvent:(PYEvent *)event
         successHandler:(void (^) (NSData * content))success
           errorHandler:(void (^) (NSError *error))errorHandler
{
    
    
    //---- got it from cache
    
    NSData *cachedData = [self.cache previewForEvent:event];
    if (cachedData) {
        if (success) { success(cachedData);}
        return;
    }
    
    if (! event.eventId) {
        if (success) { success(nil);}
        return;
    }
    
    
    
    NSString *path = [NSString stringWithFormat:@"%@/%@?w=512",kROUTE_EVENTS, event.eventId];
    NSString *urlPath = [path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    
    
    
    NSString* fullPath = [NSString stringWithFormat:@"%@://%@%@:%i/%@", self.apiScheme, self.userID, self.apiDomain, 3443, urlPath];
    
    NSURL *url = [NSURL URLWithString:fullPath];
    
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
    [request setValue:self.accessToken forHTTPHeaderField:@"Authorization"];
    [request setURL:url];
    [request setHTTPMethod:@"GET"];
    request.timeoutInterval = 60.0f;
    
    [PYClient apiRawRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSMutableData *result) {
        if (success) {
            NSLog(@"*77 %@ %@", @([result length]), url);
            [self.cache savePreview:result forEvent:event];
            success(result);
            
        }
    } failure:^(NSError *error) {
        errorHandler(error);
        
    }];
}



@end