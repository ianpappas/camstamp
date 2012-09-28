#import <Preferences/PSListController.h>

@interface CamstampPrefsListController: PSListController {
}
@end

@implementation CamstampPrefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"CamstampPrefs" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
