# vis3d Fortran exporter

这是一个基于 Fortran 2003 的 VIS3D 导出器项目，当前重点是把 MCX XML 输入卡中的几何转换为 VTK 文件，便于在 ParaView 中检查模型。

## 文档入口

- 开发文档：[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- 使用文档：[docs/USAGE.md](docs/USAGE.md)
- 验证说明：[validation/README.md](validation/README.md)

## 当前能力

- 读取 MCX XML 输入
- 默认导出表面 `VTP`
- 支持 `VTI`、`VTP`、`VTU`
- 已覆盖一批 MCX 示例中的常见几何：
  - plane box region
  - `cylinder-z`
  - `sphere`
  - `pin`
  - `particle`
  - `rectangular lattice`
  - `universe` 递归 `fill`

## 快速构建

```powershell
cmake -S . -B build-winlibs -G "MinGW Makefiles"
cmake --build build-winlibs -j 4
```

## 快速验证

```powershell
.\validation\run_mcx_examples.ps1
```
