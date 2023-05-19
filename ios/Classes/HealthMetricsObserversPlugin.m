#import "HealthMetricsObserversPlugin.h"
#if __has_include(<health_metrics_observers/health_metrics_observers-Swift.h>)
#import <health_metrics_observers/health_metrics_observers-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "health_metrics_observers-Swift.h"
#endif

@implementation HealthMetricsObserversPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHealthMetricsObserversPlugin registerWithRegistrar:registrar];
}
@end
