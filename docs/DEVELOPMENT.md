# 开发文档

## 1. 文档维护约定

- `docs/DEVELOPMENT.md` 记录实现状态、模块职责、已知限制和开发约定。
- `docs/USAGE.md` 记录编译、运行、输入要求和验证方式。
- 后续只要发生下面任一变更，就同步更新这两个文档：
  - 新增或修改几何语法支持
  - 调整导出格式、命令行行为或默认输出策略
  - 增删 validation 用例
  - 修改构建方式或运行依赖

## 2. 当前项目状态

当前项目已经从最初的 skeleton 提升到“可针对一批 MCX XML 示例直接导出 VTK”的阶段。

当前重点能力：

- 读取 MCX XML 输入，未写 `@VIS3D` 指令时自动按表面模式导出 `.vtp`
- 支持 `VTI`、`VTP`、`VTU` 三种输出路径
- 支持以下 MCX 几何语法子集：
  - 轴对齐平面：`x-plane / plane-x / y-plane / plane-y / z-plane / plane-z`
  - 显式 `cylinder-z`
  - `sphere`
  - 平面围成的盒体 cell
  - 平面差集/外环类布尔区：
    - `((outer)~(inner)) extra`
    - `(-a|b|-c|d) outer-box`
  - `pin`
  - `particle`
  - 2D/3D `rectangular lattice`
  - cell `universe` 定义与递归 `fill`

当前已经在项目内完成回归验证的 MCX XML 用例：

- `validation/mcx_examples/pool.xml`
- `validation/mcx_examples/2G.xml`
- `validation/mcx_examples/VERA_1b.xml`
- `validation/mcx_examples/c5g7.xml`
- `validation/mcx_examples/pebble.xml`

## 3. 目录说明

- `src/`
  主源码目录
- `docs/`
  项目文档目录
- `validation/mcx_examples/`
  当前用于回归的 MCX XML 样例和生成的 `.vtp`
- `validation/run_mcx_examples.ps1`
  Windows 下的一键回归脚本
- `build-winlibs/`
  当前已验证可用的 Windows 构建目录

## 4. 关键模块

### `src/vis3d_driver.f90`

主调度入口，负责：

- 判断输入语法
- 读取 VIS3D 配置
- 生成宿主几何模型
- 解析 bbox
- 走 voxel 或 surface 导出路径

### `src/vis3d_input_mcx.f90`

MCX 输入配置解析。

当前行为：

- 如果存在 `@VIS3D` 注释，按指令读取配置
- 如果是普通 XML 且没有 `@VIS3D`，默认：
  - 启用导出
  - 模式为 `surface`
  - 格式为 `vtp`
  - 输出文件为输入文件同名 `.vtp`

### `src/vis3d_host_types.f90`

当前几何核心。

主要职责：

- 解析 MCX XML 中的 `surface / pin / particle / lattice / cell`
- 建立内部 primitive 模型：
  - `box_primitive_t`
  - `cylinder_primitive_t`
  - `sphere_primitive_t`
- 递归展开：
  - unit fill
  - lattice fill
  - universe fill
- 提供点查询给体素采样模块使用

### `src/vis3d_surface_patch.f90`

把 primitive 转成三角面片：

- 盒体导出为 12 个三角形
- 圆柱导出外壁、内壁、顶底盖
- 球体导出为经纬网近似三角面
- 三角片属性写入：
  - `cell_id`
  - `material_id`
  - `surface_id`
  - `universe_id`

### `src/vis3d_types.f90`

包含导出数据结构。

当前一个重要实现点是 `poly_surface_dataset_t%reserve` 已改成按容量倍增扩容，避免大 lattice 模型导出时出现明显的 O(n^2) 退化。

## 5. 当前支持范围

### 已支持

- 盒体 cell
- 同心圆柱层
- 同心球层
- `pin` 和 `particle` 模板
- unit 在 lattice 中重复展开
- universe 在 cell/lattice 中递归展开
- 平面差集与矩形外环

### 已知限制

- 不是完整 MCX CSG 内核，只覆盖当前验证样例所需的子集
- 更通用的布尔表达式还没有系统实现
- `packing` 目前不会重建真实随机排布，只做可解析几何骨架展开
- 盒体与圆柱/球体之间不会做严格布尔裁剪，面片可能存在重叠显示
- 表面导出未做点合并，文件体积偏大
- MCNP 路径仍然是骨架级实现，当前增强主要针对 MCX XML

## 6. 当前验证结果

在 `validation/run_mcx_examples.ps1` 下，本地验证已通过：

- `pool.xml`
- `2G.xml`
- `VERA_1b.xml`
- `c5g7.xml`
- `pebble.xml`

对应输出文件已生成在 `validation/mcx_examples/`。

## 7. 后续优先级建议

推荐的后续开发顺序：

1. 扩展更通用的布尔区表达式
2. 做 box/cylinder/sphere 的裁剪去重，减少重叠面片
3. 让 `VTU`、`VTI` 和 `VTP` 的字段语义进一步统一
4. 继续补更多 MCX surface 类型
5. 如果需要，再系统补 MCNP 几何接入
