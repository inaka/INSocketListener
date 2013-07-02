//
//  INSocketListener.h
//  INSocketListener
//
//  Created by toms on 29/06/13.
//  Copyright (c) 2013 Inaka Labs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INSocketDelegate.h"

@interface INSocketListener : NSObject
@property (nonatomic, strong) NSString *server;
@property NSInteger port;
@property (nonatomic, strong) NSString *endpointPath;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSString *authenticationString;
@property (nonatomic, assign) id<INSocketDelegate>delegate;

- (id)initWithServer:(NSString *)server port:(NSInteger)port delegate:(id<INSocketDelegate>)delegate;
- (void)connect;
- (void)reconnect;
- (void)disconnect;
- (void)authenticateWithKey:(NSString *)key secret:(NSString *)secret;
@end
