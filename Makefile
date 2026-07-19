PROJECT = ClassDumpDylib
# 输出目录
OUTDIR  = packages
# 源代码文件
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m

# 编译参数
CFLAGS  = -fobjc-arc -I. -O2 -Wall
# 链接参数 (明确指定动态库)
LDFLAGS = -dynamiclib -lobjc \
          -framework UIKit \
          -framework Foundation \
          -framework QuartzCore \
          -framework CoreGraphics

# 目标架构 (建议同时编译 arm64 和 arm64e 以兼容新老设备)
ARCHS   = -arch arm64 -arch arm64e

# SDK 路径逻辑优化
ifdef THEOS
  SDK_PATH ?= $(THEOS)/sdks/iPhoneOS14.5.sdk
  ifeq ("$(wildcard $(SDK_PATH))","")
    SDK_PATH := $(shell find $(THEOS)/sdks -name "iPhoneOS*.sdk" -type d 2>/dev/null | head -1)
  endif
else
  SDK_PATH ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
endif

# 定义伪目标
.PHONY: all clean

all: $(OUTDIR)/$(PROJECT).dylib

$(OUTDIR)/$(PROJECT).dylib: $(FILES)
	@mkdir -p $(OUTDIR)
	@echo "——> 正在使用 SDK: $(SDK_PATH) 进行编译..."
	
	# 编译与链接
	clang $(ARCHS) $(CFLAGS) \
		-isysroot "$(SDK_PATH)" \
		-miphoneos-version-min=14.0 \
		$(LDFLAGS) \
		$(FILES) \
		-o $(OUTDIR)/$(PROJECT).dylib
	
	# 代码签名 (iOS 运行必需，即使是伪签名)
	@echo "——> 正在进行代码签名 (ldid)..."
	@if command -v ldid > /dev/null; then \
		ldid -S $(OUTDIR)/$(PROJECT).dylib; \
	else \
		echo "警告: 未找到 ldid，请确保你的编译环境安装了 ldid，否则真机无法加载"; \
	fi
	
	@echo " 编译完成: $(OUTDIR)/$(PROJECT).dylib"
	@ls -la $(OUTDIR)/$(PROJECT).dylib

clean:
	rm -rf $(OUTDIR)
	@echo "已清理编译目录"
