PROJECT = ClassDumpDylib
OUTDIR  = packages
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m

# 这一行强制让编译器认识 UIKit 基础代码
CFLAGS  = -fobjc-arc -I. -O2 -Wall -include UIKit/UIKit.h
LDFLAGS = -dynamiclib -lobjc -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics

ARCHS   = -arch arm64 -arch arm64e
SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

all: $(OUTDIR)/$(PROJECT).dylib

$(OUTDIR)/$(PROJECT).dylib: $(FILES)
	@mkdir -p $(OUTDIR)
	clang $(ARCHS) $(CFLAGS) -isysroot "$(SDK_PATH)" -miphoneos-version-min=14.0 $(LDFLAGS) $(FILES) -o $(OUTDIR)/$(PROJECT).dylib
	@echo "编译成功！"

clean:
	rm -rf $(OUTDIR)
