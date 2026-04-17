
module vis3d_sampler_voxel
    use vis3d_kinds, only: dp
    use vis3d_types, only: aabb_t, vis3d_geom_context_t, vis3d_config_t, voxel_dataset_t
    use vis3d_host_types, only: geometry_point_query
    implicit none
    private
    public :: vis3d_sample_voxel

contains
    subroutine vis3d_sample_voxel(ctx, cfg, bbox, vox, ierr)
        type(vis3d_geom_context_t), intent(in) :: ctx
        type(vis3d_config_t), intent(in) :: cfg
        type(aabb_t), intent(in) :: bbox
        type(voxel_dataset_t), intent(out) :: vox
        integer, intent(out) :: ierr

        integer :: i, j, k
        real(dp) :: x, y, z
        real(dp) :: dx, dy, dz
        ierr = 0

        vox%bbox = bbox
        vox%grid = cfg%grid
        dx = (vox%bbox%xmax - vox%bbox%xmin) / real(vox%grid%nx, dp)
        dy = (vox%bbox%ymax - vox%bbox%ymin) / real(vox%grid%ny, dp)
        dz = (vox%bbox%zmax - vox%bbox%zmin) / real(vox%grid%nz, dp)
        vox%grid%dx = dx
        vox%grid%dy = dy
        vox%grid%dz = dz
        call vox%allocate_fields()

        do k = 1, vox%grid%nz
            z = vox%bbox%zmin + (real(k,dp) - 0.5_dp) * dz
            do j = 1, vox%grid%ny
                y = vox%bbox%ymin + (real(j,dp) - 0.5_dp) * dy
                do i = 1, vox%grid%nx
                    x = vox%bbox%xmin + (real(i,dp) - 0.5_dp) * dx
                    call geometry_point_query(ctx%model, x, y, z, &
                        vox%cell_id(i,j,k), vox%material_id(i,j,k), &
                        vox%universe_id(i,j,k), vox%lattice_id(i,j,k), vox%instance_id(i,j,k))
                end do
            end do
        end do
    end subroutine vis3d_sample_voxel
end module vis3d_sampler_voxel
