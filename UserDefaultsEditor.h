#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserDefaultsEditor : NSObject

/// 获取所有 NSUserDefaults 键值对
+ (NSDictionary<NSString *, id> *)allDefaults;

/// 搜索键名包含关键词的条目
+ (NSDictionary<NSString *, id> *)searchDefaultsWithKeyword:(NSString *)keyword;

/// 设置值
+ (BOOL)setValue:(id)value forKey:(NSString *)key;

/// 删除值
+ (BOOL)removeKey:(NSString *)key;

/// 格式化输出报告
+ (NSString *)formatReport:(NSDictionary<NSString *, id> *)dict;

@end

NS_ASSUME_NONNULL_END
