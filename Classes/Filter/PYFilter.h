//
//  PYEventFilter.h
//  PryvApiKit
//
//  Created by Pierre-Mikael Legris on 30.05.13.
//  Copyright (c) 2013 Pryv. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import "PYAPIConstants.h"


@class PYConnection;

#define PYEventFilter_UNDEFINED_FROMTIME -DBL_MAX
#define PYEventFilter_UNDEFINED_TOTIME DBL_MAX

typedef enum {
    PYEventFilter_kStateDefault,
    PYEventFilter_kStateTrashed,
    PYEventFilter_kStateAll
} PYEventFilter_kState;
extern NSString * const PYEventFilter_kStateArray[];

@interface PYFilter : NSObject
{
    PYConnection *_connection;
    NSTimeInterval _fromTime;
    NSTimeInterval _toTime;
    NSUInteger _limit;
    NSArray *_onlyStreamsIDs; // of strings
    NSArray *_tags;
    NSArray *_types;
    NSTimeInterval _modifiedSince;
}

@property (readonly, nonatomic, retain) PYConnection *connection;
@property (nonatomic) NSTimeInterval fromTime;
@property (nonatomic) NSTimeInterval toTime;
@property (nonatomic) NSUInteger limit;
@property (nonatomic, retain) NSArray *onlyStreamsIDs;
@property (nonatomic, retain) NSArray *tags;
@property (nonatomic, retain) NSArray *types;
@property (nonatomic) PYEventFilter_kState state;


@property (nonatomic, retain, readonly) NSMutableDictionary *currentEventsDic;

/** double value serverTime **/
@property (nonatomic) NSTimeInterval modifiedSince;


/**
 * @param fromTime use PYEventFilter_UNDEFINED_FROMTIME when undefined
 * @param toTime use PYEventFilter_UNDEFINED_TOTIME when undefined
 * @param onlyStreamsIDs array of strings with StreamsIDs, nil for no match
 * @param tags array of strings with tags, nil for no match
 * @param type array of strings with typefilters, such as 'position/wgs84' or 'note/\*', nil for no match
 * @param limit number of events may be 2x > to the limit if cached events are totally differents than online events, 0 or negative for ALL
 */
- (id)initWithConnection:(PYConnection *)connection
                fromTime:(NSTimeInterval)fromTime
                  toTime:(NSTimeInterval)toTime
                   limit:(NSUInteger)limit
          onlyStreamsIDs:(NSArray *)onlyStreamsIDs
                    tags:(NSArray *)tags
                   types:(NSArray *)types;

- (void)changeFilterFromTime:(NSTimeInterval)fromTime
                      toTime:(NSTimeInterval)toTime
                       limit:(NSUInteger)limit
              onlyStreamsIDs:(NSArray *)onlyStreamsIDs
                        tags:(NSArray *)tags
                       types:(NSArray *)types;


- (void)changeFilterFromTime:(NSTimeInterval)fromTime
                      toTime:(NSTimeInterval)toTime
                       limit:(NSUInteger)limit
              onlyStreamsIDs:(NSArray *)onlyStreamsIDs
                        tags:(NSArray *)tags;



@end
