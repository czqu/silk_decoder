#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint silk_decoder.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'silk_decoder'
  s.version          = '0.0.2'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://czqu.net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'me@czqu.net' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.prepare_command = 'bash build_ios.sh'
  s.script_phase = {
      :name => 'Trigger Native Build',
      # First argument is relative path to the `rust` folder, second is name of rust library
      :script => 'ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/build_phony"',
      :execution_position=> :before_compile,
      :input_files => ['${BUILT_PRODUCTS_DIR}/build_phony'],
      :output_files => [__dir__ + "/../src/cmake-build-macos/libsilk_decoder.a"],
    }

    # Flutter.framework does not contain a i386 slice.
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
      'OTHER_LDFLAGS' => '-force_load ' + __dir__ + '/../src/cmake-build-macos/libsilk_decoder.a' + ' -force_load ' + __dir__ + '/../src/cmake-build-macos/silk/libsilk.a',
    }
  s.swift_version = '5.0'
end
