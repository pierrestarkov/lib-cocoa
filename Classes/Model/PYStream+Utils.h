//
//  PYStream+Utils.h
//  Pods
//
//  Created by Perki on 04.04.14.
//
//

#import "PYStream.h"

@interface PYStream (Utils)




/**
 * fill an NSDictonary with all Streams in the tree strucure index by their streamids.
 * If a stream is already present it won't be added to the Dictionary
 */
+ (void)fillNSDictionary:(NSMutableDictionary*)dict withStreamsStructure:(NSArray*)rootStreams;


+ (void)fillNSMutableArray:(NSMutableArray*)array
   withIdAndChildrensIdsOf:(PYStream*)stream;

/**
 * get the childrens ids of this stream
 */
- (NSArray*)descendantsIds;

/**
 * add a children
 */
- (void)addChildren:(PYStream*)stream;

/**
 * find a stream by id. 
 * The search on names is case insensitive
 */
+ (PYStream*)findStreamMatchingId:(NSString*)streamId orNames:(NSArray*)namesList onList:(NSArray*)streamsList;



@end
