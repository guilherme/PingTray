//
//  PingTrayAppDelegate.h
//  PingTray
//
//  Created by Guilherme Reis Campos on 24/02/12.
//  Copyright 2012 SetaLabs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PingTrayAppDelegate : NSObject <NSApplicationDelegate> { 
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    NSImage *statusImage;
    IBOutlet NSWindow *settingsWindow;
    
    int sockfd;
    struct  protoent *proto;
    int pingStatus;
    int icmp_id;
    int icmp_seq;
    int attempt;
}

- (IBAction)doSomething:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
