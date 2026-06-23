platform :tvos, '17.0'
use_frameworks!

# Inhibit warnings from pods so our CI only shows first-party issues.
inhibit_all_warnings!

target 'Reef' do
  pod 'TVVLCKit', '~> 3.7'
end

# ReefTests does not need MobileVLCKit — VLC engine is not unit-tested.
target 'ReefTests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '17.0'
      # Silence deprecation warnings inside vendored pod code.
      config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
    end
  end
end
