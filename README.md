# 魔方 App（Flutter / iOS）

- **自由玩**：3D 魔方（puzzle_cube），手指拖拽转层、空白处拖动旋转视角；打乱后转第一下自动开始计时，还原后自动停止并记录成绩；点击计时器可手动计时（实体魔方用）。
- **填色求解**：直接点击 3D 魔方上的色块填色（视角按固定顺序切换：魔方两侧 ◀ ▶ 按钮每次转 90°（金字塔 120°），依次看前→右→后→左面，最后翻到底面；不能手指拖动旋转，避免误触；「正面/背面」按钮一键跳到对应视角），色板显示每种颜色剩余数量、填满 9 个自动禁用；首次进入弹出手持姿势引导 → 校验（未填完提示 / 不可能的块 / 单角翻转 / 单棱翻色 / 奇偶，不可解时弹出专门提示）→ cuber（Kociemba 两阶段算法）在后台 Isolate 求解 → 3D 动画逐步演示（播放、暂停、上一步、下一步、点击步骤跳转）。
- **多种魔方**：二阶 / 三阶 / 四阶 / 五阶 / 金字塔。三阶用 puzzle_cube（本地分支）+ cuber；2/4/5 阶用自研 N 阶引擎（`lib/core/nxn/`）；金字塔用自研模型（`lib/core/pyraminx/`），都支持 3D 拖动转层、打乱、还原检测与计时。
- **花式教学（全部魔方）**：三阶 7 种、二阶 1 种、四阶 3 种、五阶 3 种、金字塔 3 种，3D 动画逐步演示，每个图案都有性质测试。
- **填色求解**：三阶（cuber）、二阶（≤11 步最优）、金字塔（层 ≤11 步最优 + 顶角）、四阶和五阶（降阶法，见下）都可求解。
  播放器显示各阶段（拼中心 / 配对棱块 / 奇偶校正 / 三阶求解），可点阶段跳转、单步、暂停，支持 1× / 2× / 4× 倍速。
  宽层转动（Rw、3Rw、Uw2 等）作为一步整体转动；播放时正在转的层保持明亮、其余层压暗，转完平滑恢复（只在播放器里启用）。
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

## 四阶 / 五阶求解（降阶法）

代码在 `lib/features/solver/domain/big_cube/`，全部基于自研 N 阶引擎（`NxnCubeState` 是唯一的状态来源）：

1. **拼中心**：这时角块和棱块还不需要保持，所以允许任意合法转动（单层、Rw/3Rw 宽层、2-3Rw 内层块），
   按“每转一次放好几块中心”挑选 ≤2 步序列、交换子 [A,B] 和带一步预备的 S[A,B]S'；少量剩余块用自动生成的
   纯三循环公式库（`PieceCycleLibrary`）收尾。四阶目标配色由角块推出（兼容任意拿法），五阶由正中心决定，
   角中心和棱中心一起拼。
2. **提前决定奇偶**：拼完中心时棱块排列的奇偶就已确定。四阶在中心阶段末尾用 7 步宽层序列
   `Lw2 2D' 2-3Rw2 Uw 2-3Rw2 Dw' Lw2`（中心全不变、翻转棱块奇偶）代替之后 15 步的 OLL 奇偶公式；
   并尝试几种开局，按“拼中心 + 实际配棱 + 奇偶”的真实转动数选最优。
3. **配对棱块**：小棱块纯三循环（必须保持中心）。四阶用匈牙利算法选移动最少的配对方案，并直接选与角块奇偶
   一致的排列，避免 PLL 奇偶；五阶按中棱确定目标，必要时用棱块奇偶公式。
4. **三阶求解**：提取等效三阶交给 cuber，解法换成外层转动执行。
5. **合并成宽层**：每段同轴连续转动改写为最少的整体转动（精确最少，广度优先表）。同时跑原纯交换子方案，
   取转动更少者，所以任何输入都不会比以前长。

每一步都在真实引擎上执行并检查（目标块到位、已完成的不被破坏、不该动的贴纸没动），最后把整套步骤在输入的全新副本上重放，必须还原，
否则报告内部错误而不是给出错误步骤。求解在后台 Isolate 运行，限时 30 秒。

## puzzle_cube 本地分支

`packages/puzzle_cube` 是 puzzle_cube 0.2.1（MIT）的本地副本：数据模型、手势、校验保持原样，
只把扁平的 DiTreDi 渲染换成了带光照、圆角高光贴纸、塑料块体和投影的 `RealisticCubeRenderer`，
2/4/5 阶引擎也共用这套渲染；另外动画时长改为可调（播放倍速）。改动记录见其 CHANGELOG。

## 魔方朝向约定

白色中心朝上、绿色中心朝前（红在右）。puzzle_cube 枚举名与渲染出来的面并不一致（例如它的 `u` 实际转的是画面中的底层），
`CubeNotation` 中的映射表是根据实际渲染结果推导并由测试验证的。

## 在手机上拿到安装包

推送到 GitHub 后，Actions 的 `CI` 工作流会：分析 + 测试 → 在 macOS 上 `flutter build ios --no-codesign`，
产物 `rubik_app_unsigned_ipa` 可在 Actions 运行页面下载，用 AltStore / Sideloadly / 巨魔等自签后安装。
