# Pryv iOS/OSX Cocoa SDK [![Build Status](https://travis-ci.org/pryv/sdk-objectivec-apple.svg?branch=master)](https://travis-ci.org/pryv/sdk-objectivec-apple)  [![Coverage Status](https://coveralls.io/repos/dkonst/sdk-objectivec-apple/badge.png)](https://coveralls.io/r/dkonst/sdk-objectivec-apple)


**PryvApiKit is an OS X framework and an iOS static library. It handles all networking and interactions with Pryv API for your Objective-C based applications.**


**Note PYRequestType Sync / Async will be removed and all request will be made using Async method **

## PryvApiKit.framework

This framework Mac OS X lets you interact with the Pryv servers from your Mac OS X application.
First of all, you need to create a WebView object `myWebView` that you locate in a window, a panel, a view or whatever you think will be appropriate and make one of your controller a `PYWebLoginDelegate` – typically, the WebView controller. You can then obtain your access token with your app ID using the following lines.

```objective-c
NSArray *objects = [NSArray arrayWithObjects:@"*", @"manage", nil];
NSArray *keys = [NSArray arrayWithObjects:@"StreamId", @"level", nil];
NSArray *permissions = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjects:objects forKeys:keys]];
```

After this preparation, you actually request an access token with these two lines:

```objective-c
[PYClient setDefaultDomainStaging];
[PYWebLoginViewController requestConnectionWithAppId:@"pryv-sdk-osx-example"
                                      andPermissions:permissions
                                            delegate:self
                                         withWebView:&myWebView];
```                                          
        
The first one is needed whenever you need to (re-)log a user. Notice in the second method that you pass the reference of your WebView object which will be displayed where you located it asking for username and password. If everything went good, you'll manage the response in the delegate method :

```objective-c
- (void) pyWebLoginSuccess:(PYConnection*)pyConnection {
    NSLog(@"Signin With Success %@ %@",pyConnection.userID,pyConnection.accessToken);
    [pyConnection synchronizeTimeWithSuccessHandler:nil errorHandler:nil];
}
```
    	
Otherwise, you can manage abortion and error using the methods `- (void) pyWebLoginAborted:(NSString*)reason` and `- (void) pyWebLoginError:(NSError*)error`.

## LibPryvApiKit.a
This is a static library to be used for iOS. Usage is pretty straightforward. First of all, you need to obtain access token. To achieve this, you should set up a permission array in which you specify what streams you need and what access for those streams you ask for, like this :

```objective-c
NSArray *objects = [NSArray arrayWithObjects:@"*", @"manage", nil];
NSArray *keys = [NSArray arrayWithObjects:@"StreamId", @"level", nil];
    
NSArray *permissions = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjects:objects forKeys:keys]];
```
After this preparation, you actually request for an access token using this method :
	
```objective-c
[PYClient setDefaultDomainStaging];
[PYWebLoginViewController requestConnectionWithAppId:@"pryv-sdk-ios-example"
                                 andPermissions:permissions
                                       delegate:self];
```

The first line is needed whenever you need to (re-)log a user. Here you are sending the `appId` and an array of permissions. An instance of `UIWebView` will pop up and will ask the user for username and password. If everything went ok, you'll get response in the delegate method.

```objective-c
- (void) pyWebLoginSuccess:(PYConnection*)pyConnection {
    NSLog(@"Signin With Success %@ %@",pyConnection.userID,pyConnection.accessToken);
    [pyConnection synchronizeTimeWithSuccessHandler:nil errorHandler:nil];
}
```
	
Otherwise, you can manage abortion and error using the methods `- (void) pyWebLoginAborted:(NSString*)reason` and `- (void) pyWebLoginError:(NSError*)error`.



## PryvApiKit 

*Compatible with iOS and Mac OS X.*

### Inits

##### FIXME

```objective-c
/** refresh stream list **/
[connection refreshStreams:^done]
```

### Calls

##### FIXME

```objective-c
/** get latest stream structure fetched **/
NSArray *currentStreams = connection.currentStreams;
```


### Notifications

#### PYConnection

- name: "EVENTS"
  **userInfo**

- name: "EVENTS"   
  **userInfo**  
  

`NSDictionary = @{ kPYNotificationKeyAdd : NSArray of PYEvents, 
                 kPYNotificationKeyModify : ...
                 kPYNotificationKeyDelete : ... }`
  
- name: "STREAMS"
  **userInfo**  
  
`NSArray of (root) PYStreams`

complete structure of streams is accessible thru childrens
  
- name: "LOADING"
  **userInfo**  
  
`NSDictionary = @{ kPYNotificationKeyAdd : @"BEGIN" or @"END", 
                 @"CALL" : @"STREAMS" or kPYNotificationEvents or @"PROFILE" ... (API key) }`




#### PYFilter

- name: "EVENTS"   
  **userInfo**  
  
```objective-c
NSDictionary = @{ kPYNotificationKeyAdd : NSArray of PYEvents, 
                 kPYNotificationKeyModify : ...
                 kPYNotificationKeyDelete : ... }
```
 


###### streams

```objective-c
[[NSNotificationCenter defaultCenter] addObserverForName:@"STREAMS"
                                                  object:connection
                                                   queue:nil
                                              usingBlock:^(NSNotification *note) {
	NSDictionary *message = (NSDictionary*) note.userInfo;
    NSArray *streams = [message objectForKey:@"STREAMS"];
		//...
    }];

// shortcut for the above
[connection addObserverForStreams:^(NSArray *streams) { 
    // ... 
}];
```

###### events

```objective-c
PYEventFilter* pyFilter = [[PYEventFilter alloc] initWithConnection:self.connection
                                                               fromTime:PYEventFilter_UNDEFINED_FROMTIME
                                                                 toTime:PYEventFilter_UNDEFINED_TOTIME
                                                                  limit:20
                                                         onlyStreamsIDs:nil
                                                                   tags:nil];
                                                               
[[NSNotificationCenter defaultCenter] addObserverForName:kPYNotificationEvents
                                                  object:pyFilter
                                                   queue:nil
                                              usingBlock:^(NSNotification *note)
     {
	NSDictionary *message = (NSDictionary*) note.userInfo;
         NSArray *toAdd = [message objectForKey:kPYNotificationKeyAdd];
         if (toAdd && toAdd.count > 0) {
             NSLog(@"ADD %i", toAdd.count);
         }
         NSArray *toRemove = [message objectForKey:kPYNotificationKeyDelete];
         if (toRemove) {
             NSLog(@"REMOVE %i", toRemove.count);
         }
         NSArray *modify = [message objectForKey:kPYNotificationKeyModify];
         if (modify) {
             NSLog(@"MODIFY %i", modify.count);
         }
	}]

// shortcut with the same effect than previous code
[pyFilter addObserverForEvents:^(NSArray *toAdd, NSArray *modify, NSArray *toRemove) { ... }]

[pyFilter refresh]; // refresh once

[pyFilter autoRefresh:30000]; // time in miliseconds
```

### Main Methods


The user ID and the access token are used for creating PYConnection object.

```objective-c
PYConnection *access = [PYClient createAccessWithUsername:@"username" andAccessToken:@"accessToken"];
```

With `PYConnection` objects, you can browse Streams, streams and events with the permissions you have in access token.

```objective-c
[Connection getAllStreamsWithRequestType:PYRequestTypeAsync gotCachedStreams:^(NSArray *cachedStreamList) {

} gotOnlineStreams:^(NSArray *onlineStreamList) {

} errorHandler:^(NSError *error) {

}];
```


This library can work offline if caching is enabled. To enable/disable caching possibility you set the preprocessor macro `CACHE` in project file to 1/0 depending on whether or not you want caching support.

`cachedStreamList` and `onlineStreamList` contain `PYStream` objects. A Stream il linked to `PYStream` children and `PYEvent` objects.

You can manipulate streams and events. For example, you can create, delete, modify, …. Same rules applie for other object types. Currently only personal type of access allows creating Streams and it will be added for v2 of SDK when access-rights will be covered in depth.






### Some useful `PYConnection` methods:

Example of getting all events:

`filter:nil` means **no** filer, so all events.

```objective-c
[connection getEventsWithRequestType:PYRequestTypeAsync filter:nil
gotCachedEvents:^(NSArray *cachedEventList) {
    
} gotOnlineEvents:^(NSArray *onlineEventList) {
    
} successHandler:^(NSArray *eventsToAdd, NSArray *eventsToRemove, NSArray *eventModified) {
    
} errorHandler:^(NSError *error) {
    
}];
```


Example of creating event on server:

```objective-c
PYEvent *event = [[PYEvent alloc] init];
event.streamId = @"someStreamId";
event.value = @"someEventValue";
event.eventClass = @"note";
event.eventFormat = @"txt";
event.tags = @[@"tag1", @"tag2", @"tag3"];
event.clientData = @{@"clDataKey": @"clientDataObject"};

[connection createEvent:event
         requestType:PYRequestTypeAsync
      successHandler:^(NSString *newEventId, NSString *stoppedId) {
    
} errorHandler:^(NSError *error) {
    
}];
```
                
Example of modifying event data on server. You create an event object with the properties you want to modify. In the example below, we are sending events with id "someEventId" to stream with id "someStreamId" and we are changing event `value` property.

```objective-c
PYEvent *event = [[PYEvent alloc] init];
event.streamId = @"someStreamId";
event.value = @"someEventValue";

[connection updateEvent:event
                           successHandler:^(NSString *stoppedId) {
    
} errorHandler:^(NSError *error) {
    
}];
```


Example of getting events from server with filter. This particular filter will search for events recorded in the last 60 days, ones that are in specific `streamId` and tagged with `tag2`. List of events will be limited to 10 results. If caching is enabled for library it will automatically sync events with ones from cache and give you result of synchronization.

```objective-c
NSDate *today = [NSDate date];
NSCalendar *cal = [NSCalendar currentCalendar];
NSDateComponents *components = [[NSDateComponents alloc] init];
[components setDay:-60];
NSDate *fromTime = [cal dateByAddingComponents:components toDate:today options:0];
NSDate *toTime = today;
PYEventFilter *eventFilter = [[PYEventFilter alloc] initWithConnection:connection
                                                          fromTime:[fromTime timeIntervalSince1970]
                                                            toTime:[toTime timeIntervalSince1970]
                                                             limit:10
                                                    onlyStreamsIDs:@[@"streamId"]
                                                              tags:@[@"tag2"]];
[eventFilter getEventsWithRequestType:PYRequestTypeSync gotCachedEvents:^(NSArray *eventList) {
   NSLog(@"cached eventList %@",eventList);
} gotOnlineEvents:^(NSArray *eventsToAdd, NSArray *eventsToRemove, NSArray *eventModified) {
   NSLog(@"eventsToAdd %@",eventsToAdd);
   NSLog(@"eventsToRemove %@",eventsToRemove);
   NSLog(@"eventModified %@",eventModified);
} errorHandler:^(NSError *error) {
   NSLog(@"error is %@",error);
}];
```

In a similar way, you manipulate streams.

Getting all streams from current Stream:

```objective-c
[connection getAllStreamsWithRequestType:PYRequestTypeAsync
                         filterParams:nil
                     gotCachedStreams:^(NSArray *cachedStreamsList) {

} gotOnlineStreams:^(NSArray *onlineStreamList) {

} errorHandler:^(NSError *error) {

}];
```

Creating stream in current Stream:

```objective-c
PYStream *stream = [[PYStream alloc] init];
stream.name = @"someStreamName";
            
[connection createStream:stream withRequestType:PYRequestTypeAsync successHandler:^(NSString *createdStreamId) {
    
} errorHandler:^(NSError *error) {
    
}];
```

If you want to change name of previously created stream above, you do this :

```objective-c
PYStream *stream = [[PYStream alloc] init];
stream.name = @"someStreamNameChanged";
[connec setModifiedStreamAttributesObject:stream
                               forStreamId:createdStreamId
                               requestType:PYRequestTypeAsync successHandler:^{
    
} errorHandler:^(NSError *error) {
    
}];
```

You can trash/delete stream in this way:

```objective-c
[connection trashOrDeleteStreamWithId:createdStreamId filterParams:nil withRequestType:PYRequestTypeAsync successHandler:^{
    
} errorHandler:^(NSError *error) {
    
}];
```

### Some words about caching
If caching is enabled for library, Streams, streams or events requested from server will be cached automatically. If you want to create an event and you get successful response, that event will be cached automatically for you. Same rules apply for other types. If you are offline, the library still works. All Streams, streams or events will be cached on disk with tempId and will be put in unsync list. When internet turns on, the unsync list will be synched with server and all events, streams or Streams will be cached automatically. Developers don't need to care about caching, all process about it is done in background. Developers should use public API methods as usual. From my pov I'll rather take out `gotCachedStreams` `gotCachedEvents` and `gotCachedStreams` callbacks because I think it's unnecessary. Everything can be in one callback… Perki, what do you think about it?

Also, there are some testing classes that are testing whether or not Objective-C public API works with web service. To perform those tests start iOS example in simulator first. After this step, stop the simulator and choose libPryvApiKit.a scheme. Go to Product->Test in xCode.


# Use cases

## Editing an event with an eventual rollback

#### If the event is a draft `event.isDraft` (ie `event.hasTempId && !event.toBeSync`)

- Rollback: Event just have to be thrown away in case of cancel.
- Save: `[connection createEvent:event ......]`

#### If the event is not a draft, the properties of the event have been cached.

- Rollback: `[event resetFromCache]`
- Save: `[connection updateEvent:event ......]`

**Note:** there is a fallback with this method. Until data is reset changes are done on app-wide instance of the event. We may at some point need a logic with  `PYEvent *backupEvent = [event backup] ; [event restoreFromBackup:backupEvent]`



# License

[Revised BSD license](https://github.com/pryv/documents/blob/master/license-bsd-revised.md)
