# vis3d Fortran exporter

这是一个基于 Fortran 2003 的 VIS3D 导出器项目，目标是把 MCX / MCNP 输入卡中的 CSG 几何转换成 ParaView 可读取的 VTK 文件。

当前已经打通两条主路径：

- MCX XML 几何导出
  - 默认输出表面网格 `VTP`
  - 支持 `VTP` / `VTU` / `VTI`
- MCNP 输入卡几何导出
  - 当前默认输出体素 `VTI`
  - 已覆盖 `PX/PY/PZ`、`CX/CY/CZ`、`C/X C/Y C/Z`、`S` 和常见布尔区表达式子集

## 文档入口

- 开发文档：[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- 使用文档：[docs/USAGE.md](docs/USAGE.md)
- Validation 说明：[validation/README.md](validation/README.md)

## 快速构建

```powershell
cmake -S . -B build-winlibs -G "MinGW Makefiles"
cmake --build build-winlibs -j 4
```

## 快速验证

```powershell
.\validation\run_mcx_examples.ps1
.\validation\run_mcnp_examples.ps1
```
