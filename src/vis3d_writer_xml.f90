
module vis3d_writer_xml
    implicit none
    private
    public :: xml_open_file, xml_close_file, xml_write_line

contains
    subroutine xml_open_file(filename, unit, ierr)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: unit
        integer, intent(out) :: ierr
        character(len=512) :: iomsg

        iomsg = ''
        open(newunit=unit, file=trim(filename), status='replace', action='write', iostat=ierr, iomsg=iomsg)
        if (ierr /= 0) then
            write(*,'(A)') 'VIS3D output open failed: ' // trim(filename)
            if (len_trim(iomsg) > 0) write(*,'(A)') trim(iomsg)
        end if
    end subroutine xml_open_file

    subroutine xml_close_file(unit)
        integer, intent(in) :: unit
        close(unit)
    end subroutine xml_close_file

    subroutine xml_write_line(unit, line)
        integer, intent(in) :: unit
        character(len=*), intent(in) :: line
        write(unit, '(A)') trim(line)
    end subroutine xml_write_line
end module vis3d_writer_xml
