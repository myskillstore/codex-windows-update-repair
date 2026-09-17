# Codex Windows Update Repair

## 更新后、启动前的可选运行时同步

对于已配置本地重定位运行时的安装，可在更新脚本中加 `-SyncBundledRuntime`：新版注册成功后先静态检查，仅同步不一致文件并复查，再手动启动 Codex。默认不启动应用；运行中的 Codex、缺失源文件或路径异常会阻止同步。

```powershell
.\scripts\repair-codex-update.ps1 -SyncBundledRuntime
.\scripts\repair-codex-update.ps1 -Apply -SyncBundledRuntime
```

需要同时安装相邻的 `codex-windows-bundled-plugin-repair`，且授权须涵盖更新与运行时/相关配置/用户环境同步。Store 更新已经完成时，可先退出 Codex，再预览并授权执行 `scripts/sync-bundled-runtime-before-start.ps1 -Apply`。详见 [恢复流程](references/recovery.md)。浏览器连接仍须启动后在新会话验收。

Codex Windows Update Repair 是一个用于诊断和修复 Windows 上 Codex 桌面版更新卡住问题的开源 Skill，重点处理“点击更新后应用关闭，但版本没有变化”这类 Microsoft Store/MSIX 注册故障。
Codex Windows Update Repair is an open-source skill for diagnosing and repairing stuck Codex desktop updates on Windows, especially Microsoft Store/MSIX registration failures where the app closes but the installed version does not change.

[English README](README.en.md)

## 为什么需要它

Windows 上的 Codex 桌面版可能同时出现多个互相矛盾的状态：应用内提示有更新，`winget` 却显示没有升级；新包已经下载或暂存，Windows 实际启动的仍是旧版本；点击更新后应用关闭，却因为 Electron 子进程尚未完全退出而导致 AppX 注册失败。

这种问题很难仅凭界面判断。`download_completed` 不代表更新已经生效，`winget` 对 Microsoft Store 产品返回 `Version: Unknown` 时也无法证明当前版本是最新。反复点击更新、直接重置应用或卸载重装，可能中断任务或影响本地状态，却仍然没有解释根因。

这个 Skill 会先建立证据时间线，再区分：

- 正常的更新触发退出；
- Electron/Chromium 主进程崩溃；
- 已下载但尚未注册的 MSIX 包；
- 被残留应用进程阻止的 AppX 注册；
- Store、应用内更新清单与 `winget` 之间的版本不一致。

修复阶段默认只预演。只有用户明确授权后，脚本才会关闭属于 Codex Windows 包的桌面进程，并尝试注册已经暂存的最高版本；它不会自动重置、卸载或删除 Codex 数据。

## 适用范围

适合以下情况：

- Codex 长期显示“有更新”；
- 点击更新后 Codex 关闭，但不会重新启动；
- 手动打开后仍然显示待更新；
- `winget upgrade` 显示没有可用升级，但应用仍提示更新；
- AppX/Store 日志出现 `BlockedOnUser`、`0x80070005` 或“需要关闭 OpenAI.Codex”；
- 需要判断自动退出究竟是崩溃还是更新行为。

不适用于 Codex CLI 的普通升级，也不用于修复其他 Windows 应用。

## 安装

将仓库克隆到 Codex Skills 目录：

```powershell
$skillsRoot = if ($env:CODEX_HOME) {
  Join-Path $env:CODEX_HOME 'skills'
} else {
  Join-Path $env:USERPROFILE '.codex\skills'
}

git clone https://github.com/myskillstore/codex-windows-update-repair.git `
  (Join-Path $skillsRoot 'codex-windows-update-repair')
```

这段命令会在未设置 `CODEX_HOME` 时自动使用默认的 `~/.codex/skills` 目录。

重启 Codex 后，可以显式调用：

```text
使用 $codex-windows-update-repair 检查为什么我的 Windows Codex 更新一直卡住。
```

## 直接运行诊断脚本

只读诊断：

```powershell
.\scripts\diagnose-codex-update.ps1
```

保存经过基础路径脱敏的 JSON 报告：

```powershell
.\scripts\diagnose-codex-update.ps1 -OutputPath .\codex-update-diagnostics.json
```

分享报告前仍应人工检查其中是否包含敏感信息。

## 修复已经暂存但未注册的更新

必须在独立的 Windows Terminal 或 PowerShell 中运行，不能使用 Codex 内置终端。

先预演：

```powershell
.\scripts\repair-codex-update.ps1
```

确认当前任务已经保存后，再执行：

```powershell
.\scripts\repair-codex-update.ps1 -Apply
```

脚本还会显示一次高影响操作确认。修复完成后手动启动 Codex，并检查实际注册版本：

```powershell
Get-AppxPackage -Name OpenAI.Codex |
  Select-Object Name, Version, Status
```

## 安全边界

- 诊断默认只读。
- 修复必须显式使用 `-Apply`，并经过 PowerShell 确认。
- 修复脚本检测到自己运行在 Codex 进程树下时会拒绝执行。
- 不会删除日志、会话、项目或 `<CODEX_HOME>`。
- 不会自动 Reset、卸载或重装应用。
- 注册失败后只报告错误，不会无限重试。

## 项目结构

```text
SKILL.md
agents/openai.yaml
references/diagnostics.md
references/recovery.md
scripts/diagnose-codex-update.ps1
scripts/repair-codex-update.ps1
README.md
README.en.md
```

## 许可证

[MIT License](LICENSE)
