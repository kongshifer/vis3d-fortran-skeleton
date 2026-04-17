
module vis3d_host_types
    use vis3d_kinds, only: dp
    implicit none
    private
    public :: geometry_model_t
    public :: geometry_build_from_input
    public :: geometry_point_query

    type :: geometry_model_t
        integer :: n_cells = 0
        integer :: n_surfaces = 0
        integer :: n_materials = 0
        real(dp) :: bbox(6) = [0.0_dp, 10.0_dp, 0.0_dp, 10.0_dp, 0.0_dp, 10.0_dp]
    end type geometry_model_t
contains
    subroutine geometry_build_from_input(input_file, syntax_kind, model, ierr)
        character(len=*), intent(in) :: input_file
        integer, intent(in)          :: syntax_kind
        type(geometry_model_t), intent(out) :: model
        integer, intent(out) :: ierr
        ierr = 0
        model%n_cells = 2
        model%n_surfaces = 6
        model%n_materials = 2
        model%bbox = [0.0_dp, 10.0_dp, 0.0_dp, 10.0_dp, 0.0_dp, 10.0_dp]
    end subroutine geometry_build_from_input

    subroutine geometry_point_query(model, x, y, z, cell_id, material_id, universe_id, lattice_id, instance_id)
        type(geometry_model_t), intent(in) :: model
        real(dp), intent(in) :: x, y, z
        integer, intent(out) :: cell_id, material_id, universe_id, lattice_id, instance_id
        real(dp) :: xmid
        xmid = 0.5_dp * (model%bbox(1) + model%bbox(2))
        universe_id = 0
        lattice_id = -1
        instance_id = 0
        if (x < model%bbox(1) .or. x > model%bbox(2) .or. &
            y < model%bbox(3) .or. y > model%bbox(4) .or. &
            z < model%bbox(5) .or. z > model%bbox(6)) then
            cell_id = -1
            material_id = -1
        else if (x <= xmid) then
            cell_id = 1
            material_id = 1
        else
            cell_id = 2
            material_id = 2
        end if
    end subroutine geometry_point_query
end module vis3d_host_types
