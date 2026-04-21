
module vis3d_writer_vti
    use vis3d_writer_xml, only: xml_open_file, xml_close_file, xml_write_line
    use vis3d_types, only: field_flags_t, voxel_dataset_t
    implicit none
    private
    public :: write_vti

contains
    subroutine write_vti(filename, vox, fields, ierr)
        character(len=*), intent(in) :: filename
        type(voxel_dataset_t), intent(in) :: vox
        type(field_flags_t), intent(in) :: fields
        integer, intent(out) :: ierr
        integer :: unit
        character(len=32) :: scalars_name
        character(len=128) :: line

        ierr = 0
        call xml_open_file(filename, unit, ierr)
        if (ierr /= 0) return

        call xml_write_line(unit, '<?xml version="1.0"?>')
        call xml_write_line(unit, '<VTKFile type="ImageData" version="0.1" byte_order="LittleEndian">')
        write(unit,'(A,I0,A,I0,A,I0,A,F0.6,1X,F0.6,1X,F0.6,A,F0.6,1X,F0.6,1X,F0.6,A)') &
            '  <ImageData WholeExtent="0 ', vox%grid%nx, ' 0 ', vox%grid%ny, ' 0 ', vox%grid%nz, &
            '" Origin="', vox%bbox%xmin, vox%bbox%ymin, vox%bbox%zmin, &
            '" Spacing="', vox%grid%dx, vox%grid%dy, vox%grid%dz, '">'
        write(unit,'(A,I0,A,I0,A,I0,A)') '    <Piece Extent="0 ', vox%grid%nx, ' 0 ', vox%grid%ny, ' 0 ', vox%grid%nz, '">'

        scalars_name = first_cell_scalar(fields)
        if (len_trim(scalars_name) > 0) then
            write(line,'(A,A,A)') '      <CellData Scalars="', trim(scalars_name), '">'
            call xml_write_line(unit, trim(line))
        else
            call xml_write_line(unit, '      <CellData>')
        end if

        if (fields%cell_id) call write_int_array_3d(unit, 'cell_id', vox%cell_id)
        if (fields%material_id) call write_int_array_3d(unit, 'material_id', vox%material_id)
        if (fields%universe_id) call write_int_array_3d(unit, 'universe_id', vox%universe_id)
        if (fields%lattice_id) call write_int_array_3d(unit, 'lattice_id', vox%lattice_id)
        if (fields%instance_id) call write_int_array_3d(unit, 'instance_id', vox%instance_id)
        call xml_write_line(unit, '      </CellData>')
        if (len_trim(scalars_name) > 0) then
            write(line,'(A,A,A)') '      <PointData Scalars="', trim(scalars_name), '">'
            call xml_write_line(unit, trim(line))
            select case (trim(scalars_name))
            case ('cell_id')
                call write_int_point_array_3d(unit, 'cell_id', vox%cell_id)
            case ('material_id')
                call write_int_point_array_3d(unit, 'material_id', vox%material_id)
            case ('universe_id')
                call write_int_point_array_3d(unit, 'universe_id', vox%universe_id)
            case ('lattice_id')
                call write_int_point_array_3d(unit, 'lattice_id', vox%lattice_id)
            case ('instance_id')
                call write_int_point_array_3d(unit, 'instance_id', vox%instance_id)
            end select
            call xml_write_line(unit, '      </PointData>')
        else
            call xml_write_line(unit, '      <PointData/>')
        end if
        call xml_write_line(unit, '    </Piece>')
        call xml_write_line(unit, '  </ImageData>')
        call xml_write_line(unit, '</VTKFile>')
        call xml_close_file(unit)
    contains
        pure function first_cell_scalar(fields) result(name)
            type(field_flags_t), intent(in) :: fields
            character(len=32) :: name
            name = ''
            if (fields%cell_id) then
                name = 'cell_id'
            else if (fields%material_id) then
                name = 'material_id'
            else if (fields%universe_id) then
                name = 'universe_id'
            else if (fields%lattice_id) then
                name = 'lattice_id'
            else if (fields%instance_id) then
                name = 'instance_id'
            end if
        end function first_cell_scalar

        subroutine write_int_array_3d(unit, name, arr)
            integer, intent(in) :: unit
            character(len=*), intent(in) :: name
            integer, intent(in) :: arr(:,:,:)
            integer :: i, j, k
            write(unit,'(A,A,A)') '        <DataArray type="Int32" Name="', trim(name), '" format="ascii">'
            do k = 1, size(arr,3)
                do j = 1, size(arr,2)
                    write(unit,'(*(I0,1X))') (arr(i,j,k), i=1,size(arr,1))
                end do
            end do
            call xml_write_line(unit, '        </DataArray>')
        end subroutine write_int_array_3d

        subroutine write_int_point_array_3d(unit, name, arr)
            integer, intent(in) :: unit
            character(len=*), intent(in) :: name
            integer, intent(in) :: arr(:,:,:)
            integer :: i, j, k
            integer :: value

            write(unit,'(A,A,A)') '        <DataArray type="Int32" Name="', trim(name), '" format="ascii">'
            do k = 1, size(arr,3) + 1
                do j = 1, size(arr,2) + 1
                    do i = 1, size(arr,1) + 1
                        call majority_point_value(arr, i, j, k, value)
                        write(unit,'(I0,1X)', advance='no') value
                    end do
                    write(unit,*)
                end do
            end do
            call xml_write_line(unit, '        </DataArray>')
        end subroutine write_int_point_array_3d

        subroutine majority_point_value(arr, ip, jp, kp, value)
            integer, intent(in) :: arr(:,:,:)
            integer, intent(in) :: ip, jp, kp
            integer, intent(out) :: value
            integer :: values(8), counts(8)
            integer :: i, j, k, nvals, idx

            nvals = 0
            values = 0
            counts = 0
            do k = max(1, kp - 1), min(size(arr,3), kp)
                do j = max(1, jp - 1), min(size(arr,2), jp)
                    do i = max(1, ip - 1), min(size(arr,1), ip)
                        call accumulate_value(arr(i,j,k), values, counts, nvals)
                    end do
                end do
            end do

            value = -1
            if (nvals <= 0) return
            value = values(1)
            idx = 1
            do i = 2, nvals
                if (counts(i) > counts(idx)) then
                    idx = i
                    value = values(i)
                else if (counts(i) == counts(idx)) then
                    if (value < 0 .and. values(i) >= 0) then
                        idx = i
                        value = values(i)
                    end if
                end if
            end do
        end subroutine majority_point_value

        subroutine accumulate_value(candidate, values, counts, nvals)
            integer, intent(in) :: candidate
            integer, intent(inout) :: values(8), counts(8)
            integer, intent(inout) :: nvals
            integer :: i

            do i = 1, nvals
                if (values(i) == candidate) then
                    counts(i) = counts(i) + 1
                    return
                end if
            end do

            nvals = nvals + 1
            values(nvals) = candidate
            counts(nvals) = 1
        end subroutine accumulate_value
    end subroutine write_vti
end module vis3d_writer_vti
