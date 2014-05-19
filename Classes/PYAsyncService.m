//
//  PYAsyncService.m
//  PryvApiKit
//
//  Created by Nenad Jelic on 4/15/13.
//  Copyright (c) 2013 Pryv. All rights reserved.
//

#import "PYAsyncService.h"
#import "PYJSONUtility.h"
#import "PYClient.h"
#import "PYError.h"

@interface PYAsyncService ()

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, retain) NSMutableData *responseData;

@property (nonatomic) BOOL running;
@property (nonatomic) PYRequestResultType requestResultType;

@property (nonatomic, copy) PYAsyncServiceSuccessBlock onSuccess;
@property (nonatomic, copy) PYAsyncServiceFailureBlock onFailure;


@end

@implementation PYAsyncService

@synthesize responseData = _responseData;
@synthesize connection = _connection;
@synthesize request = _request;
@synthesize response = _response;
@synthesize running = _running;
@synthesize onFailure = _onFailure;
@synthesize onSuccess = _onSuccess;
@synthesize requestResultType = _requestResultType;

- (void)dealloc
{
    [_request release];
    _request = nil;
    [_response release];
    _response = nil;
    
    [_onSuccess release];
    [_onFailure release];
    [_connection release];
    //[_responseData release];
    
    
    [super dealloc];
}

- (id)initWithRequest:(NSURLRequest *)request
{
    self = [super init];
    if (self) {
        // create the connection with the request
        // and start loading the data asynchronously
        self.request = request;
        self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        if (_connection) {
            // Create the NSMutableData to hold the received data.
            // receivedData is an instance variable declared elsewhere.
            _responseData = [[NSMutableData data] retain];
            _running = YES;
        } else {
            NSLog(@"<ERROR> PYAsyncService.initWithRequest failed to create an NSURLConnection");
        }
        
    }
    
    return self;
}


+ (void)RAWRequestServiceWithRequest:(NSURLRequest *)request
                             success:(PYAsyncServiceSuccessBlock)success
                             failure:(PYAsyncServiceFailureBlock)failure
{
    PYAsyncService *requestOperation = [[[self alloc] initWithRequest:request] autorelease];
    
    [requestOperation setCompletionBlockWithSuccess:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSMutableData *responseData) {
        if (success) {
            success (req, resp, responseData);
        }
    } failure:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSError *error, id responseData) {
        if (failure) {
            failure (req, resp, error, responseData);
        }
    }];
    
}


+ (void)JSONRequestServiceWithRequest:(NSURLRequest *)request
                              success:(PYAsyncServiceSuccessBlockJSON)success
                              failure:(PYAsyncServiceFailureBlock)failure
{
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        PYAsyncService *requestOperation = [[[self alloc] initWithRequest:request] autorelease];
        [requestOperation setCompletionBlockWithSuccess:^(NSURLRequest *req, NSHTTPURLResponse *resp,  NSMutableData *responseData) {
            if (success) {
                
                id JSON = [PYJSONUtility getJSONObjectFromData:responseData];
                if (JSON == nil) { // Is not NSDictionary or NSArray
                    if ([resp statusCode] == 204) {
                        // NOTE: special case - Deleting trashed events returns zero length content
                        // maybe need to handle it somewhere else
                        JSON = [[[NSDictionary alloc] init] autorelease];
                    } else {
                        NSDictionary *errorInfoDic = @{ @"message" : @"Data is not JSON"};
                        NSError *error =  [NSError errorWithDomain:PryvErrorJSONResponseIsNotJSON code:PYErrorUnknown userInfo:errorInfoDic];
                        failure (req, resp, error, responseData);
                        return;
                    }
                }
                success (req, resp, JSON);
            }
        } failure:^(NSURLRequest *req, NSHTTPURLResponse *resp, NSError *error, NSMutableData *responseData) {
            if (failure) {
                failure (req, resp, error, responseData);
            }
        }];
        
        
    });
    
}

- (void)setCompletionBlockWithSuccess:(PYAsyncServiceSuccessBlock)success
                              failure:(PYAsyncServiceFailureBlock)failure
{
    self.onSuccess = success;
    self.onFailure = failure;
    [self.connection start];
}

- (void)stop
{
	[_connection cancel];
	
	if (_running)
	{
		self.request = nil;
		_running = NO;
		
	}
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    [_responseData setLength:0];
    
    self.response = (NSHTTPURLResponse *)response;
    
    
    
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [_responseData appendData:data];
    
    //    float progress = data.length / _response.expectedContentLength;
    
}


- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    // receivedData is declared as a method instance elsewhere
    [_responseData release];
    
    self.request = nil;
    
    _running = NO;
    
    // inform the user
    //    NSLog(@"Connection failed! Error - %@ %@",
    //          [error localizedDescription],
    //          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    if (self.onFailure){
        self.onFailure(self.request, self.response, error, nil);
    }
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    //NSLog(@"Succeeded! Received %d bytes of data",[_responseData length]);
    _running = NO;
    
    BOOL isUnacceptableStatusCode = [PYClient isUnacceptableStatusCode:self.response.statusCode];
    
    if (isUnacceptableStatusCode)
	{
        NSError *e = [NSError errorWithDomain:@"HTTP URL Connection is unacceptable status code" code:self.response.statusCode userInfo:nil];
        if (self.onFailure){
            self.onFailure(self.request, self.response, e, self.responseData);
        }
        // release the connection, and the data object
        [connection release];
        [_responseData release];
        
        return;
	}
    
    if (self.onSuccess)
    {
        self.onSuccess(self.request, self.response, self.responseData);
    }
    
    // release the connection, and the data object
    [connection release];
    [_responseData release];
}


@end
