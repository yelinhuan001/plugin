#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ClassDumpSearcher.h"
#import <objc/runtime.h>

@implementation ClassDumpSearcher
+ (NSArray *)searchClassesWithKeyword:(NSString *)keyword {
    NSMutableArray *results = [NSMutableArray array];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        NSString *lowerKeyword = [keyword lowercaseString];
        for (int i = 0; i < numClasses; i++) {
            NSString *className = NSStringFromClass(classes[i]);
            if (keyword.length == 0 || [[className lowercaseString] containsString:lowerKeyword]) {
                [results addObject:className];
            }
        }
        free(classes);
    }
    return [results sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}
@end
