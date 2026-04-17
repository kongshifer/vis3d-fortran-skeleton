
module vis3d_constants
    implicit none
    private

    integer, parameter, public :: VIS3D_MODE_AUTO    = 0
    integer, parameter, public :: VIS3D_MODE_VOXEL   = 1
    integer, parameter, public :: VIS3D_MODE_SURFACE = 2

    integer, parameter, public :: VIS3D_FMT_UNKNOWN = 0
    integer, parameter, public :: VIS3D_FMT_VTI     = 1
    integer, parameter, public :: VIS3D_FMT_VTP     = 2
    integer, parameter, public :: VIS3D_FMT_VTU     = 3

    integer, parameter, public :: VIS3D_SYNTAX_AUTO = 0
    integer, parameter, public :: VIS3D_SYNTAX_MCX  = 1
    integer, parameter, public :: VIS3D_SYNTAX_MCNP = 2

    character(len=*), parameter, public :: VIS3D_TAG = '@VIS3D'

    public :: lowercase, uppercase, trim_spaces
    public :: mode_from_string, format_from_string, syntax_from_string
contains
    pure function lowercase(s) result(out)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: out
        integer :: i, c
        out = s
        do i = 1, len(s)
            c = iachar(out(i:i))
            if (c >= iachar('A') .and. c <= iachar('Z')) out(i:i) = achar(c + 32)
        end do
    end function lowercase

    pure function uppercase(s) result(out)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: out
        integer :: i, c
        out = s
        do i = 1, len(s)
            c = iachar(out(i:i))
            if (c >= iachar('a') .and. c <= iachar('z')) out(i:i) = achar(c - 32)
        end do
    end function uppercase

    pure function trim_spaces(s) result(out)
        character(len=*), intent(in) :: s
        character(len=len_trim(adjustl(s))) :: out
        out = trim(adjustl(s))
    end function trim_spaces

    pure function mode_from_string(s) result(mode)
        character(len=*), intent(in) :: s
        integer :: mode
        character(len=:), allocatable :: x
        x = lowercase(trim(adjustl(s)))
        select case (x)
        case ('voxel')
            mode = VIS3D_MODE_VOXEL
        case ('surface')
            mode = VIS3D_MODE_SURFACE
        case default
            mode = VIS3D_MODE_AUTO
        end select
    end function mode_from_string

    pure function format_from_string(s) result(fmt)
        character(len=*), intent(in) :: s
        integer :: fmt
        character(len=:), allocatable :: x
        x = lowercase(trim(adjustl(s)))
        select case (x)
        case ('vti')
            fmt = VIS3D_FMT_VTI
        case ('vtp')
            fmt = VIS3D_FMT_VTP
        case ('vtu')
            fmt = VIS3D_FMT_VTU
        case default
            fmt = VIS3D_FMT_UNKNOWN
        end select
    end function format_from_string

    pure function syntax_from_string(s) result(kind_)
        character(len=*), intent(in) :: s
        integer :: kind_
        character(len=:), allocatable :: x
        x = lowercase(trim(adjustl(s)))
        select case (x)
        case ('mcx')
            kind_ = VIS3D_SYNTAX_MCX
        case ('mcnp')
            kind_ = VIS3D_SYNTAX_MCNP
        case default
            kind_ = VIS3D_SYNTAX_AUTO
        end select
    end function syntax_from_string
end module vis3d_constants
