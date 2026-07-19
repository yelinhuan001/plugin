#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UserDefaultsEditor.h"

@implementation UserDefaultsEditor

+ (NSDictionary<NSString *, id> *)allDefaults {
    return [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
}

+ (NSDictionary<NSString *, id> *)searchDefaultsWithKeyword:(NSString *)keyword {
    NSDictionary *all = [self allDefaults];
    if (keyword.length == 0) return all;

    NSString *lowerKeyword = [keyword lowercaseString];
    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    [all enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([[key lowercaseString] containsString:lowerKeyword]) {
            results[key] = value;
        }
    }];

    return [results copy];
}

+ (BOOL)setValue:(id)value forKey:(NSString *)key {
    if (key.length == 0) return NO;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value == nil || [value isKindOfClass:[NSNull class]]) {
        [defaults removeObjectForKey:key];
    } else if ([value isKindOfClass:[NSString class]]) {
        // 尝试智能类型转换
        NSString *str = (NSString *)value;

        if ([str caseInsensitiveCompare:@"YES"] == NSOrderedSame ||
            [str caseInsensitiveCompare:@"true"] == NSOrderedSame) {
            [defaults setBool:YES forKey:key];
        } else if ([str caseInsensitiveCompare:@"NO"] == NSOrderedSame ||
                   [str caseInsensitiveCompare:@"false"] == NSOrderedSame) {
            [defaults setBool:NO forKey:key];
        } else {
            // 尝试数字解析
            NSInteger intVal = [str integerValue];
            if ([str isEqualToString:@(intVal).stringValue]) {
                // 纯整数
                [defaults setInteger:intVal forKey:key];
            } else {
                double doubleVal = [str doubleValue];
                if ([str isEqualToString:[NSString stringWithFormat:@"%g", doubleVal]]) {
                    // 纯浮点数
                    [defaults setDouble:doubleVal forKey:key];
                } else {
                    // 普通字符串
                    [defaults setObject:str forKey:key];
                }
            }
        }
    } else if ([value isKindOfClass:[NSNumber class]]) {
        [defaults setObject:value forKey:key];
    } else {
        [defaults setObject:value forKey:key];
    }

    [defaults synchronize];
    return YES;
}

+ (BOOL)removeKey:(NSString *)key {
    if (key.length == 0) return NO;

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

+ (NSString *)formatReport:(NSDictionary<NSString *, id> *)dict {
    if (dict.count == 0) return @"(空)";

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"=== UserDefaults 报告 ===\n\n"];

    NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        id value = dict[key];
        NSString *valueStr;

        if ([value isKindOfClass:[NSData class]]) {
            valueStr = [NSString stringWithFormat:@"<NSData: %lu bytes>", (unsigned long)[(NSData *)value length]];
        } else if ([value isKindOfClass:[NSDate class]]) {
            NSDateFormatter *fmt = [NSDateFormatter new];
            fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            valueStr = [fmt stringFromDate:(NSDate *)value];
        } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
            valueStr = [NSString stringWithFormat:@"%@", value];
        } else {
            valueStr = [NSString stringWithFormat:@"%@", value];
        }

        [report appendFormat:@"%@ = %@\n", key, valueStr];
    }

    [report appendString:@"\n========================="];
    return [report copy];
}

@end
