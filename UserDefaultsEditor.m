#import "UserDefaultsEditor.h"

@implementation UserDefaultsEditor

+ (NSDictionary<NSString *, id> *)allDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *persistent = [defaults persistentDomainForName:[[NSBundle mainBundle] bundleIdentifier] ?: [NSBundle mainBundle].bundleIdentifier];
    // 也包含注册的默认值
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (persistent) {
        [result addEntriesFromDictionary:persistent];
    }
    // 添加 volatile 域（如当前 session 设置的）
    NSDictionary *volatile_ = [defaults volatileDomainForName:NSRegistrationDomain];
    if (volatile_) {
        [result addEntriesFromDictionary:volatile_];
    }
    return result;
}

+ (NSDictionary<NSString *, id> *)searchDefaultsWithKeyword:(NSString *)keyword {
    if (keyword.length == 0) return [self allDefaults];

    NSString *lower = [keyword lowercaseString];
    NSDictionary *all = [self allDefaults];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    [all enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if ([[key lowercaseString] containsString:lower]) {
            result[key] = obj;
        }
    }];

    return result;
}

+ (BOOL)setValue:(id)value forKey:(NSString *)key {
    if (!key) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (value) {
        [defaults setObject:value forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
    NSLog(@"[Defaults] ✅ 已设置 %@ = %@", key, value);
    return YES;
}

+ (BOOL)removeKey:(NSString *)key {
    if (!key) return NO;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[Defaults] 🗑️ 已删除 %@", key);
    return YES;
}

+ (NSString *)formatReport:(NSDictionary<NSString *, id> *)dict {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"# NSUserDefaults 内容\n"];
    [report appendFormat:@"## Bundle: %@\n", [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown"];
    [report appendString:@"----\n"];
    [report appendFormat:@"共 %lu 条记录\n\n", (unsigned long)dict.count];

    NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    __block NSUInteger idx = 1;
    for (NSString *key in sortedKeys) {
        id val = dict[key];
        NSString *valStr = @"(null)";
        if ([val isKindOfClass:[NSData class]]) {
            valStr = [NSString stringWithFormat:@"<NSData: %lu bytes>", (unsigned long)[(NSData *)val length]];
        } else if ([val isKindOfClass:[NSDate class]]) {
            valStr = [val description];
        } else {
            valStr = [NSString stringWithFormat:@"%@", val];
        }
        [report appendFormat:@"%lu. **%@** = `%@`\n", (unsigned long)idx, key, valStr];
        idx++;
    }

    return report;
}

@end
