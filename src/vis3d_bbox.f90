
module vis3d_bbox
    use vis3d_types, only: aabb_t, vis3d_config_t, vis3d_geom_context_t
    implicit none
    private
    public :: vis3d_resolve_bbox

contains
    subroutine vis3d_resolve_bbox(ctx, cfg, bbox, ierr)
        type(vis3d_geom_context_t), intent(in) :: ctx
        type(vis3d_config_t), intent(in) :: cfg
        type(aabb_t), intent(out) :: bbox
        integer, intent(out) :: ierr
        ierr = 0
        if (cfg%auto_bbox) then
            bbox%xmin = ctx%model%bbox(1)
            bbox%xmax = ctx%model%bbox(2)
            bbox%ymin = ctx%model%bbox(3)
            bbox%ymax = ctx%model%bbox(4)
            bbox%zmin = ctx%model%bbox(5)
            bbox%zmax = ctx%model%bbox(6)
            call bbox%expand(cfg%bbox_margin)
        else
            bbox = cfg%bbox
        end if
        if (.not. bbox%is_valid()) ierr = 1
    end subroutine vis3d_resolve_bbox
end module vis3d_bbox
