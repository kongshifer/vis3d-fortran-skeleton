
module vis3d_driver
    use vis3d_constants, only: VIS3D_MODE_AUTO, VIS3D_MODE_VOXEL, VIS3D_MODE_SURFACE, &
                               VIS3D_FMT_UNKNOWN, VIS3D_FMT_VTI, VIS3D_FMT_VTP, VIS3D_FMT_VTU, &
                               VIS3D_SYNTAX_AUTO, syntax_from_string, VIS3D_SYNTAX_MCX, VIS3D_SYNTAX_MCNP
    use vis3d_types, only: aabb_t, vis3d_config_t, vis3d_geom_context_t, voxel_dataset_t, poly_surface_dataset_t
    use vis3d_input_mcx, only: vis3d_read_config_mcx
    use vis3d_input_mcnp, only: vis3d_read_config_mcnp
    use vis3d_host_types, only: geometry_model_t, geometry_build_from_input
    use vis3d_geom_context, only: vis3d_build_geom_context
    use vis3d_bbox, only: vis3d_resolve_bbox
    use vis3d_sampler_voxel, only: vis3d_sample_voxel
    use vis3d_surface_patch, only: vis3d_build_surface
    use vis3d_writer_vti, only: write_vti
    use vis3d_writer_vtp, only: write_vtp
    use vis3d_writer_vtu, only: write_vtu
    implicit none
    private
    public :: vis3d_run

contains
    subroutine vis3d_run(input_file, syntax_hint, ierr, output_dir_override)
        character(len=*), intent(in) :: input_file
        character(len=*), intent(in) :: syntax_hint
        integer, intent(out) :: ierr
        character(len=*), intent(in), optional :: output_dir_override

        integer :: syntax_kind, export_mode, export_format
        type(vis3d_config_t) :: cfg
        type(geometry_model_t) :: model
        type(vis3d_geom_context_t) :: ctx
        type(voxel_dataset_t) :: vox
        type(poly_surface_dataset_t) :: surf
        type(aabb_t) :: resolved_bbox
        character(len=256) :: message

        ierr = 0
        syntax_kind = syntax_from_string(syntax_hint)
        if (syntax_kind == VIS3D_SYNTAX_AUTO) syntax_kind = guess_syntax(input_file)

        select case (syntax_kind)
        case (VIS3D_SYNTAX_MCX)
            call vis3d_read_config_mcx(input_file, cfg, ierr)
        case (VIS3D_SYNTAX_MCNP)
            call vis3d_read_config_mcnp(input_file, cfg, ierr)
        case default
            ierr = 1
            write(*,'(A)') 'VIS3D error: unsupported syntax hint.'
            return
        end select
        if (ierr /= 0) then
            write(*,'(A)') 'VIS3D error: failed while reading VIS3D config.'
            return
        end if
        if (.not. cfg%enabled) return

        call cfg%validate(ierr, message)
        if (ierr /= 0) then
            if (len_trim(message) > 0) write(*,'(A)') trim(message)
            write(*,'(A)') 'VIS3D error: invalid export configuration.'
            return
        end if

        call resolve_export_plan(cfg, export_mode, export_format, ierr)
        if (ierr /= 0) then
            write(*,'(A)') 'VIS3D error: unsupported MODE/FORMAT combination.'
            return
        end if
        if (present(output_dir_override)) then
            call apply_output_dir_override(input_file, output_dir_override, export_format, cfg)
        end if

        call geometry_build_from_input(input_file, syntax_kind, model, ierr)
        if (ierr /= 0) then
            write(*,'(A,I0)') 'VIS3D error: geometry parsing failed, ierr = ', ierr
            return
        end if

        call vis3d_build_geom_context(model, ctx, ierr)
        if (ierr /= 0) then
            write(*,'(A)') 'VIS3D error: failed to build geometry context.'
            return
        end if

        call vis3d_resolve_bbox(ctx, cfg, resolved_bbox, ierr)
        if (ierr /= 0) then
            write(*,'(A)') 'VIS3D error: failed to resolve bounding box.'
            return
        end if

        if (export_mode == VIS3D_MODE_SURFACE) then
            call vis3d_build_surface(ctx, cfg, resolved_bbox, surf, ierr)
            if (ierr /= 0) then
                write(*,'(A)') 'VIS3D error: failed to tessellate surface geometry.'
                return
            end if
            select case (export_format)
            case (VIS3D_FMT_VTP)
                call write_vtp(trim(cfg%output), surf, cfg%fields, ierr)
            case (VIS3D_FMT_VTU)
                call write_vtu(trim(cfg%output), surf, cfg%fields, ierr)
            case default
                ierr = 1
            end select
            if (ierr /= 0) then
                write(*,'(A)') 'VIS3D error: failed to write surface output.'
                return
            end if
        else
            call vis3d_sample_voxel(ctx, cfg, resolved_bbox, vox, ierr)
            if (ierr /= 0) then
                write(*,'(A)') 'VIS3D error: failed to sample voxel model.'
                return
            end if
            call inspect_voxel_result(vox, ierr)
            if (ierr /= 0) return
            call write_vti(trim(cfg%output), vox, cfg%fields, ierr)
            if (ierr /= 0) then
                write(*,'(A)') 'VIS3D error: failed to write voxel output.'
                return
            end if
        end if
    contains
        subroutine resolve_export_plan(cfg, mode_out, format_out, ierr)
            type(vis3d_config_t), intent(in) :: cfg
            integer, intent(out) :: mode_out, format_out, ierr

            ierr = 0
            mode_out = cfg%mode
            format_out = cfg%format

            if (mode_out == VIS3D_MODE_AUTO) then
                select case (format_out)
                case (VIS3D_FMT_VTP, VIS3D_FMT_VTU)
                    mode_out = VIS3D_MODE_SURFACE
                case (VIS3D_FMT_VTI)
                    mode_out = VIS3D_MODE_VOXEL
                case default
                    mode_out = VIS3D_MODE_VOXEL
                end select
            end if

            if (format_out == VIS3D_FMT_UNKNOWN) then
                select case (mode_out)
                case (VIS3D_MODE_VOXEL)
                    format_out = VIS3D_FMT_VTI
                case (VIS3D_MODE_SURFACE)
                    format_out = VIS3D_FMT_VTP
                case default
                    ierr = 1
                    return
                end select
            end if

            select case (mode_out)
            case (VIS3D_MODE_VOXEL)
                if (format_out /= VIS3D_FMT_VTI) ierr = 1
            case (VIS3D_MODE_SURFACE)
                if (format_out /= VIS3D_FMT_VTP .and. format_out /= VIS3D_FMT_VTU) ierr = 1
            case default
                ierr = 1
            end select
        end subroutine resolve_export_plan

        subroutine inspect_voxel_result(vox, ierr)
            type(voxel_dataset_t), intent(in) :: vox
            integer, intent(out) :: ierr
            integer :: unresolved_count, total_count, first_cell_id

            ierr = 0
            if (.not. allocated(vox%cell_id)) then
                ierr = 1
                write(*,'(A)') 'VIS3D error: voxel result is missing cell_id data.'
                return
            end if

            total_count = size(vox%cell_id)
            unresolved_count = count(vox%cell_id < 0)
            if (unresolved_count >= total_count) then
                ierr = 1
                write(*,'(A)') 'VIS3D error: voxel sampling matched no cells inside the export bbox.'
                write(*,'(A,I0,A,I0,A,I0)') 'VIS3D grid: ', vox%grid%nx, ' x ', vox%grid%ny, ' x ', vox%grid%nz
                write(*,'(A,6(1X,F0.6))') 'VIS3D bbox:', &
                    vox%bbox%xmin, vox%bbox%xmax, vox%bbox%ymin, vox%bbox%ymax, vox%bbox%zmin, vox%bbox%zmax
                write(*,'(A)') 'Try tightening ORIGIN/WIDTH in @VIS3D or checking unsupported MCNP geometry.'
                return
            end if

            first_cell_id = vox%cell_id(1,1,1)
            if (all(vox%cell_id == first_cell_id)) then
                write(*,'(A,I0,A)') 'VIS3D warning: the voxel grid resolved to a single cell_id = ', first_cell_id, '.'
                write(*,'(A)') 'ParaView may look empty until you inspect a Slice/Clip or tighten the export bbox.'
            else if (unresolved_count > 0) then
                write(*,'(A,I0,A,I0,A)') 'VIS3D warning: ', unresolved_count, ' of ', total_count, &
                    ' voxels did not match any cell.'
            end if
        end subroutine inspect_voxel_result

        subroutine apply_output_dir_override(input_file, output_dir, export_format, cfg)
            character(len=*), intent(in) :: input_file
            character(len=*), intent(in) :: output_dir
            integer, intent(in) :: export_format
            type(vis3d_config_t), intent(inout) :: cfg
            character(len=256) :: stem
            character(len=8) :: ext

            if (len_trim(output_dir) == 0) return
            stem = input_stem(input_file)
            ext = format_extension(export_format)
            cfg%output = join_path(trim(output_dir), trim(stem) // '.' // trim(ext))
        end subroutine apply_output_dir_override

        function input_stem(filename) result(stem)
            character(len=*), intent(in) :: filename
            character(len=256) :: stem
            integer :: i, last_sep, last_dot

            stem = trim(filename)
            last_sep = 0
            last_dot = 0
            do i = 1, len_trim(filename)
                if (filename(i:i) == '\' .or. filename(i:i) == '/') last_sep = i
                if (filename(i:i) == '.') last_dot = i
            end do

            if (last_dot > last_sep) then
                stem = trim(filename(last_sep+1:last_dot-1))
            else
                stem = trim(filename(last_sep+1:len_trim(filename)))
            end if
        end function input_stem

        function format_extension(fmt) result(ext)
            integer, intent(in) :: fmt
            character(len=8) :: ext

            select case (fmt)
            case (VIS3D_FMT_VTI)
                ext = 'vti'
            case (VIS3D_FMT_VTU)
                ext = 'vtu'
            case default
                ext = 'vtp'
            end select
        end function format_extension

        function join_path(dirpath, leaf) result(out)
            character(len=*), intent(in) :: dirpath
            character(len=*), intent(in) :: leaf
            character(len=256) :: out
            integer :: n

            out = trim(dirpath)
            n = len_trim(out)
            if (n <= 0) then
                out = trim(leaf)
            else if (out(n:n) == '\' .or. out(n:n) == '/') then
                out = trim(out) // trim(leaf)
            else
                out = trim(out) // '\' // trim(leaf)
            end if
        end function join_path

        integer function guess_syntax(filename)
            character(len=*), intent(in) :: filename
            character(len=512) :: line
            integer :: unit, ios
            guess_syntax = VIS3D_SYNTAX_MCX
            open(newunit=unit, file=trim(filename), status='old', action='read', iostat=ios)
            if (ios /= 0) return
            do
                read(unit, '(A)', iostat=ios) line
                if (ios /= 0) exit
                line = adjustl(line)
                if (len_trim(line) == 0) cycle
                if (line(1:1) == 'c' .or. line(1:1) == 'C') then
                    guess_syntax = VIS3D_SYNTAX_MCNP
                else
                    guess_syntax = VIS3D_SYNTAX_MCX
                end if
                exit
            end do
            close(unit)
        end function guess_syntax
    end subroutine vis3d_run
end module vis3d_driver
