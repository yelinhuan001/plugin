#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 存储一个活跃的 Hook 记录
@interface ActiveHook : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *returnType;
@property (nonatomic, strong, nullable) id returnValue;
@property (nonatomic, assign) IMP originalIMP;
@property (nonatomic, copy, nullable) NSString *typeEncoding;
+ (instancetype)hookWithClass:(NSString *)cls
                       method:(NSString *)sel
                      isClass:(BOOL)classMeth
                   returnType:(NSString *)type
                        value:(nullable id)value;
- (NSString *)displayDescription;
@end

/// 方法 Hook 管理器（纯 Runtime，无需 Substrate）
@interface MethodHacker : NSObject

/// 所有活跃的 Hook
@property (class, readonly) NSArray<ActiveHook *> *activeHooks;

/// Hook 一个方法，强制返回固定值。
/// returnType 传 @"auto" 或 nil 时根据方法 type encoding 自动识别。
+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(nullable NSString *)returnType
                      value:(nullable id)value;

/// 从属性名 Hook getter（自动解析 getter / isXxx）
+ (BOOL)hookPropertyWithClass:(NSString *)className
                 propertyName:(NSString *)propertyName
                        value:(id)value;

/// 取消指定 Hook
+ (BOOL)unhook:(ActiveHook *)hook;

/// 取消全部 Hook
+ (void)unhookAll;

/// 列出所有已注册类（可过滤）
+ (NSArray<NSString *> *)allClassesFiltered:(NSString * _Nullable)filter;

/// 列出某类的实例/类方法名
+ (NSArray<NSString *> *)methodsOfClass:(NSString *)className
                          isClassMethod:(BOOL)isClassMethod
                                 filter:(NSString * _Nullable)filter;

/// 读取方法返回类型编码 → 人类可读（BOOL/id/int/...）
+ (NSString *)readableReturnTypeForClass:(NSString *)className
                              methodName:(NSString *)methodName
                           isClassMethod:(BOOL)isClassMethod;

/// 将活跃 Hook 导出为 Logos / 纯 ObjC 代码
+ (NSString *)exportHooksAsCode;

@end

NS_ASSUME_NONNULL_END
