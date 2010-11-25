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

#import <Cocoa/Cocoa.h>
#include "libfreenect.h"


#define AS3_BITMAPDATA_LEN 640 * 480 * 4
#define CAMERA_RESOLUTION 640 * 480


enum {
	SET_RGB_ENABLED		= 0,
	SET_DEPTH_ENABLED	= 1,
	SET_FAR_THRESHOLD	= 2,
	SET_NEAR_THRESHOLD	= 3,
	SET_TILT_DEGREE		= 4,
	SET_LED				= 5
};


@interface Kinect : NSObject {
	IBOutlet NSTextField	*usbStateText;
	IBOutlet NSSlider		*angleSlider;
	IBOutlet NSSlider		*nearThresholdSlider;
	IBOutlet NSSlider		*farThresholdSlider;
	id						delegate;
	int						led;
	int						tilt;
	bool					rgbEnabled;
	bool					depthEnabled;
}

-(void) setData:(NSData*)data;
-(void) setDelegate:(id) i_delegate;
-(void) setLed:(freenect_led_options)i_led;
-(void) setTilt:(int)i_tilt;
-(void) setRgbEnabled:(bool)i_enabled;
-(void) setDepthEnabled:(bool)i_enabled;
-(void) setFarThreshold:(float)i_thrashold;
-(void) setNearThreshold:(float)i_thrashold;


-(void) usbState:(NSString*)message;
-(IBAction) farThresholdChange:(id)sender;
-(IBAction) nearThresholdChange:(id)sender;
-(IBAction) angleChange:(id)sender;
-(void) detect;
-(void) update;
-(void) close;

@end



@interface NSObject (WiiRemoteControllerDelegate)
- (void) kinectStateChanged:(NSData*)state from:(id)sender;
@end
