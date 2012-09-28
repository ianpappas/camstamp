include theos/makefiles/common.mk
export GO_EASY_ON_ME = 1
TWEAK_NAME = Camstamp
Camstamp_FILES = Tweak.xm
Camstamp_FRAMEWORKS = UIKit AVFoundation CoreGraphics
Camstamp_PRIVATE_FRAMEWORKS = ImageCapture PhotoLibrary PhotoLibraryServices IOSurface CoreSurface
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += camstampprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
