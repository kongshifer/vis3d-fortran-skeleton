# MCNP validation

这个目录存放 MCNP 输入卡回归用例及其导出结果。

当前用例来源：

- `angle/inp`
  对应原始示例 `examples(edu)\sdef\angle\inp`
- `point_ring_detector/inpdet`
  对应原始示例 `examples(edu)\点环探测器\inpdet`

运行方式：

```powershell
.\validation\run_mcnp_examples.ps1
```

如果当前 PowerShell 禁止直接执行脚本，可改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\validation\run_mcnp_examples.ps1
```

脚本会重新导出 `.vti` 并校验关键 `cell_id`。
