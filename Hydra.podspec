Pod::Spec.new do |s|
  s.name         = "Hydra"
  s.version      = "2.0.0"
  s.summary      = ""
  s.description  = <<-DESC
    Promises & Await: Write better async in Swift
  DESC
  s.homepage     = "https://github.com/malcommac/Hydra"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Daniele Margutti" => "hello@danielemargutti.com" }
  s.social_media_url   = "https://twitter.com/danielemargutti"
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/malcommac/Hydra.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
  s.swift_version = "4.2"
end
