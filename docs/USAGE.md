# 使用文档

## 1. 适用范围

本程序用于把 MCX / MCNP 输入卡中的几何模型转换成 ParaView 可读取的 VTK 文件。

当前重点支持：

- MCX XML 几何
- MCNP 输入卡中的常见 CSG 几何子集

## 2. 输出格式

当前支持：

- `VTP`
  表面三角网格
- `VTU`
  非结构网格三角单元
- `VTI`
  规则体素采样结果

## 3. 构建

### Windows 当前验证方式

当前仓库已经验证可用的构建目录是：

- `build-winlibs/`

如需重新构建：

```powershell
cmake -S . -B build-winlibs -G "MinGW Makefiles" `
  -DCMAKE_Fortran_COMPILER=C:/Tools/winlibs/mingw64/bin/gfortran.exe `
  -DCMAKE_MAKE_PROGRAM=C:/Tools/winlibs/mingw64/bin/mingw32-make.exe `
  -DCMAKE_RC_COMPILER=C:/Tools/winlibs/mingw64/bin/windres.exe

cmake --build build-winlibs -j 4
```

可执行文件：

- `build-winlibs/vis3d_export_demo.exe`

## 4. 命令行用法

```powershell
.\build-winlibs\vis3d_export_demo.exe <input_file> [auto|mcx|mcnp]
```

示例：

```powershell
.\build-winlibs\vis3d_export_demo.exe .\validation\mcx_examples\pool.xml mcx
.\build-winlibs\vis3d_export_demo.exe .\validation\mcnp_examples\angle\inp mcnp
```

执行成功后，会在输入文件同目录下生成对应的 VTK 文件。

## 5. MCX 默认行为

如果输入是普通 MCX XML，且没有显式 `@VIS3D` 指令，默认：

- `MODE = SURFACE`
- `FORMAT = VTP`
- 输出文件为输入文件同名 `.vtp`

当前已验证的 MCX XML 示例：

- `pool.xml`
- `2G.xml`
- `VERA_1b.xml`
- `c5g7.xml`
- `pebble.xml`

## 6. MCNP 默认行为

如果输入是 MCNP 卡，且没有显式 `c @VIS3D` 指令，默认：

- `MODE = VOXEL`
- `FORMAT = VTI`
- 输出文件为输入文件同名 `.vti`

当前这样设计是因为 MCNP 的通用 CSG 布尔区更适合先通过点查询走体素导出。

### 当前支持的 MCNP surface 类型

- `PX` / `PY` / `PZ`
- `CX` / `CY` / `CZ`
- `C/X` / `C/Y` / `C/Z`
- `S`

### 当前支持的 MCNP 几何表达式子集

- 空格隐式交
- `:` 并
- `#n` 单元补
- `#(...)` 区域补
- 括号分组

### 当前已验证的 MCNP 示例

- `validation/mcnp_examples/angle/inp`
- `validation/mcnp_examples/point_ring_detector/inpdet`

## 7. `@VIS3D` 指令

MCX / MCNP 都支持通过注释携带 `@VIS3D` 配置。

MCNP 侧使用 MCNP 风格注释，例如：

```text
c @VIS3D MODE=VOXEL
c @VIS3D FORMAT=VTI
c @VIS3D DIM=128,128,128
```

如果没有这些注释，程序会回落到各自的默认策略。

## 8. Validation

### MCX

运行：

```powershell
.\validation\run_mcx_examples.ps1
```

如果当前 PowerShell 禁止直接执行脚本，可改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\validation\run_mcx_examples.ps1
```

### MCNP

运行：

```powershell
.\validation\run_mcnp_examples.ps1
```

如果当前 PowerShell 禁止直接执行脚本，可改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\validation\run_mcnp_examples.ps1
```

MCNP 回归脚本除了检查输出文件是否生成，还会解析 `VTI` 中的 `cell_id` 字段，确认示例里的关键单元确实被识别出来。

## 9. ParaView 查看建议

推荐查看方式：

- 按 `cell_id` 着色，先检查几何分区是否正确
- 按 `material_id` 着色，检查材料分布
- 对体素结果使用 `Slice` / `Clip`，快速检查内部结构
- 对表面结果使用 `Surface With Edges`，观察网格质量

## 10. 当前限制

- MCNP 当前主要保证 `VTI` 路径，不保证通用 `VTP/VTU` 表面重建
- 复杂 MCNP 高级特性还未全面接入
- 当前 `VTI` 为 ASCII XML，较大模型的输出文件会偏大
