#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS
@interface NSUserDefaults (EasyTierContainerInitializer)
- (instancetype)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end

@interface NSUserDefaults (EasyTierSharedPreferencesCompatibility)
- (instancetype)et_initWithSuiteName:(NSString *)suiteName __attribute__((objc_method_family(init)));
@end

// On iOS 15, a TrollStore system registration can resolve a suite relative to
// each process's private container even though the App Group URL is available.
// Select the actual group container explicitly for this one suite. Other suites
// and standard defaults keep their original behavior.
@implementation NSUserDefaults (EasyTierSharedPreferencesCompatibility)
+ (void)load {
    if (@available(iOS 16.0, *)) return;
    // A prebuilt extension may also load this compatibility code as a dylib.
    // Installing once avoids swapping the methods back if both forms are present.
    const void *installedKey = sel_registerName("et_sharedPreferencesCompatibilityInstalled");
    if (objc_getAssociatedObject(self, installedKey)) return;
    SEL containerInitializer = @selector(_initWithSuiteName:container:);
    if (![self instancesRespondToSelector:containerInitializer]) return;
    Method original = class_getInstanceMethod(self, @selector(initWithSuiteName:));
    Method replacement = class_getInstanceMethod(self, @selector(et_initWithSuiteName:));
    method_exchangeImplementations(original, replacement);
    objc_setAssociatedObject(self, installedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (instancetype)et_initWithSuiteName:(NSString *)suiteName {
    if (![suiteName isEqualToString:@"group.cn.easytier"]) {
        return [self et_initWithSuiteName:suiteName];
    }
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:suiteName];
    if (!container) return [self et_initWithSuiteName:suiteName];
    return [self _initWithSuiteName:suiteName container:container];
}
@end
#endif
