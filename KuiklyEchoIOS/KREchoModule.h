//
//  KREchoModule.h
//  KuiklyEchoIOS
//
//  短音效播放模块（iOS 侧 Kuikly 原生 Module 实现）。
//  类名必须精确等于 moduleName（"KREchoModule"），Kuikly 运行时按类名动态创建实例，无需显式注册。
//
//  能力映射（基于 AVAudioPlayer）：
//   - play     -> 创建 AVAudioPlayer 实例并播放（支持多实例并发）
//   - stop     -> 遍历所有 player 调用 stop
//   - preload  -> 创建 AVAudioPlayer + prepareToPlay（预加载到内存）
//   - release  -> 遍历 stop + removeAllObjects（释放资源）
//
//  说明：
//   - 音效文件从 App Bundle 的 sounds/ 子目录加载。
//   - AVAudioSession category 设为 Ambient，不中断其他音频播放。
//   - 支持同时播放多个音效（每个 AVAudioPlayer 实例独立）。
//
//  本文件属于独立发布库 KuiklyEchoIOS（groupId=com.jlj.kuiklybase）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenKuiklyIOSRender/KRBaseModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface KREchoModule : KRBaseModule

@end

NS_ASSUME_NONNULL_END
