//
//  PYConnection+FetchedStreams.h
//  Pods
//
//  Created by Perki on 04.04.14.
//
//

#import <Foundation/Foundation.h>
#import "PYConnection.h"

@interface PYConnection (FetchedStreams)

/** return true if streams have been fetched **/
- (BOOL)hasFetchedStreams;

/** return the stream instance corresponding to this streamId or streamsCLientId **/
- (PYStream*)streamWithStreamId:(NSString*)streamId;

/** reset fetched Streams **/
- (void) updateFetchedStreams:(NSArray*)streams;

@end
