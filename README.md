# vis3d Fortran 2003 skeleton

This is a multi-file Fortran 2003 skeleton for the MCX/MCNP VIS3D exporter described in the design notes.

## Included modules

- `vis3d_kinds`
- `vis3d_constants`
- `vis3d_host_types`
- `vis3d_types`
- `vis3d_config`
- `vis3d_input_common`
- `vis3d_input_mcx`
- `vis3d_input_mcnp`
- `vis3d_geom_context`
- `vis3d_bbox`
- `vis3d_sampler_voxel`
- `vis3d_surface_patch`
- `vis3d_surface_rcc`
- `vis3d_surface_trc`
- `vis3d_surface_quadric`
- `vis3d_writer_xml`
- `vis3d_writer_vti`
- `vis3d_writer_vtp`
- `vis3d_writer_vtu`
- `vis3d_validate`
- `vis3d_driver`

## Notes

- This is a **skeleton**, not a full integration with MCX.
- The `vis3d_host_types` module contains placeholder host geometry types and query hooks.
- The `.vti` writer is usable for quick inspection in ParaView.
- The surface route is intentionally minimal and currently exports a simple bounding-box shell placeholder.

## Build

```bash
cmake -S . -B build
cmake --build build
```

## Demo

```bash
./build/vis3d_export_demo input.i auto
```

The demo driver:
- reads `@VIS3D` directives from MCX-style or MCNP-style comment lines,
- builds a placeholder geometry context,
- exports either `.vti` or `.vtp`.

