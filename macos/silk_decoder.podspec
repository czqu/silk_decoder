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


  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.library = 'c++'
  s.prepare_command = 'bash build_macos.sh'
  s.script_phase = {
  :name => 'Trigger Native Build',
  # First argument is relative path to the `rust` folder, second is name of rust library
  :script => 'ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/build_phony"',
  :execution_position=> :before_compile,
  :input_files => ['{BUILT_PRODUCTS_DIR}/build_phony'],
  :output_files => [__dir__ + "/../src/cmake-build-macos/libsilk_decoder.a"],
}
   s.pod_target_xcconfig = {
  'DEFINES_MODULE' => 'YES',
  'OTHER_LDFLAGS' => '-force_load ' + __dir__ + '/../src/cmake-build-macos/libsilk_decoder.a' + ' -force_load ' + __dir__ + '/../src/cmake-build-macos/silk/libsilk.a',
}


  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.swift_version = '5.0'
end
