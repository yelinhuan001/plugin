export TARGET := iphone:clang:14.0:13.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ClassDumpTweak
ClassDumpTweak_FILES = Tweak.xm ClassDumpSearcher.m SearchOverlayWindow.m
ClassDumpTweak_CFLAGS = -fobjc-arc -I.
ClassDumpTweak_LDFLAGS = -lobjc -framework UIKit -framework Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后杀掉目标 App（可修改为你希望注入的 App）
after-install::
	install.exec "killall -9 SpringBoard" || true
