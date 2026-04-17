
module vis3d_input_common
    use vis3d_kinds, only: dp
    use vis3d_constants, only: uppercase, mode_from_string, format_from_string
    use vis3d_types, only: vis3d_config_t
    implicit none
    private
    public :: vis3d_read_config
    public :: vis3d_extract_kv

contains
    subroutine vis3d_read_config(lines, syntax, cfg, ierr)
        character(len=*), intent(in) :: lines(:)
        character(len=*), intent(in) :: syntax
        type(vis3d_config_t), intent(out) :: cfg
        integer, intent(out) :: ierr

        integer :: i
        character(len=256) :: key, val
        ierr = 0
        cfg = vis3d_config_t()
        cfg%enabled = .true.

        do i = 1, size(lines)
            call vis3d_extract_kv(lines(i), key, val)
            if (len_trim(key) == 0) cycle
            select case (trim(uppercase(key)))
            case ('MODE')
                cfg%mode = mode_from_string(val)
            case ('FORMAT')
                cfg%format = format_from_string(val)
            case ('OUTPUT')
                cfg%output = trim(adjustl(val))
            case ('COLORBY')
                cfg%color_by = trim(adjustl(val))
            case ('AUTO_BBOX')
                cfg%auto_bbox = truthy(val)
            case ('MARGIN')
                read(val, *, iostat=ierr) cfg%bbox_margin
                if (ierr /= 0) return
                ierr = 0
            case ('DIM')
                call parse_dim(val, cfg%grid%nx, cfg%grid%ny, cfg%grid%nz, ierr)
                if (ierr /= 0) return
            case ('ORIGIN')
                call parse_vec3(val, cfg%bbox%xmin, cfg%bbox%ymin, cfg%bbox%zmin, ierr)
                if (ierr /= 0) return
            case ('WIDTH')
                call parse_width(val, cfg, ierr)
                if (ierr /= 0) return
            case ('FIELDS')
                call parse_fields(val, cfg)
            case default
                ! ignore unknown keys in skeleton version
            end select
        end do
        call cfg%normalize()
    end subroutine vis3d_read_config

    subroutine vis3d_extract_kv(line, key, val)
        character(len=*), intent(in) :: line
        character(len=*), intent(out) :: key, val
        integer :: p
        key = ''
        val = ''
        p = index(line, '=')
        if (p <= 0) return
        key = trim(adjustl(line(:p-1)))
        val = trim(adjustl(line(p+1:)))
    end subroutine vis3d_extract_kv

    logical function truthy(s)
        character(len=*), intent(in) :: s
        character(len=:), allocatable :: x
        x = uppercase(trim(adjustl(s)))
        truthy = (x == 'YES' .or. x == 'TRUE' .or. x == '1')
    end function truthy

    subroutine parse_dim(s, a, b, c, ierr)
        character(len=*), intent(in) :: s
        integer, intent(out) :: a, b, c
        integer, intent(out) :: ierr
        character(len=256) :: t
        t = s
        call commas_to_spaces(t)
        read(t, *, iostat=ierr) a, b, c
    end subroutine parse_dim

    subroutine parse_vec3(s, x, y, z, ierr)
        character(len=*), intent(in) :: s
        real(dp), intent(out) :: x, y, z
        integer, intent(out) :: ierr
        character(len=256) :: t
        t = s
        call commas_to_spaces(t)
        read(t, *, iostat=ierr) x, y, z
    end subroutine parse_vec3

    subroutine parse_width(s, cfg, ierr)
        character(len=*), intent(in) :: s
        type(vis3d_config_t), intent(inout) :: cfg
        integer, intent(out) :: ierr
        real(dp) :: wx, wy, wz
        call parse_vec3(s, wx, wy, wz, ierr)
        if (ierr /= 0) return
        cfg%bbox%xmax = cfg%bbox%xmin + wx
        cfg%bbox%ymax = cfg%bbox%ymin + wy
        cfg%bbox%zmax = cfg%bbox%zmin + wz
    end subroutine parse_width

    subroutine parse_fields(s, cfg)
        character(len=*), intent(in) :: s
        type(vis3d_config_t), intent(inout) :: cfg
        character(len=512) :: t
        character(len=64) :: token
        integer :: p
        t = trim(adjustl(s))
        cfg%fields%cell_id = .false.
        cfg%fields%material_id = .false.
        cfg%fields%universe_id = .false.
        cfg%fields%lattice_id = .false.
        cfg%fields%instance_id = .false.
        cfg%fields%surface_id = .false.
        cfg%fields%density = .false.
        cfg%fields%temperature = .false.
        cfg%fields%importance = .false.
        do
            p = index(t, ',')
            if (p == 0) then
                token = trim(adjustl(t))
                call set_field(token, cfg)
                exit
            else
                token = trim(adjustl(t(:p-1)))
                call set_field(token, cfg)
                t = trim(adjustl(t(p+1:)))
            end if
        end do
    end subroutine parse_fields

    subroutine set_field(token, cfg)
        character(len=*), intent(in) :: token
        type(vis3d_config_t), intent(inout) :: cfg
        select case (trim(uppercase(token)))
        case ('CELL_ID')
            cfg%fields%cell_id = .true.
        case ('MATERIAL_ID')
            cfg%fields%material_id = .true.
        case ('UNIVERSE_ID')
            cfg%fields%universe_id = .true.
        case ('LATTICE_ID')
            cfg%fields%lattice_id = .true.
        case ('INSTANCE_ID')
            cfg%fields%instance_id = .true.
        case ('SURFACE_ID')
            cfg%fields%surface_id = .true.
        case ('DENSITY')
            cfg%fields%density = .true.
        case ('TEMPERATURE')
            cfg%fields%temperature = .true.
        case ('IMPORTANCE')
            cfg%fields%importance = .true.
        end select
    end subroutine set_field

    subroutine commas_to_spaces(s)
        character(len=*), intent(inout) :: s
        integer :: i
        do i = 1, len_trim(s)
            if (s(i:i) == ',') s(i:i) = ' '
        end do
    end subroutine commas_to_spaces
end module vis3d_input_common
