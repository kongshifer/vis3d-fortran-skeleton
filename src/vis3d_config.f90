
module vis3d_config
    use vis3d_types, only: vis3d_config_t
    implicit none
    private
    public :: vis3d_config_set_defaults, vis3d_config_validate

contains
    subroutine vis3d_config_set_defaults(cfg)
        type(vis3d_config_t), intent(inout) :: cfg
        call cfg%normalize()
    end subroutine vis3d_config_set_defaults

    subroutine vis3d_config_validate(cfg, ierr, message)
        type(vis3d_config_t), intent(inout) :: cfg
        integer, intent(out) :: ierr
        character(len=*), intent(out) :: message
        call cfg%normalize()
        call cfg%validate(ierr, message)
    end subroutine vis3d_config_validate
end module vis3d_config
