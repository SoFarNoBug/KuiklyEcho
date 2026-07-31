/*
 * KREchoModule.ets
 *
 * 鸿蒙侧短音效播放模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 EchoModule（moduleName = "KREchoModule"）桥接，
 * 在 KuiklyViewDelegate 的 getCustomRenderModuleCreatorRegisterMap 中以同名注册。
 *
 * 能力映射（基于 @ohos.multimedia.media SoundPool，适配 HarmonyOS NEXT / API 12+）：
 *  - play     -> soundPool.play(soundId, volume, priority, loop, rate)
 *  - stop     -> soundPool.stop(streamId)
 *  - preload  -> soundPool.load(filePath)
 *  - release  -> soundPool.release()
 *
 * 说明：
 *  - 鸿蒙 SoundPool 支持并发播放多个短音效。
 *  - 音效文件从应用 rawfile/sounds 目录加载（须手动同步 shared 资源到
 *    entry/src/main/resources/rawfile/sounds，rawfile 不落地为普通文件，
 *    不能走 filesDir 路径，否则 SoundPool.load 报 resource path is invalid）。
 *  - 通过 resourceManager.getRawFd 取得 rawfile 文件描述符后交给
 *    soundPool.load(fd, offset, length) 播放。
 *  - 维护 soundIdMap 缓存，避免重复加载。
 */

import { common } from '@kit.AbilityKit';
import { KuiklyRenderBaseModule, KuiklyRenderCallback, KTAny } from '@kuikly-open/render';
import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';

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
  private loadCompleteResolvers: Map<number, () => void> = new Map();

  syncMode(): boolean {
    return false;
  }

  call(method: string, params: KTAny, callback: KuiklyRenderCallback): KTAny {
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

  private parseParams(params: KTAny): Record<string, Object> {
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
    const renderInfo: audio.AudioRendererInfo = {
      // 短音效走媒体/音乐流，确保路由到扬声器并受媒体音量控制。
      // 用 STREAM_USAGE_UNKNOWN 会被系统判为未知用途，管线跑完却无输出。
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    };
    this.soundPoolPromise = media.createSoundPool(5, renderInfo).then((pool) => {
      this.setupSoundPoolListeners(pool);
      this.soundPool = pool;
      this.soundPoolPromise = undefined;
      return pool;
    });
    return this.soundPoolPromise;
  }

  private setupSoundPoolListeners(pool: media.SoundPool): void {
    // 官方规范：loadComplete / playFinished / error 监听必须在 load 之前注册，
    // 且只有收到 loadComplete 回调（对应 soundId 真正解码就绪）后才能安全 play。
    pool.on('loadComplete', (soundId: number) => {
      console.info('[KREchoModule] loadComplete soundId=' + soundId);
      const resolve = this.loadCompleteResolvers.get(soundId);
      if (resolve) {
        this.loadCompleteResolvers.delete(soundId);
        resolve();
      }
    });
    pool.on('playFinished', () => {
      console.info('[KREchoModule] playFinished');
    });
    pool.on('error', (error: BusinessError) => {
      console.error('[KREchoModule] soundPool error code=' + error.code + ' msg=' + error.message);
    });
  }

  private waitLoadComplete(soundId: number): Promise<void> {
    // 等待对应 soundId 的 loadComplete；加 1.5s 超时兜底，避免加载异常时 play 永久挂起。
    return new Promise<void>((resolve) => {
      this.loadCompleteResolvers.set(soundId, resolve);
      setTimeout(() => {
        if (this.loadCompleteResolvers.get(soundId) === resolve) {
          this.loadCompleteResolvers.delete(soundId);
          resolve();
        }
      }, 1500);
    });
  }

  private async loadSound(soundName: string): Promise<number> {
    const cached = this.soundIdMap.get(soundName);
    if (cached !== undefined) {
      return cached;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      // rawfile 资源不落地为普通文件，不能拼 filesDir 路径（load 报 resource path invalid）。
      // 也不能走 getRawFd + SoundPool.load(fd,...)：load(fd) 的 Promise 会提前返回
      // soundId（数据尚未读完），若紧接着 closeRawFd 关闭描述符，SoundPool 后续惰性读样本
      // 时 fd 已失效 -> 读到空数据 -> 渲染器「播放成功却无声」。
      // 因此改为 getRawFileContent 读成字节缓冲，再用 SoundPool.load(buffer) 加载，
      // 彻底绕开 fd 生命周期竞态。
      // 注意：官方 API 参考未列出 ArrayBuffer 重载（rawfile 文档化路径为
      // load(fd, offset, length)）。当前 load(buffer) 在实测设备上可正常出声，但属未文档化
      // 用法；如需 100% 贴合官方规范，可改回 load(fd, offset, length) 并保留 fd 直至 release
      // 时再 closeRawFd（官方明确警告：将 fd 交给 load 后不要对其再做读写/关闭等操作）。
      const soundPath = 'sounds/' + soundName;
      const buffer = await this.readRawFileBuffer(context, soundPath);
      const pool = await this.ensureSoundPool();
      // 官方 SoundPool.load 类型仅声明 (uri: string) 与 (fd, offset, length) 两个重载，
      // 未声明 ArrayBuffer 重载；但运行时支持 load(buffer)（已实测 Mate 60 Pro 可出声）。
      // 此处用 as any 绕过类型声明缺失，load 实际同步返回 number 类型的 soundId。
      const soundId: number = (pool as any).load(buffer);
      // 官方规范：load 返回的 soundId 仅代表已提交加载任务，真正就绪由 loadComplete 事件标识，
      // 必须在 loadComplete 之后才能安全 play。
      await this.waitLoadComplete(soundId);
      this.soundIdMap.set(soundName, soundId);
      return soundId;
    } catch (e) {
      console.error("[KREchoModule] loadSound error: " + (e as Error).message);
      return -1;
    }
  }

  private readRawFileBuffer(context: common.UIAbilityContext, path: string): Promise<ArrayBuffer> {
    return new Promise<ArrayBuffer>((resolve, reject) => {
      context.resourceManager.getRawFileContent(path, (error: BusinessError, value: Uint8Array) => {
        if (error) {
          reject(error);
          return;
        }
        // 取出干净的 ArrayBuffer（避免 Uint8Array 视图偏移问题）交给 SoundPool.load。
        const ab = value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength);
        resolve(ab);
      });
    });
  }

  private async handlePlay(params: KTAny): Promise<void> {
    const p = this.parseParams(params);
    const soundName = (p["soundName"] as string) ?? "";
    const volume = (p["volume"] as number) ?? 1.0;
    if (!soundName) return;

    try {
      const soundId = await this.loadSound(soundName);
      if (soundId === -1) return;
      const pool = await this.ensureSoundPool();
      const streamId: number = await pool.play(soundId, {
        leftVolume: volume,
        rightVolume: volume,
        loop: 0,
        rate: 1.0
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

  private async handlePreload(params: KTAny): Promise<void> {
    const p = this.parseParams(params);
    const soundName = (p["soundName"] as string) ?? "";
    if (!soundName) return;
    await this.loadSound(soundName);
  }

  private async handleRelease(): Promise<void> {
    try {
      if (this.soundPool) {
        // 官方规范：release 前应 unload 已加载资源，并注销所有事件监听，避免资源泄漏。
        for (const soundId of this.soundIdMap.values()) {
          try {
            await this.soundPool.unload(soundId);
          } catch (e) {
            console.error("[KREchoModule] unload error: " + (e as Error).message);
          }
        }
        this.soundPool.off('loadComplete');
        this.soundPool.off('playFinished');
        this.soundPool.off('error');
        await this.soundPool.release();
        this.soundPool = undefined;
      }
      this.soundPoolPromise = undefined;
      this.soundIdMap.clear();
      this.activeStreamIds.clear();
      this.loadCompleteResolvers.clear();
    } catch (e) {
      console.error("[KREchoModule] release error: " + (e as Error).message);
    }
  }
}
