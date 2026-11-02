# RS_DQR

统一入口（按 `game.GameId` 自动选择对应发布产物）：

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/Robleisi/RS_DQR@main/loader.lua"))()
```

| 游戏 | GameId | 发布文件 |
|---|---|---|
| DQ classic | 848145103 | `Robleisi_DQ_classic_release.lua` |
| DQ Reborn | 9931749389 | `Robleisi_DQR_release.lua` |
| Heavyweight Fishing | 8342498724 | `Robleisi_HWF_release.lua` |
| Throw Food For Animals | 10766972131 | `Robleisi_ThrowFood_release.lua`（待发布） |

当前发布戳：

- DQ Reborn：**2026-09-20a**
- DQ classic：**2026-10-05b**
- Heavyweight Fishing：**2026-10-31a**
- Throw Food For Animals：源码 `dev/ThrowFood.lua`（待发布）

源码位于主仓库 `dev/`（`dev/DQR.lua`、`dev/DQ_classic.lua`、`dev/HWF.lua`、`dev/Universal.lua`、`dev/ThrowFood.lua`），本仓库只存放混淆产物与入口 loader。
