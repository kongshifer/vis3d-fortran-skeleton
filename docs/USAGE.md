# 使用文档

## 1. 适用范围

本程序当前主要用于把一批 MCX XML 输入卡中的几何导出为 VTK 文件，便于在 ParaView 等工具中查看。

当前已验证可直接导出的示例：

- `pool.xml`
- `2G.xml`
- `VERA_1b.xml`
- `c5g7.xml`
- `pebble.xml`

## 2. 输出格式

当前支持：

- `VTP`
  表面三角网格，当前 MCX XML 默认导出格式
- `VTU`
  非结构网格三角单元输出
- `VTI`
  体素采样输出

如果输入 XML 没有显式 `@VIS3D` 指令，程序当前默认：

- `MODE = SURFACE`
- `FORMAT = VTP`
- 输出文件名为输入文件同名 `.vtp`

## 3. 构建

### Windows 当前已验证方式

当前仓库已验证可用的构建目录是：

- `build-winlibs/`

如果需要重新编译：

```powershell
cmake -S . -B build-winlibs -G "MinGW Makefiles" `
  -DCMAKE_Fortran_COMPILER=C:/Tools/winlibs/mingw64/bin/gfortran.exe `
  -DCMAKE_MAKE_PROGRAM=C:/Tools/winlibs/mingw64/bin/mingw32-make.exe `
  -DCMAKE_RC_COMPILER=C:/Tools/winlibs/mingw64/bin/windres.exe

cmake --build build-winlibs -j 4
```

可执行文件路径：

- `build-winlibs/vis3d_export_demo.exe`

## 4. 命令行用法

```powershell
.\build-winlibs\vis3d_export_demo.exe <input_file> [auto|mcx|mcnp]
```

示例：

```powershell
.\build-winlibs\vis3d_export_demo.exe .\validation\mcx_examples\pool.xml mcx
```

执行成功后，会在输入文件同目录下生成对应的 VTK 文件。

## 5. 输入要求

### MCX XML

当前支持的主要几何元素：

- `<surface>`：
  - `x-plane / plane-x`
  - `y-plane / plane-y`
  - `z-plane / plane-z`
  - `cylinder-z`
  - `sphere`
- `<cell>`
- `<pin>`
- `<particle>`
- `<lattice type="rectangular">`

当前支持的 `zone` 表达式子集：

- 盒体区：`a1 -a2 a3 -a4 z1 -z2`
- 圆柱或球壳区：`-1 8 -9`、`surf1`、`-surf2`
- 矩形外环：`(-a1|a2|-a3|a4) o1 -o2 o3 -o4 z1 -z2`
- 盒体差集：`((x0 -x1 y0 -y1)~(x2 -x3 y2 -y3)) z0 -z1`

## 6. 回归验证

项目内已经准备好 validation 脚本：

```powershell
.\validation\run_mcx_examples.ps1
```

脚本会自动运行下面这些样例：

- `validation/mcx_examples/pool.xml`
- `validation/mcx_examples/2G.xml`
- `validation/mcx_examples/VERA_1b.xml`
- `validation/mcx_examples/c5g7.xml`
- `validation/mcx_examples/pebble.xml`

并在同目录下生成：

- `pool.vtp`
- `2G.vtp`
- `VERA_1b.vtp`
- `c5g7.vtp`
- `pebble.vtp`

## 7. 可视化查看

推荐用 ParaView 打开生成的 `.vtp/.vtu/.vti` 文件。

常见查看方式：

- 按 `material_id` 着色
- 按 `cell_id` 着色
- 对大模型使用 `Surface With Edges` 快速检查网格结构

## 8. 当前限制说明

- `pebble.xml` 中的 `packing` 目前不是随机排布重建，只是输出可解析的球层/容器几何
- 当前表面导出未做几何裁剪去重，某些组合区域可能有重叠面片
- 如果后续新增几何语法或调整命令行行为，本文件会同步更新
