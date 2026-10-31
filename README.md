# 魔方 App（Flutter / iOS）

- **自由玩**：3D 魔方（puzzle_cube），手指拖拽转层、空白处拖动旋转视角；打乱后转第一下自动开始计时，还原后自动停止并记录成绩；点击计时器可手动计时（实体魔方用）。
- **填色求解**：直接点击 3D 魔方上的色块填色（拖动旋转视角，一键切正面/背面），色板显示每种颜色剩余数量、填满 9 个自动禁用；首次进入弹出手持姿势引导 → 校验（未填完提示 / 不可能的块 / 单角翻转 / 单棱翻色 / 奇偶，不可解时弹出专门提示）→ cuber（Kociemba 两阶段算法）在后台 Isolate 求解 → 3D 动画逐步演示（播放、暂停、上一步、下一步、点击步骤跳转）。
- **多种魔方**：二阶 / 三阶 / 四阶 / 五阶 / 金字塔。三阶用 puzzle_cube（本地分支）+ cuber；2/4/5 阶用自研 N 阶引擎（`lib/core/nxn/`）；金字塔用自研模型（`lib/core/pyraminx/`），都支持 3D 拖动转层、打乱、还原检测与计时。
- **花式教学（全部魔方）**：三阶 7 种、二阶 1 种、四阶 3 种、五阶 3 种、金字塔 3 种，3D 动画逐步演示，每个图案都有性质测试。
- **填色求解**：三阶（cuber）、二阶（≤11 步最优）、金字塔（层 ≤11 步最优 + 顶角）可求解；四/五阶可填色与校验，求解（降阶法）开发中。
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
    pyraminx/                      # 金字塔：几何模型、求解、渲染、手势
    solver/facelet_solver.dart     # 通用双向搜索求解内核（二阶、金字塔）
    prefs/shared_prefs_provider.dart
    utils/time_format.dart
  features/
    home/                          # 底部导航
    puzzles/                       # 魔方类型选择
    patterns/                      # 花式教学（全部魔方）
    player/                        # 通用逐步动画播放器
    pyraminx/                      # 金字塔打乱公式
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
