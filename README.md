# 魔方 App（Flutter / iOS）

- **自由玩**：3D 魔方（puzzle_cube），手指拖拽转层、空白处拖动旋转视角；打乱后转第一下自动开始计时，还原后自动停止并记录成绩；点击计时器可手动计时（实体魔方用）。
- **填色求解**：直接点击 3D 魔方上的色块填色（拖动旋转视角，一键切正面/背面），色板显示每种颜色剩余数量、填满 9 个自动禁用；首次进入弹出手持姿势引导 → 校验（未填完提示 / 不可能的块 / 单角翻转 / 单棱翻色 / 奇偶，不可解时弹出专门提示）→ cuber（Kociemba 两阶段算法）在后台 Isolate 求解 → 3D 动画逐步演示（播放、暂停、上一步、下一步、点击步骤跳转）。
- **多种魔方**：自由玩顶部可切换 二阶 / 三阶 / 四阶 / 五阶 / 金字塔。三阶用 puzzle_cube + cuber；2/4/5 阶用自研 N 阶引擎（`lib/core/nxn/`：数据模型、透视投影、画家算法渲染、拖动转层）；金字塔目前为实体计时模式（WCA 打乱 + 手动计时），3D 模型待开发。
- **花式教学（三阶）**：棋盘格、六面回字、四面回字、十字、六面 T 字、魔中魔、俄罗斯方块，3D 动画逐步演示。
- **成绩**：按魔方类型分别统计，单次成绩、最佳、平均、当前/最佳 ao5、ao12（WCA 去头尾平均），左滑删除。
- **架构**：Riverpod 状态管理，feature-first 目录。

## 目录结构

```
lib/
  main.dart / app.dart
  core/
    cube/cube_facelets.dart        # puzzle_cube <-> cuber 坐标与转动映射
    cube/sticker_hit_test.dart     # 3D 点击 -> 具体贴纸（复刻 DiTreDi 投影 + 背面剔除）
    cube/app_cube_controller.dart  # 视角拖动跟手（修正 puzzle_cube 的反向）
    nxn/                           # 自研 N 阶魔方引擎（2/4/5 阶）
    prefs/shared_prefs_provider.dart
    utils/time_format.dart
  features/
    home/                          # 底部导航
    puzzles/                       # 魔方类型选择
    patterns/                      # 花式教学
    pyraminx/                      # 金字塔（框架 + 打乱公式）
    free_play/application|presentation
    solver/domain|data|application|presentation
    stats/domain|data|application|presentation
test/                              # 映射、校验、ao5/ao12、播放、冒烟测试
```

## puzzle_cube 本地分支

`packages/puzzle_cube` 是 puzzle_cube 0.2.1（MIT）的本地副本：数据模型、手势、校验保持原样，
只把扁平的 DiTreDi 渲染换成了带光照、圆角高光贴纸、塑料块体和投影的 `RealisticCubeRenderer`，
2/4/5 阶引擎也共用这套渲染。改动记录见其 CHANGELOG。

## 魔方朝向约定

白色中心朝上、绿色中心朝前（红在右）。puzzle_cube 枚举名与渲染出来的面并不一致（例如它的 `u` 实际转的是画面中的底层），
`CubeNotation` 中的映射表是根据实际渲染结果推导并由测试验证的。

## 在手机上拿到安装包

推送到 GitHub 后，Actions 的 `CI` 工作流会：分析 + 测试 → 在 macOS 上 `flutter build ios --no-codesign`，
产物 `rubik_app_unsigned_ipa` 可在 Actions 运行页面下载，用 AltStore / Sideloadly / 巨魔等自签后安装。
