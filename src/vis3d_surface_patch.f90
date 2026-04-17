
module vis3d_surface_patch
    use vis3d_kinds, only: dp
    use vis3d_types, only: aabb_t, vis3d_geom_context_t, vis3d_config_t, poly_surface_dataset_t
    use vis3d_surface_rcc, only: vis3d_emit_rcc_placeholder
    use vis3d_surface_trc, only: vis3d_emit_trc_placeholder
    use vis3d_surface_quadric, only: vis3d_emit_quadric_placeholder
    implicit none
    private
    public :: vis3d_build_surface

contains
    subroutine vis3d_build_surface(ctx, cfg, bbox, surf, ierr)
        type(vis3d_geom_context_t), intent(in) :: ctx
        type(vis3d_config_t), intent(in) :: cfg
        type(aabb_t), intent(in) :: bbox
        type(poly_surface_dataset_t), intent(out) :: surf
        integer, intent(out) :: ierr

        real(dp) :: xmin, xmax, ymin, ymax, zmin, zmax
        ierr = 0
        surf = poly_surface_dataset_t()

        xmin = bbox%xmin; xmax = bbox%xmax
        ymin = bbox%ymin; ymax = bbox%ymax
        zmin = bbox%zmin; zmax = bbox%zmax

        ! Minimal placeholder: emit two triangles for one face of the bbox.
        call surf%append_triangle([xmin,ymin,zmin], [xmax,ymin,zmin], [xmax,ymax,zmin], 1, 1, 1001, 0)
        call surf%append_triangle([xmin,ymin,zmin], [xmax,ymax,zmin], [xmin,ymax,zmin], 1, 1, 1001, 0)

        call vis3d_emit_rcc_placeholder(surf, ierr)
        if (ierr /= 0) return
        call vis3d_emit_trc_placeholder(surf, ierr)
        if (ierr /= 0) return
        call vis3d_emit_quadric_placeholder(surf, ierr)
    end subroutine vis3d_build_surface
end module vis3d_surface_patch
