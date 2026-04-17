
module vis3d_writer_vtu
    use vis3d_writer_xml, only: xml_open_file, xml_close_file, xml_write_line
    use vis3d_types, only: field_flags_t, poly_surface_dataset_t
    implicit none
    private
    public :: write_vtu

contains
    subroutine write_vtu(filename, surf, fields, ierr)
        character(len=*), intent(in) :: filename
        type(poly_surface_dataset_t), intent(in) :: surf
        type(field_flags_t), intent(in) :: fields
        integer, intent(out) :: ierr
        integer :: unit, i
        character(len=32) :: scalars_name
        character(len=128) :: line

        call xml_open_file(filename, unit, ierr)
        if (ierr /= 0) return

        call xml_write_line(unit, '<?xml version="1.0"?>')
        call xml_write_line(unit, '<VTKFile type="UnstructuredGrid" version="0.1" byte_order="LittleEndian">')
        write(unit,'(A,I0,A,I0,A)') '  <UnstructuredGrid><Piece NumberOfPoints="', surf%n_points, '" NumberOfCells="', surf%n_tris, '">'

        scalars_name = first_cell_scalar(fields)
        if (len_trim(scalars_name) > 0) then
            write(line,'(A,A,A)') '    <CellData Scalars="', trim(scalars_name), '">'
            call xml_write_line(unit, trim(line))
        else
            call xml_write_line(unit, '    <CellData>')
        end if
        if (fields%cell_id) call write_int_array_1d(unit, 'cell_id', surf%cell_id(1:surf%n_tris))
        if (fields%material_id) call write_int_array_1d(unit, 'material_id', surf%material_id(1:surf%n_tris))
        if (fields%surface_id) call write_int_array_1d(unit, 'surface_id', surf%surface_id(1:surf%n_tris))
        if (fields%universe_id) call write_int_array_1d(unit, 'universe_id', surf%universe_id(1:surf%n_tris))
        call xml_write_line(unit, '    </CellData>')

        call xml_write_line(unit, '    <Points>')
        call xml_write_line(unit, '      <DataArray type="Float64" NumberOfComponents="3" format="ascii">')
        do i = 1, surf%n_points
            write(unit,'(3(ES24.16,1X))') surf%points(1,i), surf%points(2,i), surf%points(3,i)
        end do
        call xml_write_line(unit, '      </DataArray>')
        call xml_write_line(unit, '    </Points>')

        call xml_write_line(unit, '    <Cells>')
        call xml_write_line(unit, '      <DataArray type="Int32" Name="connectivity" format="ascii">')
        do i = 1, surf%n_tris
            write(unit,'(3(I0,1X))') surf%conn(1,i), surf%conn(2,i), surf%conn(3,i)
        end do
        call xml_write_line(unit, '      </DataArray>')
        call xml_write_line(unit, '      <DataArray type="Int32" Name="offsets" format="ascii">')
        do i = 1, surf%n_tris
            write(unit,'(I0)') 3 * i
        end do
        call xml_write_line(unit, '      </DataArray>')
        call xml_write_line(unit, '      <DataArray type="UInt8" Name="types" format="ascii">')
        do i = 1, surf%n_tris
            write(unit,'(I0)') 5
        end do
        call xml_write_line(unit, '      </DataArray>')
        call xml_write_line(unit, '    </Cells>')

        call xml_write_line(unit, '  </Piece></UnstructuredGrid>')
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
            else if (fields%surface_id) then
                name = 'surface_id'
            else if (fields%universe_id) then
                name = 'universe_id'
            end if
        end function first_cell_scalar

        subroutine write_int_array_1d(unit, name, arr)
            integer, intent(in) :: unit
            character(len=*), intent(in) :: name
            integer, intent(in) :: arr(:)
            write(unit,'(A,A,A)') '      <DataArray type="Int32" Name="', trim(name), '" format="ascii">'
            write(unit,'(*(I0,1X))') arr
            call xml_write_line(unit, '      </DataArray>')
        end subroutine write_int_array_1d
    end subroutine write_vtu
end module vis3d_writer_vtu
