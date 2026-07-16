// TweakEntry.m
// dylib 入口。不自动改会员；默认延迟后弹出搜索面板，便于手动操作。

#import <UIKit/UIKit.h>
#import "CDSOverlay.h"
#import "ClassDumpSearch.h"

// 设为 0 则启动后不自动弹窗，需自行在别处调用 [CDSOverlay show]
#ifndef CDS_AUTO_SHOW_OVERLAY
#define CDS_AUTO_SHOW_OVERLAY 1
#endif

__attribute__((constructor))
static void cds_init(void) {
    // 默认只扫 App 自身类，减少噪声；需要全进程扫描时改为 NO
    [ClassDumpSearch setSearchAppOwnClassesOnly:YES];

    NSLog(@"[ClassDumpSearch] dylib loaded in %@",
          [[NSBundle mainBundle] bundleIdentifier] ?: @"?");

#if CDS_AUTO_SHOW_OVERLAY
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [CDSOverlay show];
    });
#endif
}
