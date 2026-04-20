module vis3d_host_types
    use vis3d_kinds, only: dp
    use vis3d_constants, only: VIS3D_SYNTAX_MCX, lowercase
    implicit none
    private
    public :: geometry_model_t
    public :: geometry_build_from_input
    public :: geometry_point_query
    public :: box_primitive_t
    public :: cylinder_primitive_t
    public :: sphere_primitive_t

    integer, parameter :: NAME_LEN = 64
    integer, parameter :: LINE_LEN = 4096
    integer, parameter :: UNIT_KIND_CYLINDER = 1
    integer, parameter :: UNIT_KIND_SPHERE = 2
    real(dp), parameter :: REGION_BIG = huge(1.0_dp) / 16.0_dp

    type :: box_primitive_t
        real(dp) :: xmin = 0.0_dp, xmax = 0.0_dp
        real(dp) :: ymin = 0.0_dp, ymax = 0.0_dp
        real(dp) :: zmin = 0.0_dp, zmax = 0.0_dp
        integer :: cell_id = -1
        integer :: material_id = -1
        integer :: universe_id = 0
        integer :: lattice_id = -1
        integer :: instance_id = 0
        integer :: surface_id = 0
    end type box_primitive_t

    type :: cylinder_primitive_t
        real(dp) :: xc = 0.0_dp, yc = 0.0_dp
        real(dp) :: zmin = 0.0_dp, zmax = 0.0_dp
        real(dp) :: rmin = 0.0_dp, rmax = 0.0_dp
        integer :: cell_id = -1
        integer :: material_id = -1
        integer :: universe_id = 0
        integer :: lattice_id = -1
        integer :: instance_id = 0
        integer :: surface_id = 0
    end type cylinder_primitive_t

    type :: sphere_primitive_t
        real(dp) :: xc = 0.0_dp, yc = 0.0_dp, zc = 0.0_dp
        real(dp) :: rmin = 0.0_dp, rmax = 0.0_dp
        integer :: cell_id = -1
        integer :: material_id = -1
        integer :: universe_id = 0
        integer :: lattice_id = -1
        integer :: instance_id = 0
        integer :: surface_id = 0
    end type sphere_primitive_t

    type :: plane_spec_t
        character(len=NAME_LEN) :: id = ''
        integer :: axis = 0
        real(dp) :: value = 0.0_dp
    end type plane_spec_t

    type :: cylinder_surface_t
        character(len=NAME_LEN) :: id = ''
        real(dp) :: xc = 0.0_dp, yc = 0.0_dp, radius = 0.0_dp
    end type cylinder_surface_t

    type :: sphere_surface_t
        character(len=NAME_LEN) :: id = ''
        real(dp) :: xc = 0.0_dp, yc = 0.0_dp, zc = 0.0_dp, radius = 0.0_dp
    end type sphere_surface_t

    type :: unit_def_t
        character(len=NAME_LEN) :: id = ''
        integer :: kind = 0
        integer, allocatable :: material_ids(:)
        real(dp), allocatable :: radii(:)
    end type unit_def_t

    type :: lattice_spec_t
        character(len=NAME_LEN) :: id = ''
        integer :: nx = 1, ny = 1, nz = 1
        real(dp) :: pitch(3) = [1.0_dp, 1.0_dp, 1.0_dp]
        real(dp) :: lower_left(3) = [0.0_dp, 0.0_dp, 0.0_dp]
        integer :: background_material_id = 0
        character(len=NAME_LEN), allocatable :: token_names(:,:,:)
    end type lattice_spec_t

    type :: cell_spec_t
        character(len=NAME_LEN) :: id = ''
        integer :: cell_id = -1
        integer :: material_id = -1
        character(len=NAME_LEN) :: fill_name = ''
        character(len=LINE_LEN) :: zone = ''
        character(len=NAME_LEN) :: universe_name = ''
        integer :: universe_id = 0
    end type cell_spec_t

    type :: region_spec_t
        logical :: xmin_set = .false., xmax_set = .false.
        logical :: ymin_set = .false., ymax_set = .false.
        logical :: zmin_set = .false., zmax_set = .false.
        real(dp) :: xmin = -REGION_BIG, xmax = REGION_BIG
        real(dp) :: ymin = -REGION_BIG, ymax = REGION_BIG
        real(dp) :: zmin = -REGION_BIG, zmax = REGION_BIG
        logical :: has_cylinder = .false.
        real(dp) :: cyl_xc = 0.0_dp, cyl_yc = 0.0_dp
        real(dp) :: cyl_rmin = 0.0_dp, cyl_rmax = REGION_BIG
        logical :: has_sphere = .false.
        real(dp) :: sph_xc = 0.0_dp, sph_yc = 0.0_dp, sph_zc = 0.0_dp
        real(dp) :: sph_rmin = 0.0_dp, sph_rmax = REGION_BIG
    end type region_spec_t

    type :: geometry_model_t
        integer :: n_cells = 0
        integer :: n_surfaces = 0
        integer :: n_materials = 0
        real(dp) :: bbox(6) = [0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp]
        type(box_primitive_t), allocatable :: boxes(:)
        type(cylinder_primitive_t), allocatable :: cylinders(:)
        type(sphere_primitive_t), allocatable :: spheres(:)
    end type geometry_model_t

contains
    subroutine geometry_build_from_input(input_file, syntax_kind, model, ierr)
        character(len=*), intent(in) :: input_file
        integer, intent(in) :: syntax_kind
        type(geometry_model_t), intent(out) :: model
        integer, intent(out) :: ierr

        call reset_model(model)
        ierr = 0

        if (syntax_kind == VIS3D_SYNTAX_MCX .or. is_xml_file(input_file)) then
            call geometry_build_from_mcx_xml(input_file, model, ierr)
            return
        end if

        ierr = 1
    end subroutine geometry_build_from_input

    subroutine geometry_point_query(model, x, y, z, cell_id, material_id, universe_id, lattice_id, instance_id)
        type(geometry_model_t), intent(in) :: model
        real(dp), intent(in) :: x, y, z
        integer, intent(out) :: cell_id, material_id, universe_id, lattice_id, instance_id
        integer :: i
        real(dp) :: r2, d2

        cell_id = -1
        material_id = -1
        universe_id = 0
        lattice_id = -1
        instance_id = 0

        do i = 1, size(model%boxes)
            if (point_in_box(model%boxes(i), x, y, z)) then
                cell_id = model%boxes(i)%cell_id
                material_id = model%boxes(i)%material_id
                universe_id = model%boxes(i)%universe_id
                lattice_id = model%boxes(i)%lattice_id
                instance_id = model%boxes(i)%instance_id
            end if
        end do

        do i = 1, size(model%cylinders)
            if (z < model%cylinders(i)%zmin .or. z > model%cylinders(i)%zmax) cycle
            r2 = (x - model%cylinders(i)%xc)**2 + (y - model%cylinders(i)%yc)**2
            if (r2 >= model%cylinders(i)%rmin**2 .and. r2 <= model%cylinders(i)%rmax**2) then
                cell_id = model%cylinders(i)%cell_id
                material_id = model%cylinders(i)%material_id
                universe_id = model%cylinders(i)%universe_id
                lattice_id = model%cylinders(i)%lattice_id
                instance_id = model%cylinders(i)%instance_id
            end if
        end do

        do i = 1, size(model%spheres)
            d2 = (x - model%spheres(i)%xc)**2 + (y - model%spheres(i)%yc)**2 + (z - model%spheres(i)%zc)**2
            if (d2 >= model%spheres(i)%rmin**2 .and. d2 <= model%spheres(i)%rmax**2) then
                cell_id = model%spheres(i)%cell_id
                material_id = model%spheres(i)%material_id
                universe_id = model%spheres(i)%universe_id
                lattice_id = model%spheres(i)%lattice_id
                instance_id = model%spheres(i)%instance_id
            end if
        end do
    end subroutine geometry_point_query

    subroutine geometry_build_from_mcx_xml(filename, model, ierr)
        character(len=*), intent(in) :: filename
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        character(len=LINE_LEN), allocatable :: lines(:)
        type(plane_spec_t), allocatable :: planes(:)
        type(cylinder_surface_t), allocatable :: cylinder_surfaces(:)
        type(sphere_surface_t), allocatable :: sphere_surfaces(:)
        type(unit_def_t), allocatable :: units(:)
        type(lattice_spec_t), allocatable :: lattices(:)
        type(cell_spec_t), allocatable :: cells(:)
        character(len=NAME_LEN), allocatable :: material_names(:)
        character(len=NAME_LEN), allocatable :: cell_names(:)
        integer, allocatable :: cell_ids(:)
        character(len=NAME_LEN), allocatable :: universe_names(:)
        integer, allocatable :: universe_ids(:)

        integer :: i, next_cell_id, next_universe_id
        character(len=LINE_LEN) :: line
        type(cell_spec_t) :: cell
        type(region_spec_t) :: empty_parent

        ierr = 0
        next_cell_id = 1
        next_universe_id = 1
        empty_parent = empty_region()
        allocate(lines(0), planes(0), cylinder_surfaces(0), sphere_surfaces(0), units(0), lattices(0), cells(0))
        allocate(material_names(0), cell_names(0), cell_ids(0), universe_names(0), universe_ids(0))

        call read_all_lines(filename, lines, ierr)
        if (ierr /= 0) return

        do i = 1, size(lines)
            line = trim(adjustl(lines(i)))
            if (starts_with(line, '<material')) then
                call collect_material_id(line, material_names)
            end if
        end do

        i = 1
        do while (i <= size(lines))
            line = trim(adjustl(lines(i)))

            if (len_trim(line) == 0 .or. starts_with(line, '<!--')) then
                i = i + 1
                cycle
            end if

            if (starts_with(line, '<surface')) then
                call parse_surface_line(line, planes, cylinder_surfaces, sphere_surfaces)
                i = i + 1
                cycle
            end if

            if (starts_with(line, '<pin')) then
                call parse_unit_block(lines, i, UNIT_KIND_CYLINDER, units, material_names)
                cycle
            end if

            if (starts_with(line, '<particle')) then
                call parse_unit_block(lines, i, UNIT_KIND_SPHERE, units, material_names)
                cycle
            end if

            if (starts_with(line, '<lattice')) then
                call parse_lattice_block(lines, i, lattices, ierr)
                if (ierr /= 0) then
                    write(*,'(A)') 'VIS3D geometry error: failed to parse lattice block.'
                    return
                end if
                cycle
            end if

            if (starts_with(line, '<cell')) then
                call collect_open_tag(lines, i, line)
                call parse_cell_line(line, material_names, cell_names, cell_ids, next_cell_id, &
                    universe_names, universe_ids, next_universe_id, cell, ierr)
                if (ierr /= 0) then
                    write(*,'(A)') 'VIS3D geometry error: failed to parse cell definition.'
                    return
                end if
                call append_cell(cells, cell)
            end if

            i = i + 1
        end do

        do i = 1, size(lattices)
            lattices(i)%background_material_id = common_background_material(lattices(i), units)
        end do

        do i = 1, size(cells)
            if (len_trim(cells(i)%universe_name) == 0) then
                call expand_cell(cells(i), cells, planes, cylinder_surfaces, sphere_surfaces, units, lattices, &
                    [0.0_dp, 0.0_dp, 0.0_dp], empty_parent, 0, -1, 0, model, ierr, 1)
                if (ierr /= 0) return
            end if
        end do

        if (size(model%boxes) == 0 .and. size(model%cylinders) == 0 .and. size(model%spheres) == 0) then
            write(*,'(A)') 'VIS3D geometry error: XML input produced no supported primitives.'
            ierr = 1
            return
        end if

        model%n_cells = maxval_default(cell_ids, 0)
        model%n_materials = size(material_names)
        model%n_surfaces = size(model%boxes) + size(model%cylinders) + size(model%spheres)
    contains
        integer function maxval_default(values, default_value)
            integer, intent(in) :: values(:)
            integer, intent(in) :: default_value
            if (size(values) == 0) then
                maxval_default = default_value
            else
                maxval_default = maxval(values)
            end if
        end function maxval_default
    end subroutine geometry_build_from_mcx_xml

    recursive subroutine expand_cell(cell, cells, planes, cylinder_surfaces, sphere_surfaces, units, lattices, &
                                     translation, parent_region, active_universe_id, active_lattice_id, &
                                     active_instance_id, model, ierr, depth)
        type(cell_spec_t), intent(in) :: cell
        type(cell_spec_t), intent(in) :: cells(:)
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        type(unit_def_t), intent(in) :: units(:)
        type(lattice_spec_t), intent(in) :: lattices(:)
        real(dp), intent(in) :: translation(3)
        type(region_spec_t), intent(in) :: parent_region
        integer, intent(in) :: active_universe_id, active_lattice_id, active_instance_id, depth
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        integer :: unit_idx, lattice_idx, universe_id
        type(region_spec_t) :: fill_region
        logical :: ok

        ierr = 0
        if (depth > 16) then
            write(*,'(A)') 'VIS3D geometry error: universe recursion too deep.'
            ierr = 1
            return
        end if

        if (cell%material_id > 0) then
            universe_id = active_universe_id
            if (universe_id <= 0) universe_id = cell%universe_id
            call append_material_from_zone(cell%zone, parent_region, planes, cylinder_surfaces, sphere_surfaces, &
                translation, cell%cell_id, cell%material_id, universe_id, active_lattice_id, active_instance_id, &
                model, ierr)
            return
        end if

        if (len_trim(cell%fill_name) == 0) return

        unit_idx = find_unit_index(units, cell%fill_name)
        if (unit_idx > 0) then
            universe_id = active_universe_id
            if (universe_id <= 0) universe_id = cell%universe_id
            call append_unit_fill(cell, units(unit_idx), parent_region, planes, cylinder_surfaces, sphere_surfaces, &
                translation, universe_id, active_lattice_id, active_instance_id, model, ierr)
            if (ierr /= 0) write(*,'(A,A)') 'VIS3D geometry error: failed to expand unit fill for cell ', trim(cell%id)
            return
        end if

        lattice_idx = find_lattice_index(lattices, cell%fill_name)
        if (lattice_idx > 0) then
            universe_id = active_universe_id
            if (universe_id <= 0) universe_id = cell%universe_id
            call expand_lattice(cell, lattices(lattice_idx), lattice_idx, cells, planes, cylinder_surfaces, &
                sphere_surfaces, units, lattices, translation, parent_region, universe_id, model, ierr, depth + 1)
            if (ierr /= 0) write(*,'(A,A)') 'VIS3D geometry error: failed to expand lattice fill for cell ', trim(cell%id)
            return
        end if

        call parse_zone_region(cell%zone, planes, cylinder_surfaces, sphere_surfaces, translation, fill_region, ok)
        if (.not. ok) then
            write(*,'(A,A)') 'VIS3D geometry error: unsupported universe fill zone: ', trim(cell%zone)
            ierr = 1
            return
        end if
        call intersect_region(parent_region, fill_region)
        call expand_universe(cell%fill_name, cells, planes, cylinder_surfaces, sphere_surfaces, units, lattices, &
            translation, fill_region, active_lattice_id, active_instance_id, model, ierr, depth + 1)
        if (ierr /= 0) write(*,'(A,A,A)') 'VIS3D geometry error: failed to expand universe fill ', trim(cell%fill_name), &
            ' for cell ' // trim(cell%id)
    end subroutine expand_cell

    recursive subroutine expand_universe(universe_name, cells, planes, cylinder_surfaces, sphere_surfaces, units, &
                                         lattices, translation, parent_region, active_lattice_id, &
                                         active_instance_id, model, ierr, depth)
        character(len=*), intent(in) :: universe_name
        type(cell_spec_t), intent(in) :: cells(:)
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        type(unit_def_t), intent(in) :: units(:)
        type(lattice_spec_t), intent(in) :: lattices(:)
        real(dp), intent(in) :: translation(3)
        type(region_spec_t), intent(in) :: parent_region
        integer, intent(in) :: active_lattice_id, active_instance_id, depth
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        integer :: i, universe_id
        logical :: found

        ierr = 0
        found = .false.
        universe_id = 0
        do i = 1, size(cells)
            if (lowercase(trim(cells(i)%universe_name)) == lowercase(trim(universe_name))) then
                universe_id = cells(i)%universe_id
                found = .true.
                exit
            end if
        end do

        if (.not. found) then
            write(*,'(A,A)') 'VIS3D geometry error: unknown universe fill ', trim(universe_name)
            ierr = 1
            return
        end if

        do i = 1, size(cells)
            if (lowercase(trim(cells(i)%universe_name)) == lowercase(trim(universe_name))) then
                call expand_cell(cells(i), cells, planes, cylinder_surfaces, sphere_surfaces, units, lattices, &
                    translation, parent_region, universe_id, active_lattice_id, active_instance_id, model, ierr, depth)
                if (ierr /= 0) then
                    write(*,'(A,A,A)') 'VIS3D geometry error: universe member failed: ', trim(universe_name), &
                        ' -> ' // trim(cells(i)%id)
                    return
                end if
            end if
        end do
    end subroutine expand_universe

    recursive subroutine expand_lattice(cell, lattice, lattice_id, cells, planes, cylinder_surfaces, sphere_surfaces, &
                                        units, lattices, translation, parent_region, active_universe_id, &
                                        model, ierr, depth)
        type(cell_spec_t), intent(in) :: cell
        type(lattice_spec_t), intent(in) :: lattice
        integer, intent(in) :: lattice_id
        type(cell_spec_t), intent(in) :: cells(:)
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        type(unit_def_t), intent(in) :: units(:)
        type(lattice_spec_t), intent(in) :: lattices(:)
        real(dp), intent(in) :: translation(3)
        type(region_spec_t), intent(in) :: parent_region
        integer, intent(in) :: active_universe_id, depth
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        type(region_spec_t) :: container_region, child_parent
        type(box_primitive_t) :: background_box
        integer :: ix, iy, iz, instance_id, unit_idx
        real(dp) :: x0, x1, y0, y1, z0, z1
        real(dp) :: target_center(3), source_center(3), child_translation(3)
        logical :: ok

        ierr = 0
        call parse_zone_region(cell%zone, planes, cylinder_surfaces, sphere_surfaces, translation, container_region, ok)
        if (.not. ok) then
            write(*,'(A,A)') 'VIS3D geometry error: unsupported lattice fill zone: ', trim(cell%zone)
            ierr = 1
            return
        end if
        call intersect_region(parent_region, container_region)
        if (.not. region_box_complete(container_region)) then
            write(*,'(A,A)') 'VIS3D geometry error: lattice container is not a bounded box: ', trim(cell%zone)
            ierr = 1
            return
        end if

        if (lattice%background_material_id > 0) then
            background_box%xmin = container_region%xmin
            background_box%xmax = container_region%xmax
            background_box%ymin = container_region%ymin
            background_box%ymax = container_region%ymax
            background_box%zmin = container_region%zmin
            background_box%zmax = container_region%zmax
            background_box%cell_id = cell%cell_id
            background_box%material_id = lattice%background_material_id
            background_box%universe_id = active_universe_id
            background_box%lattice_id = lattice_id
            background_box%instance_id = 0
            background_box%surface_id = model%n_surfaces + 1
            call append_box(model, background_box)
        end if

        instance_id = 1
        z0 = container_region%zmin
        z1 = container_region%zmax
        do iz = 1, lattice%nz
            do iy = 1, lattice%ny
                do ix = 1, lattice%nx
                    if (len_trim(lattice%token_names(ix, iy, iz)) == 0) cycle
                    x0 = lattice%lower_left(1) + translation(1) + real(ix - 1, dp) * lattice%pitch(1)
                    x1 = x0 + lattice%pitch(1)
                    y0 = lattice%lower_left(2) + translation(2) + real(iy - 1, dp) * lattice%pitch(2)
                    y1 = y0 + lattice%pitch(2)
                    if (lattice%nz > 1) then
                        z0 = lattice%lower_left(3) + translation(3) + real(iz - 1, dp) * lattice%pitch(3)
                        z1 = z0 + lattice%pitch(3)
                    end if

                    child_parent = empty_region()
                    child_parent%xmin = x0; child_parent%xmax = x1
                    child_parent%ymin = y0; child_parent%ymax = y1
                    child_parent%zmin = z0; child_parent%zmax = z1
                    child_parent%xmin_set = .true.; child_parent%xmax_set = .true.
                    child_parent%ymin_set = .true.; child_parent%ymax_set = .true.
                    child_parent%zmin_set = .true.; child_parent%zmax_set = .true.

                    unit_idx = find_unit_index(units, lattice%token_names(ix, iy, iz))
                    if (unit_idx > 0) then
                        call append_unit_region(units(unit_idx), child_parent, cell%cell_id, active_universe_id, &
                            lattice_id, instance_id, model, ierr, .false.)
                        if (ierr /= 0) return
                    else
                        call universe_reference_center(lattice%token_names(ix, iy, iz), cells, planes, &
                            cylinder_surfaces, sphere_surfaces, source_center, ok)
                        target_center = [0.5_dp * (x0 + x1), 0.5_dp * (y0 + y1), 0.5_dp * (z0 + z1)]
                        child_translation = translation
                        if (ok) child_translation = child_translation + target_center - source_center
                        call expand_universe(lattice%token_names(ix, iy, iz), cells, planes, cylinder_surfaces, &
                            sphere_surfaces, units, lattices, child_translation, child_parent, lattice_id, &
                            instance_id, model, ierr, depth + 1)
                        if (ierr /= 0) return
                    end if
                    instance_id = instance_id + 1
                end do
            end do
        end do
    end subroutine expand_lattice

    subroutine append_unit_fill(cell, unit, parent_region, planes, cylinder_surfaces, sphere_surfaces, translation, &
                                active_universe_id, active_lattice_id, active_instance_id, model, ierr)
        type(cell_spec_t), intent(in) :: cell
        type(unit_def_t), intent(in) :: unit
        type(region_spec_t), intent(in) :: parent_region
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        real(dp), intent(in) :: translation(3)
        integer, intent(in) :: active_universe_id, active_lattice_id, active_instance_id
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        type(region_spec_t) :: container_region
        logical :: ok

        ierr = 0
        call parse_zone_region(cell%zone, planes, cylinder_surfaces, sphere_surfaces, translation, container_region, ok)
        if (.not. ok) then
            write(*,'(A,A)') 'VIS3D geometry error: unsupported unit fill zone: ', trim(cell%zone)
            ierr = 1
            return
        end if
        call intersect_region(parent_region, container_region)
        call append_unit_region(unit, container_region, cell%cell_id, active_universe_id, active_lattice_id, &
            active_instance_id, model, ierr, .true.)
    end subroutine append_unit_fill

    subroutine append_unit_region(unit, region, cell_id, universe_id, lattice_id, instance_id, model, ierr, &
                                  emit_background)
        type(unit_def_t), intent(in) :: unit
        type(region_spec_t), intent(in) :: region
        integer, intent(in) :: cell_id, universe_id, lattice_id, instance_id
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr
        logical, intent(in) :: emit_background

        type(box_primitive_t) :: box
        type(cylinder_primitive_t) :: cyl
        type(sphere_primitive_t) :: sph
        integer :: layer, nmat
        real(dp) :: rmin

        ierr = 0
        nmat = 0
        if (allocated(unit%material_ids)) nmat = size(unit%material_ids)
        if (.not. allocated(unit%radii)) then
            ierr = 1
            return
        end if

        if (unit%kind == UNIT_KIND_CYLINDER) then
            if (.not. region_box_complete(region)) then
                ierr = 1
                return
            end if
            if (emit_background .and. nmat > size(unit%radii)) then
                box%xmin = region%xmin
                box%xmax = region%xmax
                box%ymin = region%ymin
                box%ymax = region%ymax
                box%zmin = region%zmin
                box%zmax = region%zmax
                box%cell_id = cell_id
                box%material_id = unit%material_ids(nmat)
                box%universe_id = universe_id
                box%lattice_id = lattice_id
                box%instance_id = instance_id
                box%surface_id = model%n_surfaces + 1
                call append_box(model, box)
            end if

            rmin = 0.0_dp
            do layer = 1, size(unit%radii)
                cyl%xc = 0.5_dp * (region%xmin + region%xmax)
                cyl%yc = 0.5_dp * (region%ymin + region%ymax)
                cyl%zmin = region%zmin
                cyl%zmax = region%zmax
                cyl%rmin = rmin
                cyl%rmax = unit%radii(layer)
                cyl%cell_id = cell_id
                cyl%material_id = unit%material_ids(min(layer, nmat))
                cyl%universe_id = universe_id
                cyl%lattice_id = lattice_id
                cyl%instance_id = instance_id
                cyl%surface_id = model%n_surfaces + 1
                call append_cylinder(model, cyl)
                rmin = unit%radii(layer)
            end do
        else if (unit%kind == UNIT_KIND_SPHERE) then
            if (.not. region%has_sphere .or. .not. is_finite_bound(region%sph_rmax)) then
                ierr = 1
                return
            end if

            if (emit_background .and. nmat > size(unit%radii) .and. region%sph_rmax > unit%radii(size(unit%radii))) then
                sph%xc = region%sph_xc
                sph%yc = region%sph_yc
                sph%zc = region%sph_zc
                sph%rmin = unit%radii(size(unit%radii))
                sph%rmax = region%sph_rmax
                sph%cell_id = cell_id
                sph%material_id = unit%material_ids(nmat)
                sph%universe_id = universe_id
                sph%lattice_id = lattice_id
                sph%instance_id = instance_id
                sph%surface_id = model%n_surfaces + 1
                call append_sphere(model, sph)
            end if

            rmin = 0.0_dp
            do layer = 1, size(unit%radii)
                sph%xc = region%sph_xc
                sph%yc = region%sph_yc
                sph%zc = region%sph_zc
                sph%rmin = rmin
                sph%rmax = unit%radii(layer)
                sph%cell_id = cell_id
                sph%material_id = unit%material_ids(min(layer, nmat))
                sph%universe_id = universe_id
                sph%lattice_id = lattice_id
                sph%instance_id = instance_id
                sph%surface_id = model%n_surfaces + 1
                call append_sphere(model, sph)
                rmin = unit%radii(layer)
            end do
        else
            ierr = 1
        end if
    end subroutine append_unit_region

    subroutine append_material_from_zone(zone, parent_region, planes, cylinder_surfaces, sphere_surfaces, translation, &
                                         cell_id, material_id, universe_id, lattice_id, instance_id, model, ierr)
        character(len=*), intent(in) :: zone
        type(region_spec_t), intent(in) :: parent_region
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        real(dp), intent(in) :: translation(3)
        integer, intent(in) :: cell_id, material_id, universe_id, lattice_id, instance_id
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        type(region_spec_t) :: region
        logical :: ok, handled

        ierr = 0
        handled = .false.
        if (index(zone, '~') > 0 .or. index(zone, '|') > 0) then
            call try_append_plane_boolean_zone(zone, parent_region, planes, translation, cell_id, material_id, &
                universe_id, lattice_id, instance_id, model, handled, ierr)
            if (ierr /= 0 .or. handled) return
        end if

        call parse_zone_region(zone, planes, cylinder_surfaces, sphere_surfaces, translation, region, ok)
        if (.not. ok) then
            write(*,'(A,A)') 'VIS3D geometry error: unsupported zone: ', trim(zone)
            ierr = 1
            return
        end if
        call intersect_region(parent_region, region)
        call append_region(region, cell_id, material_id, universe_id, lattice_id, instance_id, model, ierr)
    end subroutine append_material_from_zone

    subroutine try_append_plane_boolean_zone(zone, parent_region, planes, translation, cell_id, material_id, universe_id, &
                                             lattice_id, instance_id, model, handled, ierr)
        character(len=*), intent(in) :: zone
        type(region_spec_t), intent(in) :: parent_region
        type(plane_spec_t), intent(in) :: planes(:)
        real(dp), intent(in) :: translation(3)
        integer, intent(in) :: cell_id, material_id, universe_id, lattice_id, instance_id
        type(geometry_model_t), intent(inout) :: model
        logical, intent(out) :: handled
        integer, intent(out) :: ierr

        type(box_primitive_t) :: outer_box, inner_box
        character(len=LINE_LEN) :: outer_text, inner_text, extra_text, outside_text
        logical :: ok

        handled = .false.
        ierr = 0

        if (parent_region%has_sphere .or. parent_region%has_cylinder) return

        if (index(zone, '~') > 0) then
            call extract_box_difference(zone, outer_text, inner_text, extra_text, ok)
            if (.not. ok) then
                ierr = 1
                return
            end if
            call parse_box_zone(trim(outer_text) // ' ' // trim(extra_text), planes, translation, outer_box, ok)
            if (.not. ok) then
                ierr = 1
                return
            end if
            call parse_box_zone(trim(inner_text) // ' ' // trim(extra_text), planes, translation, inner_box, ok)
            if (.not. ok) then
                ierr = 1
                return
            end if
            call apply_parent_box_clip(parent_region, outer_box)
            call apply_parent_box_clip(parent_region, inner_box)
            call append_rectangular_annulus(model, outer_box, inner_box, cell_id, material_id, universe_id, &
                lattice_id, instance_id, ierr)
            handled = .true.
            return
        end if

        if (index(zone, '|') > 0) then
            call extract_outside_box(zone, outside_text, extra_text, ok)
            if (.not. ok) return
            call parse_box_zone(trim(extra_text), planes, translation, outer_box, ok)
            if (.not. ok) return
            call outside_clause_to_box(outside_text, inner_text)
            call parse_box_zone(trim(inner_text) // ' ' // trim(extract_z_tokens(extra_text, planes)), planes, &
                translation, inner_box, ok)
            if (.not. ok) return
            call apply_parent_box_clip(parent_region, outer_box)
            call apply_parent_box_clip(parent_region, inner_box)
            call append_rectangular_annulus(model, outer_box, inner_box, cell_id, material_id, universe_id, &
                lattice_id, instance_id, ierr)
            handled = .true.
        end if
    contains
        function extract_z_tokens(text, planes) result(z_tokens)
            character(len=*), intent(in) :: text
            type(plane_spec_t), intent(in) :: planes(:)
            character(len=LINE_LEN) :: z_tokens
            call extract_axis_tokens(text, planes, 3, z_tokens)
        end function extract_z_tokens
    end subroutine try_append_plane_boolean_zone

    subroutine append_region(region, cell_id, material_id, universe_id, lattice_id, instance_id, model, ierr)
        type(region_spec_t), intent(in) :: region
        integer, intent(in) :: cell_id, material_id, universe_id, lattice_id, instance_id
        type(geometry_model_t), intent(inout) :: model
        integer, intent(out) :: ierr

        type(box_primitive_t) :: box
        type(cylinder_primitive_t) :: cyl
        type(sphere_primitive_t) :: sph

        ierr = 0

        if (region%has_sphere .and. is_finite_bound(region%sph_rmax)) then
            if (region%sph_rmax <= region%sph_rmin) then
                ierr = 1
                return
            end if
            sph%xc = region%sph_xc
            sph%yc = region%sph_yc
            sph%zc = region%sph_zc
            sph%rmin = region%sph_rmin
            sph%rmax = region%sph_rmax
            sph%cell_id = cell_id
            sph%material_id = material_id
            sph%universe_id = universe_id
            sph%lattice_id = lattice_id
            sph%instance_id = instance_id
            sph%surface_id = model%n_surfaces + 1
            call append_sphere(model, sph)
            return
        end if

        if (region%has_cylinder .and. is_finite_bound(region%cyl_rmax) .and. region_box_has_z(region)) then
            if (region%cyl_rmax <= region%cyl_rmin) then
                ierr = 1
                return
            end if
            cyl%xc = region%cyl_xc
            cyl%yc = region%cyl_yc
            cyl%zmin = region%zmin
            cyl%zmax = region%zmax
            cyl%rmin = region%cyl_rmin
            cyl%rmax = region%cyl_rmax
            cyl%cell_id = cell_id
            cyl%material_id = material_id
            cyl%universe_id = universe_id
            cyl%lattice_id = lattice_id
            cyl%instance_id = instance_id
            cyl%surface_id = model%n_surfaces + 1
            call append_cylinder(model, cyl)
            return
        end if

        if (region_box_complete(region)) then
            box%xmin = region%xmin
            box%xmax = region%xmax
            box%ymin = region%ymin
            box%ymax = region%ymax
            box%zmin = region%zmin
            box%zmax = region%zmax
            box%cell_id = cell_id
            box%material_id = material_id
            box%universe_id = universe_id
            box%lattice_id = lattice_id
            box%instance_id = instance_id
            box%surface_id = model%n_surfaces + 1
            call append_box(model, box)
            return
        end if

        ierr = 1
    end subroutine append_region

    subroutine parse_zone_region(zone, planes, cylinder_surfaces, sphere_surfaces, translation, region, ok)
        character(len=*), intent(in) :: zone
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        real(dp), intent(in) :: translation(3)
        type(region_spec_t), intent(out) :: region
        logical, intent(out) :: ok

        character(len=NAME_LEN), allocatable :: tokens(:)
        character(len=NAME_LEN) :: token, surface_id
        integer :: i, axis
        real(dp) :: value
        logical :: found
        type(cylinder_surface_t) :: cyl_surf
        type(sphere_surface_t) :: sph_surf

        region = empty_region()
        ok = .false.
        call parse_name_list(zone, tokens)

        do i = 1, size(tokens)
            token = trim(tokens(i))
            if (len_trim(token) == 0) cycle
            surface_id = token
            if (token(1:1) == '-') surface_id = token(2:)

            call find_plane(planes, surface_id, axis, value, found)
            if (found) then
                value = value + translation(axis)
                if (token(1:1) == '-') then
                    select case (axis)
                    case (1)
                        region%xmax = min(region%xmax, value)
                        region%xmax_set = .true.
                    case (2)
                        region%ymax = min(region%ymax, value)
                        region%ymax_set = .true.
                    case (3)
                        region%zmax = min(region%zmax, value)
                        region%zmax_set = .true.
                    end select
                else
                    select case (axis)
                    case (1)
                        region%xmin = max(region%xmin, value)
                        region%xmin_set = .true.
                    case (2)
                        region%ymin = max(region%ymin, value)
                        region%ymin_set = .true.
                    case (3)
                        region%zmin = max(region%zmin, value)
                        region%zmin_set = .true.
                    end select
                end if
                cycle
            end if

            call find_cylinder_surface(cylinder_surfaces, surface_id, cyl_surf, found)
            if (found) then
                region%has_cylinder = .true.
                region%cyl_xc = cyl_surf%xc + translation(1)
                region%cyl_yc = cyl_surf%yc + translation(2)
                if (token(1:1) == '-') then
                    region%cyl_rmax = min(region%cyl_rmax, cyl_surf%radius)
                else
                    region%cyl_rmin = max(region%cyl_rmin, cyl_surf%radius)
                end if
                cycle
            end if

            call find_sphere_surface(sphere_surfaces, surface_id, sph_surf, found)
            if (found) then
                region%has_sphere = .true.
                region%sph_xc = sph_surf%xc + translation(1)
                region%sph_yc = sph_surf%yc + translation(2)
                region%sph_zc = sph_surf%zc + translation(3)
                if (token(1:1) == '-') then
                    region%sph_rmax = min(region%sph_rmax, sph_surf%radius)
                else
                    region%sph_rmin = max(region%sph_rmin, sph_surf%radius)
                end if
            end if
        end do

        ok = .true.
    end subroutine parse_zone_region

    subroutine intersect_region(parent_region, region)
        type(region_spec_t), intent(in) :: parent_region
        type(region_spec_t), intent(inout) :: region

        if (parent_region%xmin_set) then
            region%xmin = max(region%xmin, parent_region%xmin)
            region%xmin_set = .true.
        end if
        if (parent_region%xmax_set) then
            region%xmax = min(region%xmax, parent_region%xmax)
            region%xmax_set = .true.
        end if
        if (parent_region%ymin_set) then
            region%ymin = max(region%ymin, parent_region%ymin)
            region%ymin_set = .true.
        end if
        if (parent_region%ymax_set) then
            region%ymax = min(region%ymax, parent_region%ymax)
            region%ymax_set = .true.
        end if
        if (parent_region%zmin_set) then
            region%zmin = max(region%zmin, parent_region%zmin)
            region%zmin_set = .true.
        end if
        if (parent_region%zmax_set) then
            region%zmax = min(region%zmax, parent_region%zmax)
            region%zmax_set = .true.
        end if

        if (parent_region%has_cylinder) then
            if (.not. region%has_cylinder) then
                region%has_cylinder = .true.
                region%cyl_xc = parent_region%cyl_xc
                region%cyl_yc = parent_region%cyl_yc
                region%cyl_rmin = parent_region%cyl_rmin
                region%cyl_rmax = parent_region%cyl_rmax
            else if (same_xy_center(parent_region%cyl_xc, parent_region%cyl_yc, region%cyl_xc, region%cyl_yc)) then
                region%cyl_rmin = max(region%cyl_rmin, parent_region%cyl_rmin)
                region%cyl_rmax = min(region%cyl_rmax, parent_region%cyl_rmax)
            end if
        end if

        if (parent_region%has_sphere) then
            if (.not. region%has_sphere) then
                region%has_sphere = .true.
                region%sph_xc = parent_region%sph_xc
                region%sph_yc = parent_region%sph_yc
                region%sph_zc = parent_region%sph_zc
                region%sph_rmin = parent_region%sph_rmin
                region%sph_rmax = parent_region%sph_rmax
            else if (same_xyz_center(parent_region%sph_xc, parent_region%sph_yc, parent_region%sph_zc, &
                                     region%sph_xc, region%sph_yc, region%sph_zc)) then
                region%sph_rmin = max(region%sph_rmin, parent_region%sph_rmin)
                region%sph_rmax = min(region%sph_rmax, parent_region%sph_rmax)
            end if
        end if
    end subroutine intersect_region

    subroutine apply_parent_box_clip(parent_region, box)
        type(region_spec_t), intent(in) :: parent_region
        type(box_primitive_t), intent(inout) :: box

        if (parent_region%xmin_set) box%xmin = max(box%xmin, parent_region%xmin)
        if (parent_region%xmax_set) box%xmax = min(box%xmax, parent_region%xmax)
        if (parent_region%ymin_set) box%ymin = max(box%ymin, parent_region%ymin)
        if (parent_region%ymax_set) box%ymax = min(box%ymax, parent_region%ymax)
        if (parent_region%zmin_set) box%zmin = max(box%zmin, parent_region%zmin)
        if (parent_region%zmax_set) box%zmax = min(box%zmax, parent_region%zmax)
    end subroutine apply_parent_box_clip

    subroutine append_rectangular_annulus(model, outer_box, inner_box, cell_id, material_id, universe_id, lattice_id, &
                                          instance_id, ierr)
        type(geometry_model_t), intent(inout) :: model
        type(box_primitive_t), intent(in) :: outer_box, inner_box
        integer, intent(in) :: cell_id, material_id, universe_id, lattice_id, instance_id
        integer, intent(out) :: ierr

        type(box_primitive_t) :: box

        ierr = 0
        if (inner_box%xmin > outer_box%xmin) then
            box = outer_box
            box%xmax = inner_box%xmin
            box%cell_id = cell_id; box%material_id = material_id
            box%universe_id = universe_id; box%lattice_id = lattice_id; box%instance_id = instance_id
            box%surface_id = model%n_surfaces + 1
            call append_box(model, box)
        end if
        if (inner_box%xmax < outer_box%xmax) then
            box = outer_box
            box%xmin = inner_box%xmax
            box%cell_id = cell_id; box%material_id = material_id
            box%universe_id = universe_id; box%lattice_id = lattice_id; box%instance_id = instance_id
            box%surface_id = model%n_surfaces + 1
            call append_box(model, box)
        end if
        if (inner_box%ymin > outer_box%ymin) then
            box = outer_box
            box%xmin = inner_box%xmin
            box%xmax = inner_box%xmax
            box%ymax = inner_box%ymin
            box%cell_id = cell_id; box%material_id = material_id
            box%universe_id = universe_id; box%lattice_id = lattice_id; box%instance_id = instance_id
            box%surface_id = model%n_surfaces + 1
            call append_box(model, box)
        end if
        if (inner_box%ymax < outer_box%ymax) then
            box = outer_box
            box%xmin = inner_box%xmin
            box%xmax = inner_box%xmax
            box%ymin = inner_box%ymax
            box%cell_id = cell_id; box%material_id = material_id
            box%universe_id = universe_id; box%lattice_id = lattice_id; box%instance_id = instance_id
            box%surface_id = model%n_surfaces + 1
            call append_box(model, box)
        end if
    end subroutine append_rectangular_annulus

    subroutine parse_surface_line(line, planes, cylinder_surfaces, sphere_surfaces)
        character(len=*), intent(in) :: line
        type(plane_spec_t), allocatable, intent(inout) :: planes(:)
        type(cylinder_surface_t), allocatable, intent(inout) :: cylinder_surfaces(:)
        type(sphere_surface_t), allocatable, intent(inout) :: sphere_surfaces(:)

        character(len=NAME_LEN) :: id_text, type_text
        character(len=LINE_LEN) :: coeffs_text
        real(dp), allocatable :: coeffs(:)
        type(plane_spec_t) :: plane
        type(cylinder_surface_t) :: cyl
        type(sphere_surface_t) :: sph

        call get_attr(line, 'id', id_text)
        call get_attr(line, 'type', type_text)
        call get_attr(line, 'coeffs', coeffs_text)
        if (len_trim(id_text) == 0 .or. len_trim(type_text) == 0) return

        if (axis_from_surface_type(type_text) > 0) then
            plane%id = trim(id_text)
            plane%axis = axis_from_surface_type(type_text)
            call parse_first_real(coeffs_text, plane%value)
            call append_plane(planes, plane)
            return
        end if

        call parse_real_list(coeffs_text, coeffs)
        if (index(lowercase(trim(type_text)), 'cylinder-z') > 0 .and. size(coeffs) >= 3) then
            cyl%id = trim(id_text)
            cyl%xc = coeffs(1)
            cyl%yc = coeffs(2)
            cyl%radius = coeffs(3)
            call append_cylinder_surface(cylinder_surfaces, cyl)
        else if (index(lowercase(trim(type_text)), 'sphere') > 0 .and. size(coeffs) >= 4) then
            sph%id = trim(id_text)
            sph%xc = coeffs(1)
            sph%yc = coeffs(2)
            sph%zc = coeffs(3)
            sph%radius = coeffs(4)
            call append_sphere_surface(sphere_surfaces, sph)
        end if
    end subroutine parse_surface_line

    subroutine parse_unit_block(lines, i, kind, units, material_names)
        character(len=LINE_LEN), intent(in) :: lines(:)
        integer, intent(inout) :: i
        integer, intent(in) :: kind
        type(unit_def_t), allocatable, intent(inout) :: units(:)
        character(len=NAME_LEN), allocatable, intent(inout) :: material_names(:)

        type(unit_def_t) :: unit
        character(len=NAME_LEN), allocatable :: material_tokens(:)
        real(dp), allocatable :: radii(:)
        character(len=LINE_LEN) :: line, materials_text, radii_text
        integer :: j, material_id

        materials_text = ''
        radii_text = ''
        call get_attr(lines(i), 'id', unit%id)
        unit%kind = kind

        do
            i = i + 1
            if (i > size(lines)) exit
            line = trim(adjustl(lines(i)))
            if (starts_with(line, '<materials>')) call get_tag_text(line, 'materials', materials_text)
            if (starts_with(line, '<radii>')) call get_tag_text(line, 'radii', radii_text)
            if (starts_with(line, '</pin>') .or. starts_with(line, '</particle>')) exit
        end do

        call parse_name_list(materials_text, material_tokens)
        if (size(material_tokens) > 0) then
            allocate(unit%material_ids(size(material_tokens)))
            do j = 1, size(material_tokens)
                call ensure_name_index(material_names, material_tokens(j), material_id)
                unit%material_ids(j) = material_id
            end do
        end if

        call parse_real_list(radii_text, radii)
        if (allocated(radii)) then
            allocate(unit%radii(size(radii)))
            unit%radii = radii
        end if

        call append_unit(units, unit)
    end subroutine parse_unit_block

    subroutine parse_lattice_block(lines, i, lattices, ierr)
        character(len=LINE_LEN), intent(in) :: lines(:)
        integer, intent(inout) :: i
        type(lattice_spec_t), allocatable, intent(inout) :: lattices(:)
        integer, intent(out) :: ierr

        type(lattice_spec_t) :: lattice
        character(len=LINE_LEN) :: line, universes_block, text
        character(len=NAME_LEN), allocatable :: universe_tokens(:)
        real(dp), allocatable :: values(:)
        integer, allocatable :: dims(:)
        integer :: idx, ix, iy, iz

        ierr = 0
        universes_block = ''
        call get_attr(lines(i), 'id', lattice%id)

        do
            i = i + 1
            if (i > size(lines)) exit
            line = trim(adjustl(lines(i)))
            if (starts_with(line, '<pitch>')) then
                call get_tag_text(line, 'pitch', text)
                call parse_real_list(text, values)
                if (size(values) >= 1) lattice%pitch(1) = values(1)
                if (size(values) >= 2) lattice%pitch(2) = values(2)
                if (size(values) >= 3) lattice%pitch(3) = values(3)
            end if
            if (starts_with(line, '<dimensions>')) then
                call get_tag_text(line, 'dimensions', text)
                call parse_int_list(text, dims)
                if (size(dims) >= 1) lattice%nx = dims(1)
                if (size(dims) >= 2) lattice%ny = dims(2)
                if (size(dims) >= 3) lattice%nz = dims(3)
            end if
            if (starts_with(line, '<lower_left>')) then
                call get_tag_text(line, 'lower_left', text)
                call parse_real_list(text, values)
                if (size(values) >= 1) lattice%lower_left(1) = values(1)
                if (size(values) >= 2) lattice%lower_left(2) = values(2)
                if (size(values) >= 3) lattice%lower_left(3) = values(3)
            end if
            if (index(line, '<universes>') > 0) then
                call collect_tag_block(lines, i, 'universes', universes_block)
            end if
            if (starts_with(line, '</lattice>')) exit
        end do

        if (lattice%nx <= 0 .or. lattice%ny <= 0 .or. lattice%nz <= 0) then
            ierr = 1
            return
        end if
        if (lattice%pitch(3) <= 0.0_dp) lattice%pitch(3) = 1.0_dp

        call parse_name_list(universes_block, universe_tokens)
        if (size(universe_tokens) < lattice%nx * lattice%ny * lattice%nz) then
            ierr = 1
            return
        end if

        allocate(lattice%token_names(lattice%nx, lattice%ny, lattice%nz))
        idx = 1
        do iz = 1, lattice%nz
            do iy = 1, lattice%ny
                do ix = 1, lattice%nx
                    lattice%token_names(ix, iy, iz) = universe_tokens(idx)
                    idx = idx + 1
                end do
            end do
        end do

        call append_lattice(lattices, lattice)
    end subroutine parse_lattice_block

    subroutine parse_cell_line(line, material_names, cell_names, cell_ids, next_cell_id, universe_names, universe_ids, &
                               next_universe_id, cell, ierr)
        character(len=*), intent(in) :: line
        character(len=NAME_LEN), allocatable, intent(inout) :: material_names(:), cell_names(:), universe_names(:)
        integer, allocatable, intent(inout) :: cell_ids(:), universe_ids(:)
        integer, intent(inout) :: next_cell_id, next_universe_id
        type(cell_spec_t), intent(out) :: cell
        integer, intent(out) :: ierr

        character(len=NAME_LEN) :: material_name

        ierr = 0
        cell = cell_spec_t()
        call get_attr(line, 'id', cell%id)
        call map_name_id(cell_names, cell_ids, next_cell_id, cell%id, cell%cell_id)
        call get_attr(line, 'zone', cell%zone)
        call get_attr(line, 'fill', cell%fill_name)
        call get_attr(line, 'universe', cell%universe_name)
        if (len_trim(cell%universe_name) > 0) then
            call map_name_id(universe_names, universe_ids, next_universe_id, cell%universe_name, cell%universe_id)
        end if

        material_name = ''
        call get_attr(line, 'material', material_name)
        if (len_trim(material_name) > 0 .and. lowercase(trim(material_name)) /= 'void') then
            call ensure_name_index(material_names, material_name, cell%material_id)
        else
            cell%material_id = 0
        end if
    end subroutine parse_cell_line

    subroutine parse_box_zone(zone, planes, translation, box, ok)
        character(len=*), intent(in) :: zone
        type(plane_spec_t), intent(in) :: planes(:)
        real(dp), intent(in) :: translation(3)
        type(box_primitive_t), intent(out) :: box
        logical, intent(out) :: ok

        character(len=NAME_LEN), allocatable :: tokens(:)
        character(len=NAME_LEN) :: token, plane_name
        integer :: i, axis
        real(dp) :: value
        logical :: found

        box = box_primitive_t()
        box%xmin = REGION_BIG; box%ymin = REGION_BIG; box%zmin = REGION_BIG
        box%xmax = -REGION_BIG; box%ymax = -REGION_BIG; box%zmax = -REGION_BIG

        call parse_name_list(zone, tokens)
        do i = 1, size(tokens)
            token = trim(tokens(i))
            if (len_trim(token) == 0) cycle
            plane_name = token
            if (token(1:1) == '-') plane_name = token(2:)
            call find_plane(planes, plane_name, axis, value, found)
            if (.not. found) cycle
            value = value + translation(axis)
            if (token(1:1) == '-') then
                select case (axis)
                case (1)
                    box%xmax = value
                case (2)
                    box%ymax = value
                case (3)
                    box%zmax = value
                end select
            else
                select case (axis)
                case (1)
                    box%xmin = value
                case (2)
                    box%ymin = value
                case (3)
                    box%zmin = value
                end select
            end if
        end do

        ok = box%xmax > box%xmin .and. box%ymax > box%ymin .and. box%zmax > box%zmin
    end subroutine parse_box_zone

    subroutine extract_box_difference(zone, outer_text, inner_text, extra_text, ok)
        character(len=*), intent(in) :: zone
        character(len=*), intent(out) :: outer_text, inner_text, extra_text
        logical, intent(out) :: ok
        integer :: p_tilde, p_inner_end

        ok = .false.
        outer_text = ''
        inner_text = ''
        extra_text = ''
        p_tilde = index(zone, '~')
        if (p_tilde <= 0) return
        outer_text = trim(adjustl(zone(3:p_tilde-2)))
        p_inner_end = index(zone(p_tilde+2:), '))')
        if (p_inner_end <= 0) return
        inner_text = trim(adjustl(zone(p_tilde+2:p_tilde+p_inner_end)))
        extra_text = trim(adjustl(zone(p_tilde+p_inner_end+3:)))
        ok = len_trim(outer_text) > 0 .and. len_trim(inner_text) > 0
    end subroutine extract_box_difference

    subroutine extract_axis_tokens(zone, planes, axis_target, axis_text)
        character(len=*), intent(in) :: zone
        type(plane_spec_t), intent(in) :: planes(:)
        integer, intent(in) :: axis_target
        character(len=*), intent(out) :: axis_text

        character(len=NAME_LEN), allocatable :: tokens(:)
        character(len=NAME_LEN) :: token, plane_name
        integer :: i, axis
        real(dp) :: value
        logical :: found

        axis_text = ''
        call parse_name_list(zone, tokens)
        do i = 1, size(tokens)
            token = trim(tokens(i))
            if (len_trim(token) == 0) cycle
            plane_name = token
            if (token(1:1) == '-') plane_name = token(2:)
            call find_plane(planes, plane_name, axis, value, found)
            if (.not. found) cycle
            if (axis == axis_target) then
                if (len_trim(axis_text) > 0) then
                    axis_text = trim(axis_text) // ' ' // trim(token)
                else
                    axis_text = trim(token)
                end if
            end if
        end do
    end subroutine extract_axis_tokens

    subroutine extract_outside_box(zone, outside_text, outer_text, ok)
        character(len=*), intent(in) :: zone
        character(len=*), intent(out) :: outside_text, outer_text
        logical, intent(out) :: ok
        integer :: p1, p2

        ok = .false.
        outside_text = ''
        outer_text = ''
        p1 = index(zone, '(')
        p2 = index(zone, ')')
        if (p1 <= 0 .or. p2 <= p1) return
        outside_text = trim(adjustl(zone(p1+1:p2-1)))
        outer_text = trim(adjustl(zone(p2+1:)))
        ok = len_trim(outside_text) > 0 .and. len_trim(outer_text) > 0
    end subroutine extract_outside_box

    subroutine outside_clause_to_box(outside_text, inner_text)
        character(len=*), intent(in) :: outside_text
        character(len=*), intent(out) :: inner_text

        character(len=NAME_LEN), allocatable :: tokens(:)
        integer :: i

        inner_text = ''
        call parse_name_list(outside_text, tokens)
        do i = 1, size(tokens)
            if (tokens(i)(1:1) == '-') then
                if (len_trim(inner_text) > 0) then
                    inner_text = trim(inner_text) // ' ' // trim(tokens(i)(2:))
                else
                    inner_text = trim(tokens(i)(2:))
                end if
            else
                if (len_trim(inner_text) > 0) then
                    inner_text = trim(inner_text) // ' ' // '-' // trim(tokens(i))
                else
                    inner_text = '-' // trim(tokens(i))
                end if
            end if
        end do
    end subroutine outside_clause_to_box

    subroutine read_all_lines(filename, lines, ierr)
        character(len=*), intent(in) :: filename
        character(len=LINE_LEN), allocatable, intent(out) :: lines(:)
        integer, intent(out) :: ierr

        integer :: unit, ios, n
        character(len=LINE_LEN) :: line
        character(len=LINE_LEN), allocatable :: tmp(:)

        ierr = 0
        allocate(lines(0))
        open(newunit=unit, file=trim(filename), status='old', action='read', iostat=ios)
        if (ios /= 0) then
            ierr = ios
            return
        end if

        do
            read(unit, '(A)', iostat=ios) line
            if (ios /= 0) exit
            n = size(lines)
            allocate(tmp(n+1))
            if (n > 0) tmp(1:n) = lines
            tmp(n+1) = line
            call move_alloc(tmp, lines)
        end do
        close(unit)
    end subroutine read_all_lines

    subroutine get_attr(line, name, value)
        character(len=*), intent(in) :: line, name
        character(len=*), intent(out) :: value

        character(len=LINE_LEN) :: work
        integer :: p, q, start

        value = ''
        work = line
        p = index(lowercase(work), lowercase(trim(name)))
        do while (p > 0)
            start = p + len_trim(name)
            do while (start <= len_trim(work) .and. work(start:start) == ' ')
                start = start + 1
            end do
            if (start > len_trim(work)) exit
            if (work(start:start) /= '=') then
                q = index(lowercase(work(p+1:)), lowercase(trim(name)))
                if (q <= 0) exit
                p = p + q
                cycle
            end if
            start = start + 1
            do while (start <= len_trim(work) .and. work(start:start) == ' ')
                start = start + 1
            end do
            if (start > len_trim(work) .or. work(start:start) /= '"') return
            q = index(work(start+1:), '"')
            if (q <= 0) return
            value = trim(adjustl(work(start+1:start+q-1)))
            return
        end do
    end subroutine get_attr

    subroutine collect_material_id(line, material_names)
        character(len=*), intent(in) :: line
        character(len=NAME_LEN), allocatable, intent(inout) :: material_names(:)
        character(len=NAME_LEN) :: material_name
        integer :: dummy

        if (index(lowercase(line), '<material') <= 0) return
        call get_attr(line, 'id', material_name)
        if (len_trim(material_name) > 0 .and. lowercase(trim(material_name)) /= 'void') then
            call ensure_name_index(material_names, material_name, dummy)
        end if
    end subroutine collect_material_id

    subroutine get_tag_text(line, tag, text)
        character(len=*), intent(in) :: line, tag
        character(len=*), intent(out) :: text
        character(len=128) :: open_tag, close_tag
        integer :: p1, p2

        text = ''
        open_tag = '<' // trim(tag) // '>'
        close_tag = '</' // trim(tag) // '>'
        p1 = index(line, trim(open_tag))
        p2 = index(line, trim(close_tag))
        if (p1 <= 0 .or. p2 <= p1) return
        text = trim(adjustl(line(p1 + len_trim(open_tag):p2 - 1)))
    end subroutine get_tag_text

    subroutine collect_tag_block(lines, i, tag, text)
        character(len=LINE_LEN), intent(in) :: lines(:)
        integer, intent(inout) :: i
        character(len=*), intent(in) :: tag
        character(len=*), intent(out) :: text

        character(len=128) :: open_tag, close_tag
        character(len=LINE_LEN) :: line
        integer :: p1, p2

        text = ''
        open_tag = '<' // trim(tag) // '>'
        close_tag = '</' // trim(tag) // '>'

        line = trim(adjustl(lines(i)))
        p1 = index(line, trim(open_tag))
        if (p1 > 0) line = line(p1 + len_trim(open_tag):)

        do
            p2 = index(line, trim(close_tag))
            if (p2 > 0) then
                if (p2 > 1) text = trim(text) // ' ' // trim(adjustl(line(:p2-1)))
                exit
            end if
            text = trim(text) // ' ' // trim(adjustl(line))
            i = i + 1
            if (i > size(lines)) exit
            line = trim(adjustl(lines(i)))
        end do
    end subroutine collect_tag_block

    subroutine collect_open_tag(lines, i, text)
        character(len=LINE_LEN), intent(in) :: lines(:)
        integer, intent(inout) :: i
        character(len=*), intent(out) :: text

        integer :: j

        text = trim(adjustl(lines(i)))
        if (index(text, '>') > 0) return

        j = i
        do while (j < size(lines))
            j = j + 1
            text = trim(text) // ' ' // trim(adjustl(lines(j)))
            if (index(lines(j), '>') > 0) exit
        end do
        i = j
    end subroutine collect_open_tag

    subroutine parse_first_real(text, value)
        character(len=*), intent(in) :: text
        real(dp), intent(out) :: value
        character(len=LINE_LEN) :: work
        work = text
        call commas_to_spaces(work)
        read(work, *) value
    end subroutine parse_first_real

    subroutine parse_real_list(text, values)
        character(len=*), intent(in) :: text
        real(dp), allocatable, intent(out) :: values(:)
        character(len=NAME_LEN), allocatable :: tokens(:)
        integer :: i

        call parse_name_list(text, tokens)
        allocate(values(size(tokens)))
        do i = 1, size(tokens)
            read(tokens(i), *) values(i)
        end do
    end subroutine parse_real_list

    subroutine parse_int_list(text, values)
        character(len=*), intent(in) :: text
        integer, allocatable, intent(out) :: values(:)
        character(len=NAME_LEN), allocatable :: tokens(:)
        integer :: i

        call parse_name_list(text, tokens)
        allocate(values(size(tokens)))
        do i = 1, size(tokens)
            read(tokens(i), *) values(i)
        end do
    end subroutine parse_int_list

    subroutine parse_name_list(text, tokens)
        character(len=*), intent(in) :: text
        character(len=NAME_LEN), allocatable, intent(out) :: tokens(:)

        character(len=LINE_LEN) :: work
        character(len=NAME_LEN) :: token
        character(len=NAME_LEN), allocatable :: tmp(:)
        integer :: i, n, start, finish

        work = text
        do i = 1, len_trim(work)
            if (work(i:i) == ',' .or. work(i:i) == '|' .or. work(i:i) == '(' .or. work(i:i) == ')' .or. &
                work(i:i) == '~' .or. work(i:i) == char(9) .or. work(i:i) == char(10) .or. &
                work(i:i) == char(13)) work(i:i) = ' '
        end do

        allocate(tokens(0))
        i = 1
        do while (i <= len_trim(work))
            do while (i <= len_trim(work) .and. work(i:i) == ' ')
                i = i + 1
            end do
            if (i > len_trim(work)) exit
            start = i
            do while (i <= len_trim(work) .and. work(i:i) /= ' ')
                i = i + 1
            end do
            finish = i - 1
            token = trim(adjustl(work(start:finish)))
            n = size(tokens)
            allocate(tmp(n+1))
            if (n > 0) tmp(1:n) = tokens
            tmp(n+1) = token
            call move_alloc(tmp, tokens)
        end do
    end subroutine parse_name_list

    subroutine commas_to_spaces(text)
        character(len=*), intent(inout) :: text
        integer :: i
        do i = 1, len_trim(text)
            if (text(i:i) == ',') text(i:i) = ' '
        end do
    end subroutine commas_to_spaces

    integer function axis_from_surface_type(type_text)
        character(len=*), intent(in) :: type_text
        character(len=:), allocatable :: x

        x = lowercase(trim(adjustl(type_text)))
        axis_from_surface_type = 0
        if (index(x, 'x-plane') > 0 .or. index(x, 'plane-x') > 0) axis_from_surface_type = 1
        if (index(x, 'y-plane') > 0 .or. index(x, 'plane-y') > 0) axis_from_surface_type = 2
        if (index(x, 'z-plane') > 0 .or. index(x, 'plane-z') > 0) axis_from_surface_type = 3
    end function axis_from_surface_type

    subroutine find_plane(planes, id, axis, value, found)
        type(plane_spec_t), intent(in) :: planes(:)
        character(len=*), intent(in) :: id
        integer, intent(out) :: axis
        real(dp), intent(out) :: value
        logical, intent(out) :: found
        integer :: i

        axis = 0
        value = 0.0_dp
        found = .false.
        do i = 1, size(planes)
            if (lowercase(trim(planes(i)%id)) == lowercase(trim(id))) then
                axis = planes(i)%axis
                value = planes(i)%value
                found = .true.
                return
            end if
        end do
    end subroutine find_plane

    subroutine find_cylinder_surface(cylinder_surfaces, id, surface, found)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        character(len=*), intent(in) :: id
        type(cylinder_surface_t), intent(out) :: surface
        logical, intent(out) :: found
        integer :: i

        surface = cylinder_surface_t()
        found = .false.
        do i = 1, size(cylinder_surfaces)
            if (lowercase(trim(cylinder_surfaces(i)%id)) == lowercase(trim(id))) then
                surface = cylinder_surfaces(i)
                found = .true.
                return
            end if
        end do
    end subroutine find_cylinder_surface

    subroutine find_sphere_surface(sphere_surfaces, id, surface, found)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        character(len=*), intent(in) :: id
        type(sphere_surface_t), intent(out) :: surface
        logical, intent(out) :: found
        integer :: i

        surface = sphere_surface_t()
        found = .false.
        do i = 1, size(sphere_surfaces)
            if (lowercase(trim(sphere_surfaces(i)%id)) == lowercase(trim(id))) then
                surface = sphere_surfaces(i)
                found = .true.
                return
            end if
        end do
    end subroutine find_sphere_surface

    integer function find_unit_index(units, id)
        type(unit_def_t), intent(in) :: units(:)
        character(len=*), intent(in) :: id
        integer :: i

        find_unit_index = 0
        do i = 1, size(units)
            if (lowercase(trim(units(i)%id)) == lowercase(trim(id))) then
                find_unit_index = i
                return
            end if
        end do
    end function find_unit_index

    integer function find_lattice_index(lattices, id)
        type(lattice_spec_t), intent(in) :: lattices(:)
        character(len=*), intent(in) :: id
        integer :: i

        find_lattice_index = 0
        do i = 1, size(lattices)
            if (lowercase(trim(lattices(i)%id)) == lowercase(trim(id))) then
                find_lattice_index = i
                return
            end if
        end do
    end function find_lattice_index

    integer function common_background_material(lattice, units)
        type(lattice_spec_t), intent(in) :: lattice
        type(unit_def_t), intent(in) :: units(:)
        integer :: ix, iy, iz, unit_idx, mat_id

        common_background_material = 0
        do iz = 1, lattice%nz
            do iy = 1, lattice%ny
                do ix = 1, lattice%nx
                    unit_idx = find_unit_index(units, lattice%token_names(ix, iy, iz))
                    if (unit_idx <= 0) then
                        common_background_material = 0
                        return
                    end if
                    if (.not. allocated(units(unit_idx)%material_ids)) cycle
                    if (.not. allocated(units(unit_idx)%radii)) cycle
                    if (size(units(unit_idx)%material_ids) <= size(units(unit_idx)%radii)) then
                        common_background_material = 0
                        return
                    end if
                    mat_id = units(unit_idx)%material_ids(size(units(unit_idx)%material_ids))
                    if (common_background_material == 0) then
                        common_background_material = mat_id
                    else if (common_background_material /= mat_id) then
                        common_background_material = 0
                        return
                    end if
                end do
            end do
        end do
    end function common_background_material

    subroutine universe_reference_center(universe_name, cells, planes, cylinder_surfaces, sphere_surfaces, center, ok)
        character(len=*), intent(in) :: universe_name
        type(cell_spec_t), intent(in) :: cells(:)
        type(plane_spec_t), intent(in) :: planes(:)
        type(cylinder_surface_t), intent(in) :: cylinder_surfaces(:)
        type(sphere_surface_t), intent(in) :: sphere_surfaces(:)
        real(dp), intent(out) :: center(3)
        logical, intent(out) :: ok

        type(region_spec_t) :: region
        integer :: i
        logical :: found, zone_ok

        center = [0.0_dp, 0.0_dp, 0.0_dp]
        found = .false.
        ok = .false.
        region = empty_region()

        do i = 1, size(cells)
            if (lowercase(trim(cells(i)%universe_name)) /= lowercase(trim(universe_name))) cycle
            call parse_zone_region(cells(i)%zone, planes, cylinder_surfaces, sphere_surfaces, [0.0_dp, 0.0_dp, 0.0_dp], &
                region, zone_ok)
            if (zone_ok .and. region%xmin_set .and. region%xmax_set .and. region%ymin_set .and. region%ymax_set) then
                center(1) = 0.5_dp * (region%xmin + region%xmax)
                center(2) = 0.5_dp * (region%ymin + region%ymax)
                if (region%zmin_set .and. region%zmax_set) then
                    center(3) = 0.5_dp * (region%zmin + region%zmax)
                else
                    center(3) = 0.0_dp
                end if
                ok = .true.
                return
            end if
            if (zone_ok .and. region%has_sphere .and. is_finite_bound(region%sph_rmax)) then
                center = [region%sph_xc, region%sph_yc, region%sph_zc]
                ok = .true.
                return
            end if
            found = .true.
        end do

        if (.not. found) ok = .false.
    end subroutine universe_reference_center

    subroutine ensure_name_index(names, name, index_out)
        character(len=NAME_LEN), allocatable, intent(inout) :: names(:)
        character(len=*), intent(in) :: name
        integer, intent(out) :: index_out
        character(len=NAME_LEN), allocatable :: tmp(:)
        integer :: i, n

        do i = 1, size(names)
            if (lowercase(trim(names(i))) == lowercase(trim(name))) then
                index_out = i
                return
            end if
        end do

        n = size(names)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = names
        tmp(n+1) = trim(adjustl(name))
        call move_alloc(tmp, names)
        index_out = n + 1
    end subroutine ensure_name_index

    subroutine map_name_id(names, values, next_id, name, id_out)
        character(len=NAME_LEN), allocatable, intent(inout) :: names(:)
        integer, allocatable, intent(inout) :: values(:)
        integer, intent(inout) :: next_id
        character(len=*), intent(in) :: name
        integer, intent(out) :: id_out

        character(len=NAME_LEN), allocatable :: name_tmp(:)
        integer, allocatable :: value_tmp(:)
        integer :: i, ios, numeric_id, n

        read(name, *, iostat=ios) numeric_id
        if (ios == 0) then
            id_out = numeric_id
            if (numeric_id >= next_id) next_id = numeric_id + 1
            return
        end if

        do i = 1, size(names)
            if (lowercase(trim(names(i))) == lowercase(trim(name))) then
                id_out = values(i)
                return
            end if
        end do

        n = size(names)
        allocate(name_tmp(n+1), value_tmp(n+1))
        if (n > 0) then
            name_tmp(1:n) = names
            value_tmp(1:n) = values
        end if
        name_tmp(n+1) = trim(adjustl(name))
        value_tmp(n+1) = next_id
        call move_alloc(name_tmp, names)
        call move_alloc(value_tmp, values)
        id_out = next_id
        next_id = next_id + 1
    end subroutine map_name_id

    subroutine append_plane(planes, plane)
        type(plane_spec_t), allocatable, intent(inout) :: planes(:)
        type(plane_spec_t), intent(in) :: plane
        type(plane_spec_t), allocatable :: tmp(:)
        integer :: n

        n = size(planes)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = planes
        tmp(n+1) = plane
        call move_alloc(tmp, planes)
    end subroutine append_plane

    subroutine append_cylinder_surface(cylinder_surfaces, surface)
        type(cylinder_surface_t), allocatable, intent(inout) :: cylinder_surfaces(:)
        type(cylinder_surface_t), intent(in) :: surface
        type(cylinder_surface_t), allocatable :: tmp(:)
        integer :: n

        n = size(cylinder_surfaces)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = cylinder_surfaces
        tmp(n+1) = surface
        call move_alloc(tmp, cylinder_surfaces)
    end subroutine append_cylinder_surface

    subroutine append_sphere_surface(sphere_surfaces, surface)
        type(sphere_surface_t), allocatable, intent(inout) :: sphere_surfaces(:)
        type(sphere_surface_t), intent(in) :: surface
        type(sphere_surface_t), allocatable :: tmp(:)
        integer :: n

        n = size(sphere_surfaces)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = sphere_surfaces
        tmp(n+1) = surface
        call move_alloc(tmp, sphere_surfaces)
    end subroutine append_sphere_surface

    subroutine append_unit(units, unit)
        type(unit_def_t), allocatable, intent(inout) :: units(:)
        type(unit_def_t), intent(in) :: unit
        type(unit_def_t), allocatable :: tmp(:)
        integer :: n

        n = size(units)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = units
        tmp(n+1)%id = unit%id
        tmp(n+1)%kind = unit%kind
        if (allocated(unit%material_ids)) then
            allocate(tmp(n+1)%material_ids(size(unit%material_ids)))
            tmp(n+1)%material_ids = unit%material_ids
        end if
        if (allocated(unit%radii)) then
            allocate(tmp(n+1)%radii(size(unit%radii)))
            tmp(n+1)%radii = unit%radii
        end if
        call move_alloc(tmp, units)
    end subroutine append_unit

    subroutine append_lattice(lattices, lattice)
        type(lattice_spec_t), allocatable, intent(inout) :: lattices(:)
        type(lattice_spec_t), intent(in) :: lattice
        type(lattice_spec_t), allocatable :: tmp(:)
        integer :: n

        n = size(lattices)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = lattices
        tmp(n+1)%id = lattice%id
        tmp(n+1)%nx = lattice%nx
        tmp(n+1)%ny = lattice%ny
        tmp(n+1)%nz = lattice%nz
        tmp(n+1)%pitch = lattice%pitch
        tmp(n+1)%lower_left = lattice%lower_left
        tmp(n+1)%background_material_id = lattice%background_material_id
        if (allocated(lattice%token_names)) then
            allocate(tmp(n+1)%token_names(lattice%nx, lattice%ny, lattice%nz))
            tmp(n+1)%token_names = lattice%token_names
        end if
        call move_alloc(tmp, lattices)
    end subroutine append_lattice

    subroutine append_cell(cells, cell)
        type(cell_spec_t), allocatable, intent(inout) :: cells(:)
        type(cell_spec_t), intent(in) :: cell
        type(cell_spec_t), allocatable :: tmp(:)
        integer :: n

        n = size(cells)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = cells
        tmp(n+1) = cell
        call move_alloc(tmp, cells)
    end subroutine append_cell

    subroutine append_box(model, box)
        type(geometry_model_t), intent(inout) :: model
        type(box_primitive_t), intent(in) :: box
        type(box_primitive_t), allocatable :: tmp(:)
        integer :: n

        n = size(model%boxes)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = model%boxes
        tmp(n+1) = box
        call move_alloc(tmp, model%boxes)
        call update_bbox_with_box(model, box)
        model%n_surfaces = size(model%boxes) + size(model%cylinders) + size(model%spheres)
    end subroutine append_box

    subroutine append_cylinder(model, cyl)
        type(geometry_model_t), intent(inout) :: model
        type(cylinder_primitive_t), intent(in) :: cyl
        type(cylinder_primitive_t), allocatable :: tmp(:)
        integer :: n

        n = size(model%cylinders)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = model%cylinders
        tmp(n+1) = cyl
        call move_alloc(tmp, model%cylinders)
        call update_bbox_with_cylinder(model, cyl)
        model%n_surfaces = size(model%boxes) + size(model%cylinders) + size(model%spheres)
    end subroutine append_cylinder

    subroutine append_sphere(model, sph)
        type(geometry_model_t), intent(inout) :: model
        type(sphere_primitive_t), intent(in) :: sph
        type(sphere_primitive_t), allocatable :: tmp(:)
        integer :: n

        n = size(model%spheres)
        allocate(tmp(n+1))
        if (n > 0) tmp(1:n) = model%spheres
        tmp(n+1) = sph
        call move_alloc(tmp, model%spheres)
        call update_bbox_with_sphere(model, sph)
        model%n_surfaces = size(model%boxes) + size(model%cylinders) + size(model%spheres)
    end subroutine append_sphere

    subroutine reset_model(model)
        type(geometry_model_t), intent(out) :: model
        allocate(model%boxes(0), model%cylinders(0), model%spheres(0))
        model%n_cells = 0
        model%n_surfaces = 0
        model%n_materials = 0
        model%bbox = [ REGION_BIG, -REGION_BIG, REGION_BIG, -REGION_BIG, REGION_BIG, -REGION_BIG ]
    end subroutine reset_model

    subroutine update_bbox_with_box(model, box)
        type(geometry_model_t), intent(inout) :: model
        type(box_primitive_t), intent(in) :: box
        model%bbox(1) = min(model%bbox(1), box%xmin)
        model%bbox(2) = max(model%bbox(2), box%xmax)
        model%bbox(3) = min(model%bbox(3), box%ymin)
        model%bbox(4) = max(model%bbox(4), box%ymax)
        model%bbox(5) = min(model%bbox(5), box%zmin)
        model%bbox(6) = max(model%bbox(6), box%zmax)
    end subroutine update_bbox_with_box

    subroutine update_bbox_with_cylinder(model, cyl)
        type(geometry_model_t), intent(inout) :: model
        type(cylinder_primitive_t), intent(in) :: cyl
        model%bbox(1) = min(model%bbox(1), cyl%xc - cyl%rmax)
        model%bbox(2) = max(model%bbox(2), cyl%xc + cyl%rmax)
        model%bbox(3) = min(model%bbox(3), cyl%yc - cyl%rmax)
        model%bbox(4) = max(model%bbox(4), cyl%yc + cyl%rmax)
        model%bbox(5) = min(model%bbox(5), cyl%zmin)
        model%bbox(6) = max(model%bbox(6), cyl%zmax)
    end subroutine update_bbox_with_cylinder

    subroutine update_bbox_with_sphere(model, sph)
        type(geometry_model_t), intent(inout) :: model
        type(sphere_primitive_t), intent(in) :: sph
        model%bbox(1) = min(model%bbox(1), sph%xc - sph%rmax)
        model%bbox(2) = max(model%bbox(2), sph%xc + sph%rmax)
        model%bbox(3) = min(model%bbox(3), sph%yc - sph%rmax)
        model%bbox(4) = max(model%bbox(4), sph%yc + sph%rmax)
        model%bbox(5) = min(model%bbox(5), sph%zc - sph%rmax)
        model%bbox(6) = max(model%bbox(6), sph%zc + sph%rmax)
    end subroutine update_bbox_with_sphere

    logical function point_in_box(box, x, y, z)
        type(box_primitive_t), intent(in) :: box
        real(dp), intent(in) :: x, y, z
        point_in_box = (x >= box%xmin .and. x <= box%xmax .and. y >= box%ymin .and. y <= box%ymax .and. &
                        z >= box%zmin .and. z <= box%zmax)
    end function point_in_box

    logical function starts_with(text, prefix)
        character(len=*), intent(in) :: text, prefix
        starts_with = index(trim(adjustl(text)), trim(prefix)) == 1
    end function starts_with

    logical function is_xml_file(filename)
        character(len=*), intent(in) :: filename
        character(len=:), allocatable :: x
        x = lowercase(trim(adjustl(filename)))
        is_xml_file = len_trim(x) >= 4 .and. x(len_trim(x)-3:len_trim(x)) == '.xml'
    end function is_xml_file

    pure logical function is_finite_bound(value)
        real(dp), intent(in) :: value
        is_finite_bound = abs(value) < REGION_BIG * 0.5_dp
    end function is_finite_bound

    pure logical function region_box_complete(region)
        type(region_spec_t), intent(in) :: region
        region_box_complete = region%xmin_set .and. region%xmax_set .and. region%ymin_set .and. &
                              region%ymax_set .and. region%zmin_set .and. region%zmax_set .and. &
                              region%xmax > region%xmin .and. region%ymax > region%ymin .and. region%zmax > region%zmin
    end function region_box_complete

    pure logical function region_box_has_z(region)
        type(region_spec_t), intent(in) :: region
        region_box_has_z = region%zmin_set .and. region%zmax_set .and. region%zmax > region%zmin
    end function region_box_has_z

    pure logical function same_xy_center(x1, y1, x2, y2)
        real(dp), intent(in) :: x1, y1, x2, y2
        same_xy_center = abs(x1 - x2) < 1.0e-9_dp .and. abs(y1 - y2) < 1.0e-9_dp
    end function same_xy_center

    pure logical function same_xyz_center(x1, y1, z1, x2, y2, z2)
        real(dp), intent(in) :: x1, y1, z1, x2, y2, z2
        same_xyz_center = abs(x1 - x2) < 1.0e-9_dp .and. abs(y1 - y2) < 1.0e-9_dp .and. abs(z1 - z2) < 1.0e-9_dp
    end function same_xyz_center

    pure function empty_region() result(region)
        type(region_spec_t) :: region
        region = region_spec_t()
    end function empty_region
end module vis3d_host_types
