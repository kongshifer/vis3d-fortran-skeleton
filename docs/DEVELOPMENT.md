# 开发文档

## 1. 文档维护约定

- `docs/DEVELOPMENT.md` 记录当前实现状态、模块职责、支持范围、已知限制和后续开发建议。
- `docs/USAGE.md` 记录构建方法、命令行用法、支持的输入语法和 validation 方式。
- 只要发生下面任一变化，就同步更新这两份文档：
  - 新增或修改几何语法支持
  - 调整默认导出模式、格式或命令行行为
  - 增删 validation 用例
  - 修改构建方式或运行依赖

## 2. 当前项目状态

当前项目已经从最初的 skeleton 演进到“可针对实际 MCX / MCNP 示例直接导出 VTK”的阶段。

当前主线能力：

- MCX XML
  - 支持默认表面导出
  - 支持 `VTP` / `VTU` / `VTI`
  - 已覆盖项目内 5 个 XML validation 示例
- MCNP 输入卡
  - 无 `@VIS3D` 指令时默认启用导出
  - 默认走体素采样并输出 `VTI`
  - 已覆盖项目内 2 个 MCNP validation 示例

## 3. 目录说明

- `src/`
  主源码目录
- `docs/`
  项目文档目录
- `validation/mcx_examples/`
  MCX XML 回归输入与输出
- `validation/mcnp_examples/`
  MCNP 回归输入与输出
- `validation/run_mcx_examples.ps1`
  MCX XML 回归脚本
- `validation/run_mcnp_examples.ps1`
  MCNP 回归脚本
- `build-winlibs/`
  当前验证通过的 Windows 构建目录

## 4. 关键模块

### `src/vis3d_driver.f90`

主调度入口，负责：

- 判断输入语法
- 读取 VIS3D 配置
- 构建宿主几何模型
- 解析 bbox
- 选择 voxel 或 surface 导出路径

### `src/vis3d_input_mcx.f90`

MCX 输入配置解析。

当前行为：

- 如果存在 `@VIS3D` 注释，按指令读取配置
- 如果是普通 XML 且没有 `@VIS3D`，默认：
  - 启用导出
  - `MODE = SURFACE`
  - `FORMAT = VTP`
  - 输出文件名为输入文件同名 `.vtp`

### `src/vis3d_input_mcnp.f90`

MCNP 输入配置解析。

当前行为：

- 识别 `c @VIS3D ...` 注释
- 如果没有显式 `@VIS3D` 指令，默认：
  - 启用导出
  - `MODE = VOXEL`
  - `FORMAT = VTI`
  - 输出文件名为输入文件同名 `.vti`

这样做的原因是：MCNP 的通用 CSG 布尔区更适合先走点查询和体素路径，表面重建暂时不作为默认能力。

### `src/vis3d_host_types.f90`

当前几何核心。

MCX 侧职责：

- 解析 XML 中的 `surface / pin / particle / lattice / cell`
- 建立内部 primitive 模型
- 递归展开 `fill / universe / lattice`
- 提供点查询给体素采样模块使用

MCNP 侧职责：

- 读取 cell / surface 两个主卡段
- 解析 surface card 到内部表面表示
- 解析 cell card 几何表达式
- 把布尔区表达式编译成后缀表达式并做点内判定
- 估算有限 bbox，供体素采样使用

当前已接入的 MCNP surface 类型：

- `PX` / `PY` / `PZ`
- `CX` / `CY` / `CZ`
- `C/X` / `C/Y` / `C/Z`
- `S`

当前已接入的 MCNP 布尔区表达式子集：

- 空格隐式交
- `:` 并
- `#n` 单元补
- `#(...)` 区域补
- 括号分组

### `src/vis3d_surface_patch.f90`

把 MCX primitive 转成三角面片：

- 盒体导出为 12 个三角形
- 圆柱导出外壁、内壁和端盖
- 球体导出为经纬网近似三角面

当前这条 surface 路径主要服务 MCX XML。MCNP 通用几何暂未做表面重建。

### `src/vis3d_sampler_voxel.f90`

体素采样入口。对解析后的 bbox 和规则网格中心点做 `geometry_point_query`，生成 `VTI` 所需的字段数组。

### `src/vis3d_writer_vti.f90`

写出 `ImageData` 格式的 VTK XML。

当前会按配置选择性输出字段，例如：

- `cell_id`
- `material_id`
- `density`
- `temperature`
- `importance`

## 5. 当前支持范围

### MCX XML 已支持

- 轴对齐平面围成的 box cell
- 显式 `cylinder-z`
- `sphere`
- `pin`
- `particle`
- 2D / 3D `rectangular lattice`
- cell `universe` 与递归 `fill`
- 一部分平面布尔区表达式与差集环区

### MCNP 已支持

- `PX/PY/PZ`
- `CX/CY/CZ`
- `C/X C/Y C/Z`
- `S`
- 基于上述表面的常见 CSG 布尔区点查询
- 默认 `VTI` 导出路径

## 6. Validation 状态

### MCX XML

当前项目内 validation 用例：

- `validation/mcx_examples/pool.xml`
- `validation/mcx_examples/2G.xml`
- `validation/mcx_examples/VERA_1b.xml`
- `validation/mcx_examples/c5g7.xml`
- `validation/mcx_examples/pebble.xml`

### MCNP

当前项目内 validation 用例：

- `validation/mcnp_examples/angle/inp`
- `validation/mcnp_examples/point_ring_detector/inpdet`

当前已验证的结果：

- `angle/inp` 可以导出 `inp.vti`，并识别到 `cell_id = 1, 2, 11, 12`
- `point_ring_detector/inpdet` 可以导出 `inpdet.vti`，并识别到 `cell_id = 1, 2, 3, 4, 7`

## 7. 已知限制

- MCNP 当前默认只保证 voxel 路径，不保证通用 surface 重建
- MCNP 只覆盖当前 validation 所需的 surface 类型和布尔区子集，还不是完整 MCNP CSG 内核
- 未系统支持 TR / TRCL、宏体、二次曲面全家桶、重复结构卡等更宽语法
- bbox 当前主要基于有限 surface 估算；若模型完全开域，仍需要用户显式限制导出范围
- `VTI` 当前是 ASCII XML，示例规模继续增大后文件会比较大

## 8. 这次 MCNP 扩展的关键修正

本轮开发里有一个实际踩到的 bug：MCNP cell 几何表达式在拼接 token 时丢失了空格，导致像 `-21 9` 被错误拼成 `-219`。这一点已经在 `src/vis3d_host_types.f90` 修复，否则会直接造成半空间和布尔区判断错误。

## 9. 后续优先级建议

推荐后续开发顺序：

1. 扩展更通用的 MCNP surface 类型和布尔区语法
2. 为 MCNP 增加可控的 bbox / DIM 默认策略，避免大开域模型直接输出超大体素
3. 评估是否为 MCNP 引入 surface 重建路径
4. 继续补更多实际输入卡做 validation
5. 视需要把 `VTI` 输出改成压缩或 binary 形式，减小文件体积
