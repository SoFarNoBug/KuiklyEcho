/*
 * KREchoModule.ets
 *
 * 鸿蒙侧短音效播放模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 EchoModule（moduleName = "KREchoModule"）桥接，
 * 在 KuiklyViewDelegate 的 getCustomRenderModuleCreatorRegisterMap 中以同名注册。
 *
 * 能力映射（基于 @ohos.multimedia.media SoundPool）：
 *  - play     -> soundPool.play(soundId, {volume})
 *  - stop     -> soundPool.stop() + soundPool.release()
 *  - preload  -> soundPool.load(filePath)
 *  - release  -> soundPool.release()
 *
 * 说明：
 *  - 鸿蒙 SoundPool 支持并发播放多个短音效。
 *  - 音效文件从 rawfile 目录加载。
 *  - 维护 soundIdMap 缓存，避免重复加载。
 *
 * 注意：本文件属于独立发布库 KuiklyEchoOhos（待联调，无本地鸿蒙编译环境）。
 */

import { common } from '@kit.AbilityKit';
import { KuiklyRenderBaseModule } from '@kuikly-open/render';
import { KuiklyRenderCallback } from '@kuikly-open/render';
import media from '@ohos.multimedia.media';

export class KREchoModule extends KuiklyRenderBaseModule {
  static readonly MODULE_NAME = "KREchoModule";
  static readonly METHOD_PLAY = "play";
  static readonly METHOD_STOP = "stop";
  static readonly METHOD_PRELOAD = "preload";
  static readonly METHOD_RELEASE = "release";

  private soundPool?: media.SoundPool;
  private soundPoolPromise?: Promise<media.SoundPool>;
  private soundIdMap: Map<string, number> = new Map();
  private activeStreamIds: Set<number> = new Set();

  syncMode(): boolean {
    return false;
  }

  call(method: string, params: KRAny, callback: KuiklyRenderCallback): KRAny {
    switch (method) {
      case KREchoModule.METHOD_PLAY:
        this.handlePlay(params);
        break;
      case KREchoModule.METHOD_STOP:
        this.handleStop();
        break;
      case KREchoModule.METHOD_PRELOAD:
        this.handlePreload(params);
        break;
      case KREchoModule.METHOD_RELEASE:
        this.handleRelease();
        break;
      default:
        break;
    }
    return null;
  }

  private parseParams(params: KRAny): Record<string, Object> {
    if (!params) {
      return {};
    }
    try {
      return JSON.parse(params as string) as Record<string, Object>;
    } catch (e) {
      return {};
    }
  }

  private async ensureSoundPool(): Promise<media.SoundPool> {
    if (this.soundPool) {
      return this.soundPool;
    }
    if (this.soundPoolPromise) {
      return this.soundPoolPromise;
    }
    this.soundPoolPromise = media.createSoundPool().then((pool) => {
      this.soundPool = pool;
      this.soundPoolPromise = undefined;
      return pool;
    });
    return this.soundPoolPromise;
  }

  private async loadSound(soundName: string): Promise<number> {
    const cached = this.soundIdMap.get(soundName);
    if (cached !== undefined) {
      return cached;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const filePath = context.filesDir + '/sounds/' + soundName;
      const pool = await this.ensureSoundPool();
      const soundId = await pool.load(filePath);
      this.soundIdMap.set(soundName, soundId);
      return soundId;
    } catch (e) {
      console.error("[KREchoModule] loadSound error: " + (e as Error).message);
      return -1;
    }
  }

  private async handlePlay(params: KRAny): Promise<void> {
    const p = this.parseParams(params);
    const soundName = (p["soundName"] as string) ?? "";
    const volume = (p["volume"] as number) ?? 1.0;
    if (!soundName) return;

    try {
      const soundId = await this.loadSound(soundName);
      if (soundId === -1) return;
      const pool = await this.ensureSoundPool();
      const streamId = await pool.play({
        soundId: soundId,
        streamInfo: {
          audioSampleRate: media.AudioSamplingRate.SAMPLE_RATE_44100,
          channels: media.AudioChannel.CHANNEL_1,
          sampleFormat: media.AudioSampleFormat.SAMPLE_FORMAT_S16LE
        },
        streamOptions: {
          priority: 0,
          loop: 0,
          volume: volume,
          rate: 1.0
        }
      });
      this.activeStreamIds.add(streamId);
    } catch (e) {
      console.error("[KREchoModule] play error: " + (e as Error).message);
    }
  }

  private async handleStop(): Promise<void> {
    try {
      if (this.soundPool) {
        for (const streamId of this.activeStreamIds) {
          await this.soundPool.stop(streamId);
        }
      }
      this.activeStreamIds.clear();
    } catch (e) {
      console.error("[KREchoModule] stop error: " + (e as Error).message);
    }
  }

  private async handlePreload(params: KRAny): Promise<void> {
    const p = this.parseParams(params);
    const soundName = (p["soundName"] as string) ?? "";
    if (!soundName) return;
    await this.loadSound(soundName);
  }

  private async handleRelease(): Promise<void> {
    try {
      if (this.soundPool) {
        await this.soundPool.release();
        this.soundPool = undefined;
      }
      this.soundPoolPromise = undefined;
      this.soundIdMap.clear();
      this.activeStreamIds.clear();
    } catch (e) {
      console.error("[KREchoModule] release error: " + (e as Error).message);
    }
  }
}
