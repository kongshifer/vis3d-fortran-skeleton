
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
        call xml_write_line(unit, '      <PointData/>')
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
    end subroutine write_vti
end module vis3d_writer_vti
