Pod::Spec.new do |s|
  s.name = 'Promises'
  s.version = '1.0.3'
  s.license = 'MIT'
  s.summary = 'A simple promise implementation in Swift'
  s.homepage = 'https://github.com/dmgctrl/Promises-Swift'
  s.authors = { 'Tonic Design' => 'info@tonicdesign.com' }
  s.source = { :git => 'https://github.com/dmgctrl/Promises-Swift.git', :tag => s.version }
  s.dependency 'Queue', '~> 1.1.0' 

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Promises/*.swift'

  s.requires_arc = true
end
