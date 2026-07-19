#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ActiveHook : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *returnType;
@property (nonatomic, strong) id returnValue;
@property (nonatomic, assign) IMP originalIMP;
@end

@interface MethodHacker : NSObject
+ (BOOL)hookMethodWithClass:(NSString *)className methodName:(NSString *)methodName isClassMethod:(BOOL)isClassMethod returnType:(NSString *)returnType value:(id)value;
+ (NSArray<ActiveHook *> *)activeHooks;
@end
