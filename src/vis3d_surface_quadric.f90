
module vis3d_surface_quadric
    use vis3d_types, only: poly_surface_dataset_t
    implicit none
    private
    public :: vis3d_emit_quadric_placeholder

contains
    subroutine vis3d_emit_quadric_placeholder(dataset, ierr)
        type(poly_surface_dataset_t), intent(inout) :: dataset
        integer, intent(out) :: ierr
        ierr = 0
        ! Placeholder: general quadric support hook.
    end subroutine vis3d_emit_quadric_placeholder
end module vis3d_surface_quadric
