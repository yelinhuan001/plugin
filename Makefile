PROJECT = ClassDumpDylib
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m
CFLAGS  = -fobjc-arc -I.
LDFLAGS = -lobjc -framework UIKit -framework Foundation -framework QuartzCore
OUTDIR  = packages

ifdef THEOS
  SDK_PATH ?= $(THEOS)/sdks/iPhoneOS14.5.sdk
  ifeq ("$(wildcard $(SDK_PATH))","")
    SDK_PATH := $(shell find $(THEOS)/sdks -name "iPhoneOS*.sdk" -type d 2>/dev/null | head -1)
  endif
else
  SDK_PATH ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
endif

all:
	@mkdir -p $(OUTDIR)
	@echo "SDK: $(SDK_PATH)"
	clang -shared \
		$(CFLAGS) \
		-isysroot "$(SDK_PATH)" \
		-arch arm64 \
		-miphoneos-version-min=14.0 \
		$(LDFLAGS) \
		$(FILES) \
		-o $(OUTDIR)/$(PROJECT).dylib
	@echo "✅ 编译完成: $(OUTDIR)/$(PROJECT).dylib"
	@ls -la $(OUTDIR)/$(PROJECT).dylib

clean:
	rm -rf $(OUTDIR)
