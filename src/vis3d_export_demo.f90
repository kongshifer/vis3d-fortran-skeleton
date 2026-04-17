
program vis3d_export_demo
    use vis3d_driver, only: vis3d_run
    implicit none
    integer :: ierr
    character(len=256) :: input_file, syntax

    if (command_argument_count() < 1) then
        write(*,'(A)') 'Usage: vis3d_export_demo <input_file> [auto|mcx|mcnp]'
        stop 1
    end if

    call get_command_argument(1, input_file)
    syntax = 'auto'
    if (command_argument_count() >= 2) call get_command_argument(2, syntax)

    call vis3d_run(trim(input_file), trim(syntax), ierr)
    if (ierr /= 0) then
        write(*,'(A,I0)') 'VIS3D export failed, ierr = ', ierr
        stop 2
    end if
    write(*,'(A)') 'VIS3D export finished.'
end program vis3d_export_demo
