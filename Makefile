PROJECT = ClassDumpDylib
OUTDIR  = packages
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m

# 强制修复 UIAccessibilityTraits 报错的关键参数: -Wno-everything 是为了跳过所有不必要的干扰警告
CFLAGS  = -fobjc-arc -I. -O2 -Wno-everything -include UIKit/UIKit.h
LDFLAGS = -dynamiclib -lobjc \
          -framework UIKit \
          -framework Foundation \
          -framework QuartzCore \
          -framework CoreGraphics

ARCHS   = -arch arm64 -arch arm64e
SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

all: $(OUTDIR)/$(PROJECT).dylib

$(OUTDIR)/$(PROJECT).dylib: $(FILES)
	@mkdir -p $(OUTDIR)
	clang $(ARCHS) $(CFLAGS) -isysroot "$(SDK_PATH)" -miphoneos-version-min=14.0 $(LDFLAGS) $(FILES) -o $(OUTDIR)/$(PROJECT).dylib
	@echo "编译成功！"

clean:
	rm -rf $(OUTDIR)
