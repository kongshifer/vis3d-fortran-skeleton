cmake_minimum_required(VERSION 3.16)
project(vis3d_fortran_skeleton LANGUAGES Fortran)

set(CMAKE_Fortran_STANDARD 2003)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)

set(VIS3D_SOURCES
    src/vis3d_kinds.f90
    src/vis3d_constants.f90
    src/vis3d_host_types.f90
    src/vis3d_types.f90
    src/vis3d_config.f90
    src/vis3d_input_common.f90
    src/vis3d_input_mcx.f90
    src/vis3d_input_mcnp.f90
    src/vis3d_geom_context.f90
    src/vis3d_bbox.f90
    src/vis3d_sampler_voxel.f90
    src/vis3d_surface_rcc.f90
    src/vis3d_surface_trc.f90
    src/vis3d_surface_quadric.f90
    src/vis3d_surface_patch.f90
    src/vis3d_writer_xml.f90
    src/vis3d_writer_vti.f90
    src/vis3d_writer_vtp.f90
    src/vis3d_writer_vtu.f90
    src/vis3d_validate.f90
    src/vis3d_driver.f90
    src/vis3d_export_demo.f90
)

add_executable(vis3d_export_demo ${VIS3D_SOURCES})
