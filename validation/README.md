# Validation

项目内当前分成两套 validation：

- `validation/mcx_examples/`
  MCX XML 几何回归用例
- `validation/mcnp_examples/`
  MCNP 输入卡几何回归用例

对应脚本：

- `validation/run_mcx_examples.ps1`
- `validation/run_mcnp_examples.ps1`

## MCX

当前 MCX XML 用例：

- `pool.xml`
- `2G.xml`
- `VERA_1b.xml`
- `c5g7.xml`
- `pebble.xml`

运行：

```powershell
.\validation\run_mcx_examples.ps1
```

如果当前 PowerShell 禁止直接执行脚本，可改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\validation\run_mcx_examples.ps1
```

脚本会在每个输入文件旁生成对应的 `.vtp`。

## MCNP

当前 MCNP 用例：

- `validation/mcnp_examples/angle/inp`
- `validation/mcnp_examples/point_ring_detector/inpdet`

运行：

```powershell
.\validation\run_mcnp_examples.ps1
```

如果当前 PowerShell 禁止直接执行脚本，可改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\validation\run_mcnp_examples.ps1
```

脚本会在每个输入卡旁生成对应的 `.vti`，并检查关键 `cell_id` 是否已经出现在结果里。
