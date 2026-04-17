
module vis3d_validate
    use vis3d_kinds, only: dp
    use vis3d_types, only: vis3d_geom_context_t, voxel_dataset_t
    use vis3d_host_types, only: geometry_point_query
    implicit none
    private
    public :: vis3d_validate_random_points

contains
    subroutine vis3d_validate_random_points(ctx, vox, nsamples, mismatch_count)
        type(vis3d_geom_context_t), intent(in) :: ctx
        type(voxel_dataset_t), intent(in) :: vox
        integer, intent(in) :: nsamples
        integer, intent(out) :: mismatch_count

        integer :: n, i, j, k
        real(dp) :: rx, ry, rz, x, y, z
        integer :: cell_id, material_id, universe_id, lattice_id, instance_id
        mismatch_count = 0

        do n = 1, nsamples
            call random_number(rx); call random_number(ry); call random_number(rz)
            x = vox%bbox%xmin + rx * (vox%bbox%xmax - vox%bbox%xmin)
            y = vox%bbox%ymin + ry * (vox%bbox%ymax - vox%bbox%ymin)
            z = vox%bbox%zmin + rz * (vox%bbox%zmax - vox%bbox%zmin)

            i = min(max(int((x - vox%bbox%xmin) / vox%grid%dx) + 1, 1), vox%grid%nx)
            j = min(max(int((y - vox%bbox%ymin) / vox%grid%dy) + 1, 1), vox%grid%ny)
            k = min(max(int((z - vox%bbox%zmin) / vox%grid%dz) + 1, 1), vox%grid%nz)

            call geometry_point_query(ctx%model, x, y, z, cell_id, material_id, universe_id, lattice_id, instance_id)
            if (cell_id /= vox%cell_id(i,j,k)) mismatch_count = mismatch_count + 1
        end do
    end subroutine vis3d_validate_random_points
end module vis3d_validate
