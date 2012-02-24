//
//  PingTrayAppDelegate.h
//  PingTray
//
//  Created by Guilherme Reis Campos on 24/02/12.
//  Copyright 2012 SetaLabs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PingTrayAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
