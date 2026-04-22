
program vis3d_export_demo
    use vis3d_driver, only: vis3d_run
    implicit none
    integer :: ierr
    integer :: i, argc, positional_count
    character(len=256) :: input_file, syntax, output_dir, arg

    input_file = ''
    syntax = 'auto'
    output_dir = ''
    positional_count = 0
    argc = command_argument_count()

    if (argc < 1) then
        call print_usage()
        stop 1
    end if

    i = 1
    do while (i <= argc)
        call get_command_argument(i, arg)
        select case (trim(arg))
        case ('--help', '-h', '/?')
            call print_usage()
            stop 0
        case ('--syntax', '-s')
            if (i >= argc) then
                write(*,'(A)') 'VIS3D error: missing value after --syntax.'
                stop 1
            end if
            i = i + 1
            call get_command_argument(i, syntax)
        case ('--output-dir', '-o')
            if (i >= argc) then
                write(*,'(A)') 'VIS3D error: missing value after --output-dir.'
                stop 1
            end if
            i = i + 1
            call get_command_argument(i, output_dir)
        case default
            if (len_trim(arg) >= 2 .and. arg(1:2) == '--') then
                write(*,'(A,A)') 'VIS3D error: unsupported option ', trim(arg)
                stop 1
            end if
            positional_count = positional_count + 1
            select case (positional_count)
            case (1)
                input_file = arg
            case (2)
                syntax = arg
            case (3)
                output_dir = arg
            case default
                write(*,'(A)') 'VIS3D error: too many positional arguments.'
                call print_usage()
                stop 1
            end select
        end select
        i = i + 1
    end do

    if (len_trim(input_file) == 0) then
        call print_usage()
        stop 1
    end if

    if (len_trim(output_dir) > 0) then
        call vis3d_run(trim(input_file), trim(syntax), ierr, trim(output_dir))
    else
        call vis3d_run(trim(input_file), trim(syntax), ierr)
    end if
    if (ierr /= 0) then
        write(*,'(A,I0)') 'VIS3D export failed, ierr = ', ierr
        stop 2
    end if
    write(*,'(A)') 'VIS3D export finished.'
contains
    subroutine print_usage()
        write(*,'(A)') 'Usage: vis3d_export_demo <input_file> [auto|mcx|mcnp] [output_dir]'
        write(*,'(A)') '   or: vis3d_export_demo --syntax <auto|mcx|mcnp> --output-dir <dir> <input_file>'
    end subroutine print_usage
end program vis3d_export_demo
