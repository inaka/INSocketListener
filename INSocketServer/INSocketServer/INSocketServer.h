//
//  INSocketServer.h
//  INSocketServer
//
//  Created by toms on 01/07/13.
//  Copyright (c) 2013 Inaka Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSocketDelegate.h"

@interface INSocketServer : NSObject
@property NSInteger port;
@property (nonatomic, assign) id<INSocketDelegate>socketDelegate;

- (id)initWithPort:(NSInteger)port delegate:(id<INSocketDelegate>)delegate;
- (void)start;
- (void)stop;
- (void)sendJSON:(NSString *)jsonString tag:(NSInteger)tag;
@end
