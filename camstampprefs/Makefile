include theos/makefiles/common.mk

BUNDLE_NAME = CamstampPrefs
CamstampPrefs_FILES = CamstampPrefs.mm
CamstampPrefs_INSTALL_PATH = /Library/PreferenceBundles
CamstampPrefs_FRAMEWORKS = UIKit
CamstampPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CamstampPrefs.plist$(ECHO_END)
