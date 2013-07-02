//
//  INSocketServer.m
//  INSocketServer
//
//  Created by toms on 01/07/13.
//  Copyright (c) 2013 Inaka Labs. All rights reserved.
//

#import "INSocketServer.h"
#import "GCDAsyncSocket.h"

#define READ_TIMEOUT 15.0
#define READ_TIMEOUT_EXTENSION 10.
#define ECHO_MSG 1
#define WARNING_MSG 2

@interface INSocketServer ()
@property (nonatomic, strong) NSMutableArray *connectedSockets;
@property (nonatomic, strong) GCDAsyncSocket *listenSocket;
@property long listenPort;
@property NSInteger counter;
@property BOOL isRunning;

- (NSData *)formatJSON:(id)incoming;
@end

@implementation INSocketServer

- (id)initWithPort:(NSInteger)port delegate:(id<INSocketDelegate>)delegate {
	self = [super init];
	if(self) {
		self.port = port;
		self.socketDelegate = delegate;
		self.connectedSockets = [NSMutableArray array];
		dispatch_queue_t mainQueue = dispatch_queue_create("socketQueue", NULL);
		self.listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
	}
	return self;
}

- (void)start {
	if(!self.isRunning) {
		NSError *error = nil;
		if([self.listenSocket acceptOnPort:self.port error:&error]) {
			self.listenPort = [self.listenSocket localPort];
			self.isRunning = YES;
		}
	} 
}

- (void)stop {
	[self.listenSocket disconnect];
	for(NSUInteger i = 0;i<[self.connectedSockets count];i++) {
		[[self.connectedSockets objectAtIndex:i] disconnect];
	}
	self.isRunning = NO;
}

- (NSData *)formatJSON:(id)incoming {
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:incoming options:NSJSONWritingPrettyPrinted error:&error];
	NSString *retString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByAppendingString:@"\r\n"];
	return [retString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)sendJSON:(NSString *)jsonString tag:(NSInteger)tag {
	NSString *retString = [jsonString stringByAppendingString:@"\r\n"];
	NSData *data = [retString dataUsingEncoding:NSUTF8StringEncoding];
	for(GCDAsyncSocket *socket in self.connectedSockets) {
		[socket writeData:data withTimeout:-1 tag:tag];
		[socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:0 tag:0];
	}
	[self.listenSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:0 tag:0];
}

#pragma mark - AsyncSocket
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
	@synchronized(self.connectedSockets)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.connectedSockets addObject:newSocket];
		});
	}
	
	NSString *host = [newSocket connectedHost];
	UInt16 port = [newSocket connectedPort];

	NSLog(@"Accepted client %@:%hu", host, port);
	NSString *welcomeMsg = @"CONNECTED\r\n";
	NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
	
	[newSocket writeData:welcomeData withTimeout:-1 tag:1110];
	
	[newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];	
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
	NSLog(@"Wrote some data: %li", tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSLog(@"Read some data: %li", tag);
		[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
		NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length]-2)];
		//NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
		id jsonResponse = [NSJSONSerialization JSONObjectWithData:strData options:NSJSONReadingAllowFragments error:NULL];
		if(self.socketDelegate) {
			[self.socketDelegate handleResponse:jsonResponse];
		}
		
	});
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length
{
	if (elapsed <= READ_TIMEOUT)
	{
		NSString *warningMsg = @"shouldTimeout?\r\n";
		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
		
		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
		[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
		return READ_TIMEOUT_EXTENSION;
	}
	//return READ_TIMEOUT_EXTENSION;
	return 0.0;
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
	NSString *host = [sock connectedHost];
	UInt16 port = [sock connectedPort];
	
	//dispatch_async(dispatch_get_main_queue(), ^{
	NSLog(@"disconnecting client %@:%hu", host, port);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"Disconnecting Socket");
	if (sock != self.listenSocket)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			@autoreleasepool {
				
				NSLog(@"Disconnecting: %@\n%@", err, [err userInfo]);
				
			}
		});
		
		@synchronized(self.connectedSockets)
		{
			NSLog(@"Remoing a socket");
			[self.connectedSockets removeObject:sock];
		}
	}
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
	NSLog(@"Socket connected to host");
}
@end
