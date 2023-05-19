#import "HealthMetricsObserversPlugin.h"
#if __has_include(<co.sinapsis.sinapsis_health_metrics/co.sinapsis.sinapsis_health_metrics-Swift.h>)
#import <co.sinapsis.sinapsis_health_metrics/co.sinapsis.sinapsis_health_metrics-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "co.sinapsis.sinapsis_health_metrics-Swift.h"
#endif

@implementation HealthMetricsObserversPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHealthMetricsObserversPlugin registerWithRegistrar:registrar];
}
@end
