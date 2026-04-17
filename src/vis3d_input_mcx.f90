
module vis3d_input_mcx
    use vis3d_constants, only: VIS3D_TAG
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
            cfg%enabled = .false.
            return
        end if

        call vis3d_read_config(lines, 'mcx', cfg, ierr)
    contains
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
