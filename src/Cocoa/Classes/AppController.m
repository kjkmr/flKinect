/*
 * This file is part of the flWii Project. http://flwii.kimulabo.jp/
 *
 * Copyright (c) 2010 KIMULABO.
 *
 * This code is licensed to you under the terms of the Apache License, version
 * 2.0, or, at your option, the terms of the GNU General Public License,
 * version 2.0. See the APACHE20 and GPL2 files for the text of the licenses,
 * or the following URLs:
 * http://www.apache.org/licenses/LICENSE-2.0
 * http://www.gnu.org/licenses/gpl-2.0.txt
 *
 * If you redistribute this file in source form, modified or unmodified, you
 * may:
 *   1) Leave this header intact and distribute it under the same terms,
 *      accompanying it with the APACHE20 and GPL20 files, or
 *   2) Delete the Apache 2.0 clause and accompany it with the GPL2 file, or
 *   3) Delete the GPL v2 clause and accompany it with the APACHE20 file
 * In all cases you must keep the copyright notice intact and include a copy
 * of the CONTRIB file.
 *
 * Binary distributions must follow the binary distribution requirements of
 * either License.
 */

#import "AppController.h"


@implementation AppController

//
// Constructor
//

-(id)init{
	self= [super init];
	return self;
}

//
// dealloc
//

- (void) dealloc{
	[super dealloc];
}

/**
 * GUIの生成後
 */

-(void)awakeFromNib{
	socketServer = [[SocketServer alloc] init];
	[socketServer start];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(__receivedMessage:)
												 name:@"SockReceivedMessage"
											   object:socketServer];
	[kinect setDelegate:self];
}



- (void)kinectStateChanged:(NSData*)state from:(id*)sender {
	[socketServer sendMessage:state];
}


/**
 * データを受信したとき
 * 
 * (NSNotification*)		notification
 *
 */
- (void)__receivedMessage:(NSNotification*)notification {
	//NSLog(@"__receivedMessage");
	NSData* data = [[notification userInfo] objectForKey:@"data"];
	if ( [data bytes] == nil ) return;
	[kinect setData:data];
}

/**
 * アプリケーションが終了する前のイベント
 *
 * @param	sender		(I)sender
 * @return	終了するかどうか(NSTerminateNow,NSTerminateCancel,NSTerminateLater)
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	return NSTerminateNow;
}


/**
 * 最後のウィンドウが閉じた時のイベント
 *
 * @param	sender		(I)sender
 * @return	NO(最後のウィンドウが閉じられて時に終了しない)
 */
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

/**
 * アプリケーションの終了時、NSApplicationから送られる通知
 *
 * @param	notification	(I)Notification
 */
- (void)applicationWillTerminate:(NSNotification *)notification {
	
}

@end
