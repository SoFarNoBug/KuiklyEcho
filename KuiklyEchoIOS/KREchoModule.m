//
//  KREchoModule.m
//  KuiklyEchoIOS
//
//  短音效播放模块（iOS 侧 Kuikly 原生 Module 实现）。
//  详细说明见 KREchoModule.h。本文件属于独立发布库 KuiklyEchoIOS。
//

#import "KREchoModule.h"
#import <AVFoundation/AVFoundation.h>

@interface KREchoModule ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVAudioPlayer *> *playerCache;
// player -> cacheKey 反向映射，用于播放结束回调时定位 key
// 用 NSMutableDictionary 而非 NSMapTable：NSMapTable 部分初始化器在低版本 iOS 不可用。
// key 用 NSValue(valueWithNonretainedObject:) 包裹 player：AVAudioPlayer 不遵守 NSCopying，
// 不能直接作字典 key（否则 setObject:forKey: 发 copyWithZone: 崩溃）。finish/stop/release 时清理，无泄漏。
@property (nonatomic, strong) NSMutableDictionary<NSValue *, NSString *> *playerToKey;
@end

@implementation KREchoModule

#pragma mark - 播放音效
- (void)play:(NSDictionary *)args {
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSString *soundName = params[@"soundName"];
    if (soundName == nil || [soundName length] == 0) return;

    NSNumber *v = params[@"volume"];
    float volume = (v && [v isKindOfClass:[NSNumber class]]) ? [v floatValue] : 1.0;
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    [self ensureAudioSession];

    // 优先复用 preload 已准备好的 player（零延迟），否则创建新实例。
    NSString *preloadKey = [NSString stringWithFormat:@"preload_%@", soundName];
    AVAudioPlayer *player = [self.playerCache objectForKey:preloadKey];
    if (player) {
        // 复用预加载实例：重置到开头，避免从上次结束位置播放
        [self.playerCache removeObjectForKey:preloadKey];
        player.currentTime = 0;
    } else {
        // 每次 play 创建新 AVAudioPlayer 实例，支持并发播放
        player = [self createPlayerWithSoundName:soundName];
    }
    if (player == nil) return;

    // 先设置 delegate 和 cache，再 play，避免极短音效播放完毕后 delegate 回调丢失
    player.delegate = (id<AVAudioPlayerDelegate>)self;
    NSString *key = [NSString stringWithFormat:@"%@_%p", soundName, player];
    self.playerCache[key] = player;
    [self.playerToKey setObject:key forKey:[NSValue valueWithNonretainedObject:player]];

    player.volume = volume;
    [player play];
}

#pragma mark - 停止所有播放
- (void)stop:(NSDictionary *)args {
    for (AVAudioPlayer *player in [self.playerCache allValues]) {
        [player stop];
    }
    [self.playerCache removeAllObjects];
    [self.playerToKey removeAllObjects];
}

#pragma mark - 预加载音效
- (void)preload:(NSDictionary *)args {
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSString *soundName = params[@"soundName"];
    if (soundName == nil || [soundName length] == 0) return;

    [self ensureAudioSession];

    AVAudioPlayer *player = [self createPlayerWithSoundName:soundName];
    if (player == nil) return;

    [player prepareToPlay];

    // 缓存预加载的 player
    NSString *key = [NSString stringWithFormat:@"preload_%@", soundName];
    self.playerCache[key] = player;
}

#pragma mark - 释放所有资源
- (void)release:(NSDictionary *)args {
    for (AVAudioPlayer *player in [self.playerCache allValues]) {
        [player stop];
    }
    [self.playerCache removeAllObjects];
    [self.playerToKey removeAllObjects];
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSValue *playerKey = [NSValue valueWithNonretainedObject:player];
    NSString *key = [self.playerToKey objectForKey:playerKey];
    [self.playerToKey removeObjectForKey:playerKey];
    if (key) {
        [self.playerCache removeObjectForKey:key];
    }
}

#pragma mark - 内部方法
- (AVAudioPlayer *)createPlayerWithSoundName:(NSString *)soundName {
    NSString *path = [[NSBundle mainBundle] pathForResource:soundName ofType:nil inDirectory:@"sounds"];
    if (path == nil) {
        // 尝试直接从 Bundle 根目录加载
        path = [[NSBundle mainBundle] pathForResource:soundName ofType:nil];
    }
    if (path == nil) {
        NSLog(@"[KREchoModule] sound file not found: %@", soundName);
        return nil;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error || player == nil) {
        NSLog(@"[KREchoModule] create player error: %@", error.localizedDescription);
        return nil;
    }
    return player;
}

- (void)ensureAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    // 反馈音效类：改用 Playback 而非 Ambient，使 UI 提示音不被设备静音/响铃键压制；
    // MixWithOthers 保证不中断后台音乐等其他音频。
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&error];
    if (error) {
        NSLog(@"[KREchoModule] setCategory error: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
}

- (NSMutableDictionary<NSString *, AVAudioPlayer *> *)playerCache {
    if (_playerCache == nil) {
        _playerCache = [NSMutableDictionary dictionary];
    }
    return _playerCache;
}

- (NSMutableDictionary<NSValue *, NSString *> *)playerToKey {
    if (_playerToKey == nil) {
        _playerToKey = [NSMutableDictionary dictionary];
    }
    return _playerToKey;
}

@end
