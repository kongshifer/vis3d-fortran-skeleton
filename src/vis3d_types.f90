
module vis3d_types
    use vis3d_kinds, only: dp
    use vis3d_constants, only: VIS3D_MODE_VOXEL, VIS3D_FMT_VTI
    use vis3d_host_types, only: geometry_model_t
    implicit none
    private
    public :: aabb_t, grid_spec_t, field_flags_t, vis3d_config_t
    public :: voxel_dataset_t, poly_surface_dataset_t
    public :: vis3d_diag_t, geom_ref_t, vis3d_geom_context_t

    type :: aabb_t
        real(dp) :: xmin = 0.0_dp, xmax = 0.0_dp
        real(dp) :: ymin = 0.0_dp, ymax = 0.0_dp
        real(dp) :: zmin = 0.0_dp, zmax = 0.0_dp
    contains
        procedure :: expand
        procedure :: is_valid
    end type aabb_t

    type :: grid_spec_t
        integer :: nx = 128, ny = 128, nz = 128
        real(dp) :: dx = 0.0_dp, dy = 0.0_dp, dz = 0.0_dp
    end type grid_spec_t

    type :: field_flags_t
        logical :: cell_id     = .true.
        logical :: material_id = .true.
        logical :: universe_id = .true.
        logical :: lattice_id  = .false.
        logical :: instance_id = .false.
        logical :: surface_id  = .false.
        logical :: density     = .false.
        logical :: temperature = .false.
        logical :: importance  = .false.
    end type field_flags_t

    type :: vis3d_config_t
        logical :: enabled = .false.
        integer :: mode = VIS3D_MODE_VOXEL
        integer :: format = VIS3D_FMT_VTI
        character(len=256) :: output = 'model.vti'
        integer :: syntax = 0
        character(len=32) :: color_by = 'material_id'
        type(aabb_t) :: bbox
        type(grid_spec_t) :: grid
        type(field_flags_t) :: fields
        logical :: auto_bbox = .true.
        real(dp) :: bbox_margin = 0.0_dp
        integer :: surface_quality = 1
    contains
        procedure :: normalize
        procedure :: validate
    end type vis3d_config_t

    type :: voxel_dataset_t
        type(aabb_t) :: bbox
        type(grid_spec_t) :: grid
        integer, allocatable :: cell_id(:,:,:)
        integer, allocatable :: material_id(:,:,:)
        integer, allocatable :: universe_id(:,:,:)
        integer, allocatable :: lattice_id(:,:,:)
        integer, allocatable :: instance_id(:,:,:)
    contains
        procedure :: allocate_fields
    end type voxel_dataset_t

    type :: poly_surface_dataset_t
        integer :: n_points = 0
        integer :: n_tris = 0
        real(dp), allocatable :: points(:,:)   ! (3, capacity_points)
        integer, allocatable  :: conn(:,:)     ! (3, capacity_tris)
        integer, allocatable  :: cell_id(:)
        integer, allocatable  :: material_id(:)
        integer, allocatable  :: surface_id(:)
        integer, allocatable  :: universe_id(:)
    contains
        procedure :: reserve
        procedure :: append_triangle
    end type poly_surface_dataset_t

    type :: vis3d_diag_t
        integer :: ierr = 0
        character(len=512) :: message = ''
    end type vis3d_diag_t

    type :: geom_ref_t
        integer :: cell_id = -1
        integer :: surface_id = -1
        integer :: material_id = -1
        integer :: universe_id = -1
        integer :: lattice_id = -1
        integer :: instance_id = -1
    end type geom_ref_t

    type :: vis3d_geom_context_t
        type(geometry_model_t) :: model
        integer :: n_cells = 0
        integer :: n_surfaces = 0
        integer :: n_materials = 0
    end type vis3d_geom_context_t
contains
    subroutine expand(self, margin)
        class(aabb_t), intent(inout) :: self
        real(dp), intent(in) :: margin
        self%xmin = self%xmin - margin
        self%xmax = self%xmax + margin
        self%ymin = self%ymin - margin
        self%ymax = self%ymax + margin
        self%zmin = self%zmin - margin
        self%zmax = self%zmax + margin
    end subroutine expand

    logical function is_valid(self)
        class(aabb_t), intent(in) :: self
        is_valid = (self%xmax > self%xmin) .and. (self%ymax > self%ymin) .and. (self%zmax > self%zmin)
    end function is_valid

    subroutine normalize(self)
        class(vis3d_config_t), intent(inout) :: self
        if (self%grid%nx <= 0) self%grid%nx = 128
        if (self%grid%ny <= 0) self%grid%ny = 128
        if (self%grid%nz <= 0) self%grid%nz = 128
        if (len_trim(self%output) == 0) self%output = 'model.vti'
        if (len_trim(self%color_by) == 0) self%color_by = 'material_id'
    end subroutine normalize

    subroutine validate(self, ierr, message)
        class(vis3d_config_t), intent(in) :: self
        integer, intent(out) :: ierr
        character(len=*), intent(out) :: message
        ierr = 0
        message = ''
        if (.not. self%auto_bbox) then
            if (.not. self%bbox%is_valid()) then
                ierr = 1
                message = 'Invalid explicit bbox in vis3d_config_t'
            end if
        end if
    end subroutine validate

    subroutine allocate_fields(self)
        class(voxel_dataset_t), intent(inout) :: self
        integer :: nx, ny, nz
        nx = self%grid%nx
        ny = self%grid%ny
        nz = self%grid%nz
        if (.not. allocated(self%cell_id))     allocate(self%cell_id(nx, ny, nz))
        if (.not. allocated(self%material_id)) allocate(self%material_id(nx, ny, nz))
        if (.not. allocated(self%universe_id)) allocate(self%universe_id(nx, ny, nz))
        if (.not. allocated(self%lattice_id))  allocate(self%lattice_id(nx, ny, nz))
        if (.not. allocated(self%instance_id)) allocate(self%instance_id(nx, ny, nz))
        self%cell_id = -1
        self%material_id = -1
        self%universe_id = -1
        self%lattice_id = -1
        self%instance_id = -1
    end subroutine allocate_fields

    subroutine reserve(self, npts, ntris)
        class(poly_surface_dataset_t), intent(inout) :: self
        integer, intent(in) :: npts, ntris
        real(dp), allocatable :: ptmp(:,:)
        integer, allocatable :: ctmp(:,:), itmp(:)

        if (.not. allocated(self%points)) then
            allocate(self%points(3, max(1, npts)))
            self%points = 0.0_dp
        else if (size(self%points,2) < npts) then
            allocate(ptmp(3, npts)); ptmp = 0.0_dp
            ptmp(:,1:self%n_points) = self%points(:,1:self%n_points)
            call move_alloc(ptmp, self%points)
        end if

        if (.not. allocated(self%conn)) then
            allocate(self%conn(3, max(1, ntris)))
            allocate(self%cell_id(max(1, ntris)))
            allocate(self%material_id(max(1, ntris)))
            allocate(self%surface_id(max(1, ntris)))
            allocate(self%universe_id(max(1, ntris)))
            self%conn = 0; self%cell_id = -1; self%material_id = -1; self%surface_id = -1; self%universe_id = -1
        else if (size(self%conn,2) < ntris) then
            allocate(ctmp(3, ntris)); ctmp = 0
            ctmp(:,1:self%n_tris) = self%conn(:,1:self%n_tris)
            call move_alloc(ctmp, self%conn)
            allocate(itmp(ntris)); itmp = -1; itmp(1:self%n_tris) = self%cell_id(1:self%n_tris); call move_alloc(itmp, self%cell_id)
            allocate(itmp(ntris)); itmp = -1; itmp(1:self%n_tris) = self%material_id(1:self%n_tris); call move_alloc(itmp, self%material_id)
            allocate(itmp(ntris)); itmp = -1; itmp(1:self%n_tris) = self%surface_id(1:self%n_tris); call move_alloc(itmp, self%surface_id)
            allocate(itmp(ntris)); itmp = -1; itmp(1:self%n_tris) = self%universe_id(1:self%n_tris); call move_alloc(itmp, self%universe_id)
        end if
    end subroutine reserve

    subroutine append_triangle(self, p1, p2, p3, cell_id, material_id, surface_id, universe_id)
        class(poly_surface_dataset_t), intent(inout) :: self
        real(dp), intent(in) :: p1(3), p2(3), p3(3)
        integer, intent(in) :: cell_id, material_id, surface_id, universe_id
        integer :: i1, i2, i3
        call self%reserve(self%n_points + 3, self%n_tris + 1)
        i1 = self%n_points + 1
        i2 = self%n_points + 2
        i3 = self%n_points + 3
        self%points(:,i1) = p1
        self%points(:,i2) = p2
        self%points(:,i3) = p3
        self%n_points = self%n_points + 3
        self%n_tris = self%n_tris + 1
        self%conn(:,self%n_tris) = [i1-1, i2-1, i3-1]  ! zero-based for VTK connectivity
        self%cell_id(self%n_tris) = cell_id
        self%material_id(self%n_tris) = material_id
        self%surface_id(self%n_tris) = surface_id
        self%universe_id(self%n_tris) = universe_id
    end subroutine append_triangle
end module vis3d_types
