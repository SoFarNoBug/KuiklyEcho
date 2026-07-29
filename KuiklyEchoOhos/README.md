# @jlj/kuikly-echo-ohos

Kuikly 跨平台短音效播放模块的 **鸿蒙（OpenHarmony / HarmonyOS NEXT）** 原生实现，
与 Kotlin `commonMain` 侧 `EchoModule`（`moduleName = "KREchoModule"`）通过同名 Kuikly Module 桥接，
三端行为一致。

- 包名：`@jlj/kuikly-echo-ohos`
- 版本：`2026.7.29-1`
- Module 桥接名：`KREchoModule`
- 依赖：`@kuikly-open/render: 2.7.0`
- 适配：HarmonyOS NEXT / API 12+

## 特性

- 基于系统 `@ohos.multimedia.media` 的 `SoundPool`，适合播放短音效（点击声、提示音）。
- 支持并发播放多个短音效，互不阻塞。
- 内置 `soundId` 缓存，避免同一文件重复 `load`。
- 支持预加载（`preload`）与资源释放（`release`）。

## 能力映射

所有方法接收 JSON 字符串参数（由 Kuikly Module 机制透传）。

| 方法 | 参数（JSON） | 说明 |
| --- | --- | --- |
| `play` | `{ soundName: string, volume?: number }` | 播放音效（默认音量 1.0），并发安全；首次播放自动 `load` |
| `stop` | — | 停止所有正在播放的 stream |
| `preload` | `{ soundName: string }` | 预加载音效到 SoundPool，避免首次播放卡顿 |
| `release` | — | 释放 SoundPool 及缓存（页面销毁时建议调用） |

### 音效文件约定

- 文件须预置到应用沙箱目录：`{filesDir}/sounds/{soundName}`
- 支持 `SoundPool` 兼容格式（如 `.wav` / `.mp3` / `.ogg`）。

## 集成

### 1. 安装依赖

```bash
ohpm install @jlj/kuikly-echo-ohos
```

### 2. 注册 Module

在 `KuiklyViewDelegate` 的 `getCustomRenderModuleCreatorRegisterMap` 中以 `"KREchoModule"` 为 key 注册：

```typescript
import { KREchoModule } from '@jlj/kuikly-echo-ohos';

getCustomRenderModuleCreatorRegisterMap(): Map<string, () => KuiklyRenderBaseModule> {
  const map = new Map<string, () => KuiklyRenderBaseModule>();
  map.set("KREchoModule", () => new KREchoModule());
  return map;
}
```

### 3. 预置音效文件

将音效文件拷贝到应用沙箱 `filesDir/sounds/` 目录（例如通过 `Context` 拷贝 `rawfile` 资源，或在构建期预置）。

### 4. 业务侧调用（Kotlin commonMain）

Kotlin 侧封装详见主库
[KuiklyEcho](https://github.com/SoFarNoBug/KuiklyEcho)：

```kotlin
EchoModule.play("click.mp3", volume = 1.0f)
EchoModule.preload("click.mp3")
EchoModule.release()
```

## 注意事项

- 仅适合短音效；长音频请使用 `AVPlayer`。
- `SoundPool` 最大并发流由创建参数决定（本库默认 5 路）。
- 页面销毁或不再使用音效时调用 `release` 释放系统资源。

## 许可

MIT © 2026 jlj
