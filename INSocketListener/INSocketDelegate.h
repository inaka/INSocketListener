//
//  INSocketListenerDelegate.h
//  INSocketListener
//
//  Created by toms on 29/06/13.
//  Copyright (c) 2013 Inaka Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol INSocketDelegate <NSObject>
- (void)handleResponse:(id)responseJSON;
- (void)handleError:(NSError *)error;
@end
