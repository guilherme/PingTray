//
//  PingTrayAppDelegate.m
//  PingTray
//
//  Created by Guilherme Reis Campos on 24/02/12.
//  Copyright 2012 SetaLabs. All rights reserved.
//

#import "PingTrayAppDelegate.h"
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>


#define ICMP_TYPE_ECHO_REQUEST 8
#define ICMP_TYPE_ECHO_REPLY 0
#define PING_NO_PING_SENT 0
#define PING_WAITING_RESPONSE 1
#define PING_OK 0
#define PING_SLOW_CONN 1
#define PING_NO_CONN 2


@implementation PingTrayAppDelegate

@synthesize window;

struct ICMPHeader {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    // data...
    int64_t     sentTime;
};

/* unix time in micro seconds */
/* TODO: investigate it more */
/* How to get such small time ? */
int64_t ustime(void) {
    struct timeval tv;
    long long ust;
    
    gettimeofday(&tv, NULL);
    ust = ((int64_t)tv.tv_sec)*1000000;
    ust += tv.tv_usec;
    return ust;
}

int setSocketNonBlocking(int fd) {
    int flags;
    
    /* Set the socket nonblocking.
     * Note that fcntl(2) for F_GETFL and F_SETFL can't be
     * interrupted by a signal. */
    if ((flags = fcntl(fd, F_GETFL)) == -1) return -1;
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) return -1;
    return 0;
}
/* This is the standard BSD checksum code, modified to use modern types. */
static uint16_t in_cksum(const void *buffer, size_t bufferLen)
{
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);     /* add hi 16 to low 16 */
    sum += (sum >> 16);                     /* add carry */
    answer = ~sum;                          /* truncate to 16 bits */
    
    return answer;
}


-(void)applicationDidFinishLaunching:(NSNotification *)notification {

    NSBundle *bundle = [NSBundle mainBundle];
    
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    statusImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:@"red-ball" ofType:@"gif"]];
    
    [statusItem setImage:statusImage];
    [statusItem setMenu:statusMenu];
    [statusItem setToolTip: @"Ping Tray"];
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(statusUpdater:)]];
    [invocation setTarget: self];
    [invocation setSelector:@selector(statusUpdater:)];
    
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:0.1 invocation:invocation repeats: YES] forMode:NSRunLoopCommonModes];
    

    if (!(proto = getprotobyname("icmp"))) {
        // TODO: ALERT AND EXIT;
        NSLog(@"unknown protocol icmp");
        return;
    }
    
    sockfd = socket(PF_INET, SOCK_DGRAM, proto->p_proto); 
    if (!sockfd) {
        NSLog(@"Unable to open a socket file descriptor.");
        return;
    }
    addr = malloc(sizeof(struct sockaddr_in));
    inet_aton("8.8.8.8", (struct in_addr *)&addr->sin_addr); // DO NOT HANDLE IPv6 use inet_pton
    pingStatus = 0;
    icmp_id = random()&0xffff;
    icmp_seq = random()&0xffff;
    setSocketNonBlocking(sockfd);
    
}
- (void)updateImage:(int) image_id {   
    if(statusImage) {
        [statusImage release];
    }
    NSArray *myImages;
    NSBundle *bundle = [NSBundle mainBundle];
    myImages = [NSArray arrayWithObjects: @"green-ball", @"yellow-ball", @"red-ball", nil];
    statusImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:[myImages objectAtIndex: image_id] ofType:@"gif"]];
    
    [statusItem setImage:statusImage]; 
}


-(void)statusUpdater:(NSTimer *) t {
    struct ICMPHeader icmp;
    socklen_t fromLen;
    // PING TIME
    switch (pingStatus) {
        case PING_NO_PING_SENT:
            icmp.type = ICMP_TYPE_ECHO_REQUEST;
            icmp.code = 0;
            icmp.checksum = 0;
            icmp.sequenceNumber = icmp_id; 
            icmp.identifier     = icmp_seq;
            icmp.sentTime       = ustime();
            icmp.checksum       = in_cksum(&icmp, sizeof(icmp)); 
            attempt = 1;
            if(sendto(sockfd, &icmp, sizeof(icmp), 0, (struct sockaddr *)&addr, sizeof(addr)) == -1){
                NSLog(@"Error");
                [self updateImage: PING_NO_CONN]; 
                // TODO: TREAT THE errno global.
            } else {
                NSLog(@"#SENT");
                pingStatus = PING_WAITING_RESPONSE;
            }
            break;
        case PING_WAITING_RESPONSE:
            fromLen = sizeof(addr);
            if(recvfrom(sockfd, &icmp, sizeof(icmp), 0, (struct sockaddr *)&addr, &fromLen) > 0) {
                NSLog(@"#OK");
                if(ustime() - icmp.sentTime > 300) {
                    NSLog(@"Too slow");
                    [self updateImage: PING_SLOW_CONN];
                } else {
                    NSLog(@"OK");
                    [self updateImage: PING_OK];
                }
                pingStatus = PING_NO_PING_SENT;
            } else {
                if(attempt % 10 == 0) {
                    attempt = 1;
                    pingStatus = PING_NO_PING_SENT;
                    [self updateImage: PING_NO_CONN];
                } else {
                    attempt++;
                }
            }
            break;
        default:
            break;
    }

    

}


- (void) dealloc {
    [statusImage release];
    [super dealloc];
}

- (IBAction)doSomething:(id)sender {
    NSLog(@"Is doing something");
}

@end
