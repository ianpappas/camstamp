// %hook AVCaptureStillImageOutput
// - (void)handlePhotoTakenForRequest:(id)arg1 info:(id)arg2 {
// 	%log;  %orig;
// 	NSLog(@"%@", [arg1 iosurfaceCompletionBlock]);
// }
// %end
#include <IOSurface/IOSurface.h>

@class PLCameraSettingsView, PLCameraSettingsViewGroup;
static BOOL embedTimestamp = YES;
/* the following are PreferenceLoader keys */
static BOOL createSeparatePhoto = YES;
static UIColor *timestampColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
static NSString *timestampFont = @"Courier";

static PLCameraSettingsGroupView *timestamp;
%hook PLCameraSettingsView
- (id)initWithFrame:(CGRect)arg1 showGrid:(BOOL)arg2 showHDR:(BOOL)arg3 showPano:(BOOL)arg4 {
	[%c(PLCameraView) loadPreferences];
	id ret = %orig;
	int count = 0;
	if(arg2) count++; if(arg3) count++; if(arg4) count++;
	UIInterfaceOrientation orient = [[UIApplication sharedApplication] statusBarOrientation];
	if(orient == UIInterfaceOrientationPortraitUpsideDown)
		count = -count;
	timestamp = [[%c(PLCameraSettingsGroupView) alloc] initWithFrame:CGRectMake(0,(55 * count),arg1.size.width, 50)];
	[timestamp setType:0];
	[timestamp setTitle:@"Embed Timestamp"];

	UISwitch *swit = [[UISwitch alloc] init];
	[swit setOn:embedTimestamp];
	[swit addTarget:self action:@selector(toggleTimestamp:) forControlEvents:UIControlEventValueChanged];
	[swit setOnTintColor:[UIColor colorWithRed:.175 green:.176 blue:.176 alpha:1.]];
	[timestamp setAccessorySwitch:swit];
	[ret addSubview:(UIView *)timestamp];
	return ret;
}
-(void)setFrame:(CGRect)frame {
	CGRect frame2 = frame;
	frame2.size.height += 55;

	CGRect timestampFrame = ((UIView *)timestamp).frame;
	timestampFrame.size.width = frame2.size.width;
	((UIView *)timestamp).frame = timestampFrame;
	%orig(frame2);
}
%new
-(void)toggleTimestamp:(UISwitch *)sender {
	embedTimestamp = [sender isOn];
	NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Library/Preferences/com.ianp.camstamp.plist"];
	[plistDict setObject:[NSNumber numberWithBool:embedTimestamp] forKey:@"embedTimestamp"];
	[plistDict writeToFile:@"/private/var/mobile/Library/Preferences/com.ianp.camstamp.plist" atomically:NO];
}
%end
%hook PLCameraView
+ (void)initialize {
	[self loadPreferences];
}
- (void)_applicationDidBecomeActive:(id)arg1 {
	[%c(PLCameraView) loadPreferences];
}
- (void)cameraController:(id)arg1 capturedPhoto:(id)arg2 error:(id)arg3 {
	if(embedTimestamp == NO) {
		%orig;
		return;
	}
	NSMutableDictionary *argdict = [arg2 mutableCopy];
	int orientation = [[[argdict objectForKey:@"kPLCameraPhotoPropertiesKey"] objectForKey:@"Orientation"] intValue];

	IOSurfaceRef surface = (IOSurfaceRef)[argdict objectForKey:@"kPLCameraPhotoSurfaceKey"];
	NSData *data = [NSData dataWithBytes:IOSurfaceGetBaseAddress(surface) length:IOSurfaceGetAllocSize(surface)];
	UIImage *img = [[UIImage alloc] initWithData:data];
	CGImageRef inImage = [img CGImage];
	CFRelease(surface);

	UIGraphicsBeginImageContext(img.size);
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextSetFillColorWithColor(context, [timestampColor CGColor]);
	CGContextScaleCTM(context, 1, -1);
	CGContextTranslateCTM(context, 0, -img.size.height);
	CGContextDrawImage(context, CGRectMake(0,0,img.size.width, img.size.height), inImage);

	NSDate *date = [NSDate date];
	NSDateFormatter *formatter = [NSDateFormatter new];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setLocale:[NSLocale currentLocale]];
	NSString *dateString = [formatter stringFromDate:date];

	float size = img.size.width / 32; // 32 is an arbitrary factor from 960 / 30
	int diff = size + 10;
	CGContextSelectFont(context, [timestampFont UTF8String], size, kCGEncodingMacRoman);
	// Portrait orientation: 6 or 8
	// Landscape Orientation: 1 or 3
	if(orientation == 6) {
		CGContextSetTextMatrix(context, CGAffineTransformMakeRotation(M_PI/2));
		CGContextShowTextAtPoint(context, img.size.width - diff , diff, [dateString UTF8String], [dateString length]);
	}
	else if(orientation == 8) {
		CGContextSetTextMatrix(context, CGAffineTransformMakeRotation(-M_PI/2));
		CGContextShowTextAtPoint(context, diff,img.size.height - diff, [dateString UTF8String], [dateString length]);
	}
	else if(orientation == 1) {
		//CGContextSetTextMatrix(context, CGAffineTransformMakeRotation(M_PI));
		CGContextShowTextAtPoint(context, diff,diff, [dateString UTF8String], [dateString length]);
	}
	else if(orientation == 3) {
		CGContextSetTextMatrix(context, CGAffineTransformMakeRotation(M_PI));
		CGContextShowTextAtPoint(context, img.size.width - diff, img.size.height-diff, [dateString UTF8String], [dateString length]);
	}
	[img release];
	UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();

   	if(createSeparatePhoto) {
   		UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage:[newImg CGImage] scale:1 orientation:UIImageOrientationRight], nil, nil, NULL);
   		%orig;
   		return;
   	}

	NSData *jpegData = UIImageJPEGRepresentation(newImg, 1);

	CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	int val = [jpegData length];
	CFDictionarySetValue(dict, CFSTR("IOSurfaceAllocSize"), CFNumberCreate(NULL, kCFNumberSInt32Type, &val));
	IOSurfaceRef newSurface = IOSurfaceCreate(dict);
	memcpy(IOSurfaceGetBaseAddress(newSurface), [jpegData bytes], [jpegData length]);
	
	[argdict setObject:(id)newSurface forKey:@"kPLCameraPhotoSurfaceKey"];
	[argdict setObject:[NSNumber numberWithInt:IOSurfaceGetAllocSize(newSurface)] forKey:@"kPLCameraPhotoSurfaceSizeKey"];
	
	%orig(arg1, argdict, arg3);
	CFRelease(newSurface);
}
%new
+(void)loadPreferences {
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Library/Preferences/com.ianp.camstamp.plist"];
	id test;
	test = [dict objectForKey:@"createSeparatePhoto"];
	if(test) createSeparatePhoto = [test boolValue];
	test = [dict objectForKey:@"embedTimestamp"];
	if(test) embedTimestamp = [test boolValue];
	test = [dict objectForKey:@"timestampColor"];
	if(test) {
		switch([test intValue]) {
			case 0: {
				timestampColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
				break;
			}
			case 1: {
				timestampColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
				break;
			}
			case 2: {
				timestampColor = [UIColor colorWithRed:.25 green:.25 blue:.25 alpha:1];
				break;
			}			
			case 3: {
				timestampColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
				break;
			}			
			case 4: {
				timestampColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];
				break;
			}
		}
	}
	[timestampColor retain];
	test = [dict objectForKey:@"timestampFont"];
	if(test) timestampFont = test;
}
%end