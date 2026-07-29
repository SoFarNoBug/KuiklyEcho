# KuiklyEcho

跨端手机短音效播放 Kuikly Module，仿 [KuiklySensors](https://github.com/Tencent/KuiklySensors) 的 KMP 多模块发布结构，支持 Android / iOS / 鸿蒙 三端独立发布。与 KuiklyAudio（长音频播放）完全解耦，底层使用 SoundPool（Android）/ AVAudioPlayer（iOS）/ SoundPool（鸿蒙）引擎，支持并发播放、延迟 < 50ms。

- 库名：`KuiklyEcho`
- Maven 坐标：`io.github.sofarnobug:kuiklyecho`（KMP 公共层）/ `io.github.sofarnobug:kuiklyechoandroid`（Android 原生层）
- 源码包名：`com.jlj.kuiklybase.echo`（含作者缩写 jlj，与 Maven groupId 解耦）
- 桥接名（四端一致）：`KREchoModule`
- 分发：发布到 **Maven Central**，开发者免凭证直接 `implementation` 集成

## 模块构成

| 模块 | 平台 | 产物 | 说明 |
| --- | --- | --- | --- |
| `KuiklyEcho` | KMP 公共层（android/ios/js） | Maven Central `io.github.sofarnobug:kuiklyecho` | `EchoModule` + `LocalEchoModule` |
| `KuiklyEchoAndroid` | Android 原生 | Maven Central `io.github.sofarnobug:kuiklyechoandroid` | `KREchoModule`（继承 KuiklyRenderBaseModule） |
| `KuiklyEchoIOS` | iOS 原生 | CocoaPods `KuiklyEcho` | `KREchoModule.h/.m` |
| `KuiklyEchoOhos` | 鸿蒙原生 | ohpm `@jlj/kuikly-echo-ohos` | `KREchoModule.ets` |

## 能力 API（commonMain）

```kotlin
val em = pager.acquireModule<EchoModule>(EchoModule.MODULE_NAME)

em.play("click.wav")                       // 播放音效（默认音量 1.0）
em.play("success.mp3", volume = 0.6f)      // 指定音量 0.0~1.0
em.preload("click.wav")                    // 预加载到内存，后续 play 零延迟
em.stop()                                  // 停止所有正在播放的音效
em.release()                               // 释放所有资源（需重新 preload/play 才能继续使用）
```

Compose 中使用 `LocalEchoModule`（在容器 Pager 的 `setContent` 内通过 `CompositionLocalProvider` 注入）：

```kotlin
val echo = LocalEchoModule.current
echo.play("click.wav")
```

### API 速查

| 方法 | 参数 | 说明 |
| --- | --- | --- |
| `play(soundName, volume)` | `soundName`: 音效文件名（含扩展名）<br>`volume`: 音量 0.0~1.0（默认 1.0） | 播放音效 |
| `stop()` | — | 停止所有正在播放的音效 |
| `preload(soundName)` | `soundName`: 音效文件名 | 预加载音效到内存，后续 play 零延迟 |
| `release()` | — | 释放所有资源，需重新 preload/play 才能继续使用 |

### 音效资源目录

将音效文件放入各平台 App 的对应目录：

| 平台 | 目录 |
| --- | --- |
| Android | `androidApp/src/main/assets/sounds/` |
| iOS | App Bundle 的 `sounds/` 子目录（添加到 Xcode bundle resources） |
| 鸿蒙 | `ohosApp/src/main/resources/rawfile/sounds/` |

### 支持的音频格式

| 格式 | Android | iOS | 鸿蒙 | 推荐 |
| --- | --- | --- | --- | --- |
| WAV | ✅ | ✅ | ✅ | 无损、加载快，推荐 |
| MP3 | ✅ | ✅ | ✅ | 体积小，兼容性好 |
| AAC | ✅ | ✅ | ✅ | — |
| OGG | ✅ | ❌ | ✅ | iOS 不支持，不推荐跨端使用 |

## 集成方式

已发布到 **Maven Central**，无需任何 token，直接在依赖处添加 `mavenCentral()` 源即可。

### Android（Maven Central）

`shared/build.gradle.kts`（KMP 公共层，提供 API）：

```kotlin
dependencies {
    implementation("io.github.sofarnobug:kuiklyecho:0.0.1-2.1.21")
}
```

`androidApp/build.gradle.kts`（Android 原生实现）：

```kotlin
dependencies {
    implementation("io.github.sofarnobug:kuiklyechoandroid:0.0.1-2.1.21")
}
```

仓库源（通常新建工程已默认包含 `mavenCentral()`）：

```kotlin
dependencyResolutionManagement {
    repositories { mavenCentral() }
}
```

本地验证可先发布到 `mavenLocal`，坐标不变。

### iOS（CocoaPods）

```ruby
pod 'KuiklyEcho'
```

### 鸿蒙（ohpm）

```bash
ohpm install @jlj/kuikly-echo-ohos
```

并在 `KuiklyViewDelegate` 的 `getCustomRenderModuleCreatorRegisterMap` 中注册 `KREchoModule`。

## 发布

```bash
# 发布到 Maven Central（默认，需 CENTRAL_USERNAME / CENTRAL_PASSWORD 环境变量）
TARGET=central ./publish-maven.sh

# 或发布到 GitHub Packages（自用兜底）
TARGET=github MAVEN_USERNAME=xxx MAVEN_PASSWORD=xxx ./publish-maven.sh
```

iOS Pod / 鸿蒙 HAR 按 `publish-maven.sh` 顶部说明单独发布。

## 桥接契约

`MODULE_NAME = "KREchoModule"` 在四端必须完全一致：

- Android 原生类名 / 注册名：`KREchoModule` 以同名注册
- iOS 原生类名：`KREchoModule`（Kuikly 运行时按类名动态创建）
- 鸿蒙注册名：`KREchoModule` 以同名注册

## 许可

MIT
