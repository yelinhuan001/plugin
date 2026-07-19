#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, HookType) {
    HookTypeReturn   = 0,  // 返回固定值（默认）
    HookTypeLog      = 1,  // 运行时日志（调用时 NSLog + 通知）
    HookTypeBlock    = 2,  // 自定义 Block 替换
    HookTypeSwizzle  = 3,  // Method Swizzle（与原实现交换）
    HookTypeKVC      = 4,  // KVC 修改属性值
};

@interface ActiveHook : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, assign) HookType hookType;
@property (nonatomic, copy) NSString *returnType;  // 返回类型编码
@property (nonatomic, strong) id returnValue;      // return hook 的返回值
@property (nonatomic, copy) NSString *kvcKeyPath;  // KVC 属性路径
@property (nonatomic, strong) id kvcValue;         // KVC 目标值
@property (nonatomic, assign) IMP originalIMP;
@property (nonatomic, assign) NSUInteger callCount; // 被调用次数（Log模式）

+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)cm;
@end

@interface MethodHacker : NSObject

/// Hook 方法返回固定值
+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value;

/// Hook 方法并选择类型
+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                   hookType:(HookType)type
                 returnType:(NSString *)returnType
                      value:(id)value;

/// 添加 Log Hook - 调用时记录日志并通过通知发送
+ (BOOL)addLogHookForClass:(NSString *)className
                methodName:(NSString *)methodName
             isClassMethod:(BOOL)isClassMethod;

/// KVC 修改属性
+ (BOOL)modifyPropertyWithClass:(NSString *)className
                       keyPath:(NSString *)keyPath
                         value:(id)value;

/// 取消 Hook
+ (BOOL)unhook:(ActiveHook *)hook;

/// 取消全部
+ (void)unhookAll;

/// 获取活跃 Hook 列表
+ (NSArray<ActiveHook *> *)activeHooks;

/// 获取日志记录
+ (NSArray<NSString *> *)hookLogs;

/// 清除日志
+ (void)clearLogs;

@end

/// Hook 日志更新通知
extern NSString *const HookLogDidUpdateNotification;
