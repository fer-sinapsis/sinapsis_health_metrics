#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint health_metrics_observers.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'health_metrics_observers'
  s.version          = '0.2.6'
  s.summary          = 'creates background obverservers on health data'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://www.trywecare.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wecare' => 'aryuna@andiago.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
