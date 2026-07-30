Pod::Spec.new do |spec|
  spec.name         = 'KuiklyEcho'
  spec.version      = '2026.7.30-3'
  spec.summary      = 'Kuikly Echo Sound Effect Module for iOS (KREchoModule)'
  spec.description  = '跨端短音效播放 Kuikly Module 的 iOS 原生实现（KREchoModule），基于 AVAudioPlayer。'
  spec.homepage     = 'https://github.com/SoFarNoBug/KuiklyEcho'
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { 'jlj' => 'jlj@example.com' }
  spec.source       = { :git => 'https://github.com/SoFarNoBug/KuiklyEcho.git', :tag => spec.version.to_s }
  spec.source_files = 'KuiklyEchoIOS/KREchoModule.{h,m}'
  spec.requires_arc = true
  spec.platform     = :ios, '11.0'
  spec.frameworks   = 'AVFoundation', 'UIKit'
  spec.dependency 'OpenKuiklyIOSRender'
  spec.swift_version = '5.0'
end
