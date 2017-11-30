#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'chq_native_ads'
  s.version          = '0.0.1'
  s.summary          = 'Native ads for ClanHQ'
  s.description      = <<-DESC
Native ads for ClanHQ
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Carnivore, Inc.' => 'dev@carnivorestudios.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'FBAudienceNetwork', '~> 4.24.0'
  
  s.ios.deployment_target = '8.0'
end

