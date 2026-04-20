
module vis3d_input_mcx
    use vis3d_constants, only: VIS3D_TAG, VIS3D_MODE_SURFACE, VIS3D_FMT_VTP
    use vis3d_types, only: vis3d_config_t
    use vis3d_input_common, only: vis3d_read_config
    implicit none
    private
    public :: vis3d_read_config_mcx

contains
    subroutine vis3d_read_config_mcx(filename, cfg, ierr)
        character(len=*), intent(in) :: filename
        type(vis3d_config_t), intent(out) :: cfg
        integer, intent(out) :: ierr

        character(len=512), allocatable :: lines(:)
        integer :: unit, ios
        character(len=512) :: line, payload
        ierr = 0

        allocate(lines(0))
        open(newunit=unit, file=trim(filename), status='old', action='read', iostat=ios)
        if (ios /= 0) then
            ierr = ios
            cfg = vis3d_config_t()
            return
        end if

        do
            read(unit, '(A)', iostat=ios) line
            if (ios /= 0) exit
            if (is_vis3d_comment_mcx(line, payload)) call append_line(lines, payload)
        end do
        close(unit)

        if (size(lines) == 0) then
            cfg = vis3d_config_t()
            cfg%enabled = .true.
            cfg%mode = VIS3D_MODE_SURFACE
            cfg%format = VIS3D_FMT_VTP
            cfg%output = default_output_path(filename, 'vtp')
            cfg%fields%surface_id = .true.
            cfg%fields%lattice_id = .true.
            cfg%surface_quality = 2
            call cfg%normalize()
            return
        end if

        call vis3d_read_config(lines, 'mcx', cfg, ierr)
    contains
        function default_output_path(filename, ext) result(out)
            character(len=*), intent(in) :: filename, ext
            character(len=256) :: out
            integer :: i, last_sep, last_dot

            out = trim(filename)
            last_sep = 0
            last_dot = 0
            do i = 1, len_trim(filename)
                if (filename(i:i) == '\' .or. filename(i:i) == '/') last_sep = i
                if (filename(i:i) == '.') last_dot = i
            end do

            if (last_dot > last_sep) then
                out = trim(filename(:last_dot-1)) // '.' // trim(ext)
            else
                out = trim(filename) // '.' // trim(ext)
            end if
        end function default_output_path

        logical function is_vis3d_comment_mcx(line, payload)
            character(len=*), intent(in) :: line
            character(len=*), intent(out) :: payload
            character(len=512) :: t
            payload = ''
            t = adjustl(line)
            if (len_trim(t) < 1) then
                is_vis3d_comment_mcx = .false.; return
            end if
            if (t(1:1) /= '#' .and. t(1:1) /= '!') then
                is_vis3d_comment_mcx = .false.; return
            end if
            t = adjustl(t(2:))
            if (index(t, VIS3D_TAG) /= 1) then
                is_vis3d_comment_mcx = .false.; return
            end if
            payload = trim(adjustl(t(len(VIS3D_TAG)+1:)))
            if (trim(payload) == 'BEGIN' .or. trim(payload) == 'END') then
                is_vis3d_comment_mcx = .false.; return
            end if
            is_vis3d_comment_mcx = .true.
        end function is_vis3d_comment_mcx

        subroutine append_line(lines, text)
            character(len=512), allocatable, intent(inout) :: lines(:)
            character(len=*), intent(in) :: text
            character(len=512), allocatable :: tmp(:)
            integer :: n
            n = size(lines)
            allocate(tmp(n+1))
            if (n > 0) tmp(1:n) = lines
            tmp(n+1) = trim(text)
            call move_alloc(tmp, lines)
        end subroutine append_line
    end subroutine vis3d_read_config_mcx
end module vis3d_input_mcx
