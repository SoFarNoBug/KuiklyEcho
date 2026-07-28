/*
 * LocalEchoModule.kt
 *
 * 把 [EchoModule] 以 CompositionLocal 形式提供给 Compose 子树，
 * 便于页面内通过 LocalEchoModule.current 直接调用音效播放能力，
 * 无需每次 acquireModule。
 *
 * 注入示例（请在容器 Pager 的 setContent 内）：
 *   CompositionLocalProvider(LocalEchoModule provides echoModule) {
 *       Content()
 *   }
 * 其中 echoModule 在 created() 之后通过
 *   val echoModule = pager.acquireModule(EchoModule.MODULE_NAME)
 * 获取。
 *
 * 本文件属于独立发布库 KuiklyEcho（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.echo

import androidx.compose.runtime.compositionLocalOf

public val LocalEchoModule = compositionLocalOf<EchoModule> {
    error("LocalEchoModule 未提供：请在容器 Pager 的 setContent 中通过 CompositionLocalProvider 注入 EchoModule。")
}
