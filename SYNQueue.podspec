
Pod::Spec.new do |s|
  s.name             = "SYNQueue"
  s.version          = "0.2.2"
  s.summary          = "SYNQueue"
  s.description      = "A simple yet powerful queueing system for iOS (with persistence)"
  s.homepage         = "https://github.com/THREDOpenSource/SYNQueue"
  s.license          = 'MIT'
  s.author           = { "John Hurliman" => "johnh@thredhq.com", "Sidhant Gandhi" => "sidhant.gandhi@gmail.com" }
  s.source           = { :git => "https://github.com/THREDOpenSource/SYNQueue.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'SYNQueue/SYNQueue/**.swift'
end
