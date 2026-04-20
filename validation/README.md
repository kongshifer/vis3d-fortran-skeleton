# MCX Validation

这个目录收纳了当前用于 VIS3D XML 导出的 MCX 回归用例。

当前用例：
- `pool.xml`
- `2G.xml`
- `VERA_1b.xml`
- `c5g7.xml`
- `pebble.xml`

运行方式：

```powershell
.\validation\run_mcx_examples.ps1
```

脚本会调用 `build-winlibs\vis3d_export_demo.exe`，并在每个输入卡旁边生成对应的 `.vtp` 输出文件。

当前这批用例覆盖的几何特征包括：
- 轴对齐平面围成的盒体 cell
- 显式 `cylinder-z` 表面与圆柱环区
- `sphere` 表面与球壳
- `pin` / `particle` 模板
- 2D/3D `rectangular lattice`
- cell `universe` 定义与递归 `fill`
- 基于平面的简单布尔区表达式：外环与盒体差集
