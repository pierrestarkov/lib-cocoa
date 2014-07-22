//
//  PYEvent+JSON.h
//  PryvApiKit
//
//  Created by Nenad Jelic on 4/6/13.
//  Copyright (c) 2013 Pryv. All rights reserved.
//

#import "PYEvent.h"

@class PYConnection;
@class PYEvent;

@interface PYEvent (JSON)

/**
 * reset content of this event with this dictionary (not clientId nor eventId)
 */
- (void)resetFromDictionary:(NSDictionary *)JSON;


/**
 Get PYEvent object from json dictionary representation (JSON representation can include additioanl helper properties for event). It means that this method 'read' event from disk and from server
 */
+ (PYEvent*)eventFromDictionary:(NSDictionary *)JSON onConnection:(PYConnection *)connection;

@end
