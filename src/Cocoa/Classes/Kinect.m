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

#import "Kinect.h"
#include "libfreenect.h"

@implementation Kinect

id self_ref;
bool __connected;
freenect_context *f_ctx;
freenect_device *f_dev;
int __angle;
int __nearThreshold;
int __farThreshold;
//int __autoNearThreshold = 2047;
unsigned __gray[2048];
char _state[ AS3_BITMAPDATA_LEN /* <- rgb */ + AS3_BITMAPDATA_LEN /* <- depth */ + 4 * 6 /* <- data */ ];

void rgb_cb(freenect_device *i_dev, freenect_pixel *i_rgb, uint32_t i_timestamp) {
	int i,a,b;
	for ( i=0; i<CAMERA_RESOLUTION; i++ ) {
		a = i * 4;
		b = i * 3;
		_state[a+2] = i_rgb[b+0];
		_state[a+1] = i_rgb[b+1];
		_state[a+0] = i_rgb[b+2];
		_state[a+3] = 0x00;
	}
}

void depth_cb(freenect_device *dev, void *v_depth, uint32_t timestamp) {
	int i,a;
	//int min = 2047;
	unsigned char d;
	freenect_depth *depth = v_depth;
	for ( i=0; i<CAMERA_RESOLUTION; i++ ) {
		//if ( depth[i] < min ) min = depth[i];
		d = __gray[depth[i]];
		a = AS3_BITMAPDATA_LEN + i * 4;
		_state[a+0] = d;
		_state[a+1] = d;
		_state[a+2] = d;
		_state[a+3] = 0xff;
	}
	/*
	if ( __autoNearThreshold == 0 ) __autoNearThreshold = 2047 - min;
	else __autoNearThreshold = (int)( __autoNearThreshold * 0.5 + (2047 - min) *0.5 );
	 */
}

void calcGray() {
	int i;
	float f;
	char d;
	int range = __nearThreshold - __farThreshold;
	for ( i=0; i<2048; i++ ) {
		f = (float)( 2048 - i - __farThreshold ) / (float)range;
		if ( f < 0 ) f = 0;
		else if ( f > 1 ) f = 1;
		d = (int)0xff * f;
		__gray[i] = d;
	}
}

void doNothing() {}

/**
 * init
 */

-(id)init{
	
	//NSLog(@"init");
	self= [super init];
	self_ref = self;
	//
	return self;
}

/**
 * GUIの生成後
 */

-(void)awakeFromNib{
	__connected = false;
	__angle = 0;
	__farThreshold = [farThresholdSlider minValue];
	__nearThreshold = [nearThresholdSlider maxValue];
	calcGray();
	rgbEnabled = true;
	depthEnabled = true;
	
	//Kinect初期化
	if (freenect_init(&f_ctx, NULL) < 0) {
		[self usbState:@"Initialization faild."];
	} else {
		//freenect_set_log_level(f_ctx, FREENECT_LOG_DEBUG);
		freenect_set_log_level(f_ctx, FREENECT_LOG_ERROR);
		[self detect];
	}
}



/**
 * dealloc
 */
-(void) dealloc {
	[self close];
	[super dealloc];
}

/**
 * usb状態表示
 */
-(void) usbState:(NSString*) message {
	[usbStateText setStringValue:message];
}


/**
 * IBAction
 */

-(IBAction) farThresholdChange:(id)sender {
	__farThreshold = (int)[farThresholdSlider integerValue];
	if ( __farThreshold > __nearThreshold ) {
		__nearThreshold = __farThreshold + 1;
		[nearThresholdSlider setIntValue:__nearThreshold];
	}
	calcGray();
	float f = (float)( __farThreshold / 2048.0f );
	printf("%f\n",f);
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_FAR_THRESHOLD * 4], &f, sizeof(f));
}
-(IBAction) nearThresholdChange:(id)sender {
	__nearThreshold = [nearThresholdSlider integerValue];
	if ( __nearThreshold < __farThreshold ) {
		__farThreshold = __nearThreshold - 1;
		[farThresholdSlider setIntValue:__farThreshold];
	}
	calcGray();
	float f = (float)( __nearThreshold / 2048.0f );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_NEAR_THRESHOLD * 4], &f, sizeof(f));
}

-(IBAction) angleChange:(id)sender {
	if ( !__connected ) return;
	tilt = [angleSlider integerValue];
	freenect_set_tilt_degs(f_dev,tilt);
	float f = (float)( tilt );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_TILT_DEGREE * 4], &f, sizeof(f));
}


/**
 * 設定コマンド
 */
-(void) setData:(NSData*)data {
	//NSLog(@"setData");
	void *p = (void*)[data bytes];
	char mode;
	float value;
	int read = 0;
	int l = [data length];
	while ( read + 6 <= l ) {
		memcpy(&mode, p, sizeof(mode));
		memcpy(&value, p + 1, sizeof(value));
		
		if ( mode == SET_RGB_ENABLED ) {
			bool b = value > 0;
			[self setRgbEnabled:b];
		} else if ( mode == SET_DEPTH_ENABLED ) {
			bool b = value > 0;
			[self setDepthEnabled:b];
		} else if ( mode == SET_TILT_DEGREE ) {
			[self setTilt:(int)value];
		} else if ( mode == SET_LED ) {
			[self setLed:(int)value];
		} else if ( mode == SET_FAR_THRESHOLD ) {
			[self setFarThreshold:value];
		} else if ( mode == SET_NEAR_THRESHOLD ) {
			[self setNearThreshold:value];
		}
		
		read += 6;
		p += 6;
	}
	
}

-(void) setFarThreshold:(float)i_threshold {
	[farThresholdSlider setIntValue:i_threshold * 2048];
	[self farThresholdChange:nil];
	float f = (float)( __farThreshold / 2048.0f );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_FAR_THRESHOLD * 4], &f, sizeof(f));
}

-(void) setNearThreshold:(float)i_threshold {
	[nearThresholdSlider setIntValue:i_threshold * 2048];
	[self nearThresholdChange:nil];
	float f = (float)( __nearThreshold / 2048.0f );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_NEAR_THRESHOLD * 4], &f, sizeof(f));
}

-(void) setLed:(freenect_led_options)i_led {
	led = i_led;
	if ( !__connected ) return;
	freenect_set_led(f_dev,led);
	float f = (float)( led );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_LED * 4], &f, sizeof(f));
}

-(void) setTilt:(int)i_tilt {
	tilt = i_tilt;
	if ( !__connected ) return;
	freenect_set_tilt_degs(f_dev, (double)tilt);
	[angleSlider setIntValue:tilt];
	float f = (float)( tilt );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_TILT_DEGREE * 4], &f, sizeof(f));
}

-(void) setRgbEnabled:(bool)i_enabled {
	rgbEnabled = i_enabled;
	if ( !__connected ) return;
	if ( rgbEnabled ) {
		freenect_set_rgb_callback(f_dev, rgb_cb);
	} else {
		freenect_set_rgb_callback(f_dev, doNothing );
		memset(_state, 0, AS3_BITMAPDATA_LEN);
	}
	
	float f = (float)( rgbEnabled ? 1 : 0 );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_RGB_ENABLED * 4], &f, sizeof(f));
}

-(void) setDepthEnabled:(bool)i_enabled {
	depthEnabled = i_enabled;
	if ( !__connected ) return;
	if ( depthEnabled ) {
		freenect_set_depth_callback(f_dev, depth_cb);
	} else {
		freenect_set_depth_callback(f_dev, doNothing );
		memset(_state+AS3_BITMAPDATA_LEN, 0, AS3_BITMAPDATA_LEN);
	}
	float f = (float)( depthEnabled ? 1 : 0 );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_DEPTH_ENABLED * 4], &f, sizeof(f));
}


/**
 * usb検出
 */

-(void) detect {
	NSLog(@"detect");

	int numDevices = freenect_num_devices(f_ctx);
	if ( numDevices < 1 ) {
		[self performSelector:@selector(detect) withObject:nil afterDelay:0.5f];
		return;
	}
	
	if (freenect_open_device(f_ctx, &f_dev, 0) < 0) {
		[self usbState:@"Could not open device"];
		return;
	}
	
	__connected = true;
	[self usbState:@"connected"];
	
	//
	freenect_set_rgb_format(f_dev, FREENECT_FORMAT_RGB);
	freenect_set_depth_format(f_dev, FREENECT_FORMAT_11_BIT);
	
	
	freenect_start_rgb(f_dev);
	freenect_start_depth(f_dev);
	
	freenect_set_led(f_dev,led);
	freenect_set_tilt_degs(f_dev, tilt);
	
	[self setRgbEnabled:rgbEnabled];
	[self setDepthEnabled:depthEnabled];
	
	float f = (float)( tilt );
	f = (float)( __farThreshold / 2048.0f );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_FAR_THRESHOLD * 4], &f, sizeof(f));
	f = (float)( __nearThreshold / 2048.0f );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_NEAR_THRESHOLD * 4], &f, sizeof(f));
	f = (float)( tilt );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_TILT_DEGREE * 4], &f, sizeof(f));
	f = (float)( led );
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_LED * 4], &f, sizeof(f));
	f = (float)( rgbEnabled ? 1 : 0 );
	printf("f : %f\n",f);
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_RGB_ENABLED * 4], &f, sizeof(f));
	f = (float)( depthEnabled ? 1 : 0 );
	printf("f : %f\n",f);
	memcpy(&_state[AS3_BITMAPDATA_LEN * 2 + SET_DEPTH_ENABLED * 4], &f, sizeof(f));
	
	[self update];

}

/**
 * 更新
 */

-(void) update {
	//NSLog(@"update");
	/*
	if ( freenect_num_devices(f_ctx) < 1 ) {
		NSLog(@"disconnected");
		[self close];
		[self detect];
		return;
	}
	 */
	[self performSelector:@selector(update) withObject:nil afterDelay:1/30.0f];
	
	freenect_process_events(f_ctx);
	int16_t ax,ay,az;
	freenect_get_raw_accel(f_dev, &ax, &ay, &az);
	
	// 通知
	if ( [delegate respondsToSelector:@selector(kinectStateChanged:from:)] ) {
		NSData* data = [NSData dataWithBytes:_state length:sizeof(_state)];
		[delegate kinectStateChanged:data from:self];
	}
	/*
	//
	if ( __nearThreshold != __autoNearThreshold ) {
		__nearThreshold = __autoNearThreshold;
		__farThreshold = __nearThreshold - 512;
		calcGray();
		//[nearThresholdSlider setIntValue:__nearThreshold];
		//[farThresholdSlider setIntValue:__farThreshold];
		//[self nearThresholdChange:nil];
		//[self farThresholdChange:nil];
	}
	*/
	
}

- (void) close {
	NSLog(@"close");
	@try {
		if ( freenect_num_devices(f_ctx) >= 1 ) {
			freenect_stop_depth(f_dev);
			freenect_stop_rgb(f_dev);
		}
	}
	@catch (NSException * e) {
	}
	@finally {
		freenect_shutdown(f_ctx);
	}
	__connected = false;
	[self usbState:@"no device"];
}

- (void) setDelegate:(id) i_delegate {
	delegate = i_delegate;
}


@end
