Pod::Spec.new do |s|
  s.name             = "Havrefras"
  s.version          = "0.0.1"
  s.summary          = "A variant of a healthful serializer for your HealthKit data."
  s.homepage         = "https://github.com/carechain/Havrefras"
  s.license          = { :type => 'Apache 2.0',
                         :file => 'LICENSE' }
  s.authors          = { "Brent Hargrave" => "brent@brent.is",
                         "Chris Schaefbauer" => "chris.schaefbauer@openmhealth.org",
                         "Emerson Farrugia" => "emerson@openmhealth.org",
                         "Simona Carini" => "simona@openmhealth.org", "Johan Sellström" => "johan@carechain.io" }
  s.source           = { :git => "https://github.com/carechain/Havrefras.git",
                         :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/openmhealth'
  s.platform         = :ios, '7.0'
  s.requires_arc     = true
  s.source_files     = 'Pod/Classes/**/*'
  s.frameworks       = 'HealthKit'
  s.dependency 'ObjectiveSugar', '~> 1.1'
end
