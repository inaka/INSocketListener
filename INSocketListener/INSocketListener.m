//
//  INSocketListener.m
//  INSocketListener
//
//  Created by toms on 29/06/13.
//  Copyright (c) 2013 Inaka Labs. All rights reserved.
//

#import "INSocketListener.h"
#import "GCDAsyncSocket.h"
#import "Reachability.h"
#import "NSData+MKBase64.h"

#define SOCKET_TIMEOUT 300
#define BACKOFF_WAIT_MIN 1
#define BACKOFF_WAIT_MAX 64

@interface INSocketListener ()
@property BOOL isConnected;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) Reachability *reachability;
@property CGFloat waitTime;

- (void)attachToNewServer:(NSString *)server port:(NSInteger)port;
@end

@implementation INSocketListener

- (id)initWithServer:(NSString *)server port:(NSInteger)port delegate:(id<INSocketDelegate>)delegate {
	self = [super init];
	if(self) {
		self.server = server;
		self.port = port;
		self.delegate = delegate;
		self.waitTime = BACKOFF_WAIT_MIN;
		dispatch_queue_t mainQueue = dispatch_queue_create("com.socketlistener.socketqueue", NULL);
		self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
		[self.socket setIPv6Enabled:NO];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
	}
	return self;
}

- (void)connect {
	if(!self.socket.isConnected) {
		if(!self.socket.delegate) {
			self.socket.delegate = self;
		}
		[self attachToNewServer:self.server port:self.port];
	}
}

- (void)reconnect {
	[self disconnect];
	[self connect];
}

- (void)disconnect {
	if(self.socket.isConnected) {
		self.socket.delegate = nil;
		[self.socket disconnect];
	}
}

- (void)attachToNewServer:(NSString *)server port:(NSInteger)port {
	if(![self.server isEqualToString:server]) {
		self.server = server;
		self.port = port;
	}
	NSError *error = NULL;
	if(![self.socket connectToHost:self.server onPort:self.port error:&error]) {
		NSLog(@"Error Connecting to server %@:%i", self.server, self.port);
	}
}

- (void)authenticateWithKey:(NSString *)key secret:(NSString *)secret {
	NSString *authString = [NSString stringWithFormat:@"%@:%@", key, secret];
	NSLog(@"Auth String: %@", authString);
	
	NSData *authData = [authString dataUsingEncoding:NSASCIIStringEncoding];
	NSMutableString *headerString = [NSMutableString string];
	[headerString appendFormat:@"GET %@ HTTP/1.1\n", self.endpointPath];
	[headerString appendFormat:@"Host: %@:%i\n", self.server, self.port];
	[headerString appendString:@"Accept: */*\n"];
	for(NSString *headerKey in [self.headers allKeys]) {
		[headerString appendFormat:@"%@: %@\n", headerString, self.headers[headerKey]];
	}
	[headerString appendFormat:@"Authorization: Basic %@\n\n", authString];//[authData base64EncodedString]];
	
	NSData *sendData = [headerString dataUsingEncoding:NSASCIIStringEncoding];
	[self.socket writeData:sendData withTimeout:15 tag:234];
	[self.socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:15 tag:-1];
}

#pragma mark - AsyncSocket Delegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    self.waitTime = BACKOFF_WAIT_MIN;
    [self.socket writeData:[[self authenticationString] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:0 tag:1];
    [self.socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:SOCKET_TIMEOUT tag:-1];
	
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    NSLog(@"whisper socket did secure");
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"Whisper socket did write data.");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	NSLog(@"Reading Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
	if(self.delegate) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSError *error = nil;
			id responseData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
			[self.delegate handleResponse:responseData];
		});
	}
    [self.socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:-1];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.waitTime = MIN(1.2 * self.waitTime, BACKOFF_WAIT_MAX);
    NSLog(@"Socket did disconnect: %@, %@", err, err.userInfo);
	if(self.delegate && [self.delegate respondsToSelector:@selector(handleError:)]) {
		[self.delegate handleError:err];
	}
	//#warning Whisper socket retry connection disabled for superuser
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        sleep(self.waitTime);
        [self attachToNewServer:self.server port:self.port];
    });
}

#pragma mark - Reachability
-(void) reachabilityChanged:(NSNotification*) notification
{
    if([self.reachability currentReachabilityStatus] == ReachableViaWiFi)
    {
		[self attachToNewServer:self.server port:self.port];
    }
    else if([self.reachability currentReachabilityStatus] == ReachableViaWWAN)
    {
		[self attachToNewServer:self.server port:self.port];
    }
    else if([self.reachability currentReachabilityStatus] == NotReachable)
    {
		if(self.socket) 	[self.socket disconnect];
    }
}


#pragma mark -
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}
@end
