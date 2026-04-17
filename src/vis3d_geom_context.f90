
module vis3d_geom_context
    use vis3d_types, only: vis3d_geom_context_t
    use vis3d_host_types, only: geometry_model_t
    implicit none
    private
    public :: vis3d_build_geom_context

contains
    subroutine vis3d_build_geom_context(model, ctx, ierr)
        type(geometry_model_t), intent(in) :: model
        type(vis3d_geom_context_t), intent(out) :: ctx
        integer, intent(out) :: ierr
        ierr = 0
        ctx%model = model
        ctx%n_cells = model%n_cells
        ctx%n_surfaces = model%n_surfaces
        ctx%n_materials = model%n_materials
    end subroutine vis3d_build_geom_context
end module vis3d_geom_context
