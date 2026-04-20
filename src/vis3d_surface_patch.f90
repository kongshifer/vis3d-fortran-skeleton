module vis3d_surface_patch
    use vis3d_kinds, only: dp
    use vis3d_types, only: aabb_t, vis3d_geom_context_t, vis3d_config_t, poly_surface_dataset_t
    use vis3d_host_types, only: box_primitive_t, cylinder_primitive_t, sphere_primitive_t
    implicit none
    private
    public :: vis3d_build_surface

contains
    subroutine vis3d_build_surface(ctx, cfg, bbox, surf, ierr)
        type(vis3d_geom_context_t), intent(in) :: ctx
        type(vis3d_config_t), intent(in) :: cfg
        type(aabb_t), intent(in) :: bbox
        type(poly_surface_dataset_t), intent(out) :: surf
        integer, intent(out) :: ierr

        integer :: i, nseg

        ierr = 0
        surf%n_points = 0
        surf%n_tris = 0

        nseg = max(12, 12 * max(1, cfg%surface_quality))

        do i = 1, size(ctx%model%boxes)
            call append_box_surface(surf, ctx%model%boxes(i), bbox)
        end do

        do i = 1, size(ctx%model%cylinders)
            call append_cylinder_surface(surf, ctx%model%cylinders(i), bbox, nseg)
        end do

        do i = 1, size(ctx%model%spheres)
            call append_sphere_surface(surf, ctx%model%spheres(i), bbox, nseg)
        end do

        if (surf%n_tris <= 0) ierr = 1
    end subroutine vis3d_build_surface

    subroutine append_box_surface(surf, box, clip_bbox)
        type(poly_surface_dataset_t), intent(inout) :: surf
        type(box_primitive_t), intent(in) :: box
        type(aabb_t), intent(in) :: clip_bbox

        type(box_primitive_t) :: clipped
        real(dp) :: p000(3), p001(3), p010(3), p011(3)
        real(dp) :: p100(3), p101(3), p110(3), p111(3)

        clipped = box
        clipped%xmin = max(clipped%xmin, clip_bbox%xmin)
        clipped%xmax = min(clipped%xmax, clip_bbox%xmax)
        clipped%ymin = max(clipped%ymin, clip_bbox%ymin)
        clipped%ymax = min(clipped%ymax, clip_bbox%ymax)
        clipped%zmin = max(clipped%zmin, clip_bbox%zmin)
        clipped%zmax = min(clipped%zmax, clip_bbox%zmax)
        if (clipped%xmax <= clipped%xmin .or. clipped%ymax <= clipped%ymin .or. clipped%zmax <= clipped%zmin) return

        p000 = [clipped%xmin, clipped%ymin, clipped%zmin]
        p001 = [clipped%xmin, clipped%ymin, clipped%zmax]
        p010 = [clipped%xmin, clipped%ymax, clipped%zmin]
        p011 = [clipped%xmin, clipped%ymax, clipped%zmax]
        p100 = [clipped%xmax, clipped%ymin, clipped%zmin]
        p101 = [clipped%xmax, clipped%ymin, clipped%zmax]
        p110 = [clipped%xmax, clipped%ymax, clipped%zmin]
        p111 = [clipped%xmax, clipped%ymax, clipped%zmax]

        call append_box_face(surf, clipped, p000, p010, p011, p001)
        call append_box_face(surf, clipped, p100, p101, p111, p110)
        call append_box_face(surf, clipped, p000, p001, p101, p100)
        call append_box_face(surf, clipped, p010, p110, p111, p011)
        call append_box_face(surf, clipped, p000, p100, p110, p010)
        call append_box_face(surf, clipped, p001, p011, p111, p101)
    end subroutine append_box_surface

    subroutine append_box_face(surf, box, p1, p2, p3, p4)
        type(poly_surface_dataset_t), intent(inout) :: surf
        type(box_primitive_t), intent(in) :: box
        real(dp), intent(in) :: p1(3), p2(3), p3(3), p4(3)

        call surf%append_triangle(p1, p2, p3, box%cell_id, box%material_id, box%surface_id, box%universe_id)
        call surf%append_triangle(p1, p3, p4, box%cell_id, box%material_id, box%surface_id, box%universe_id)
    end subroutine append_box_face

    subroutine append_cylinder_surface(surf, cyl, clip_bbox, nseg)
        type(poly_surface_dataset_t), intent(inout) :: surf
        type(cylinder_primitive_t), intent(in) :: cyl
        type(aabb_t), intent(in) :: clip_bbox
        integer, intent(in) :: nseg

        real(dp), parameter :: two_pi = 6.2831853071795864769_dp
        real(dp) :: zmin, zmax
        real(dp) :: theta1, theta2
        real(dp) :: c1, s1, c2, s2
        real(dp) :: outer_top_1(3), outer_top_2(3), outer_bot_1(3), outer_bot_2(3)
        real(dp) :: inner_top_1(3), inner_top_2(3), inner_bot_1(3), inner_bot_2(3)
        real(dp) :: top_center(3), bot_center(3)
        integer :: i

        if (cyl%rmax <= 0.0_dp) return
        if (cyl%xc + cyl%rmax < clip_bbox%xmin .or. cyl%xc - cyl%rmax > clip_bbox%xmax) return
        if (cyl%yc + cyl%rmax < clip_bbox%ymin .or. cyl%yc - cyl%rmax > clip_bbox%ymax) return

        zmin = max(cyl%zmin, clip_bbox%zmin)
        zmax = min(cyl%zmax, clip_bbox%zmax)
        if (zmax <= zmin) return

        top_center = [cyl%xc, cyl%yc, zmax]
        bot_center = [cyl%xc, cyl%yc, zmin]

        do i = 0, nseg - 1
            theta1 = two_pi * real(i, dp) / real(nseg, dp)
            theta2 = two_pi * real(i + 1, dp) / real(nseg, dp)
            c1 = cos(theta1)
            s1 = sin(theta1)
            c2 = cos(theta2)
            s2 = sin(theta2)

            outer_top_1 = [cyl%xc + cyl%rmax * c1, cyl%yc + cyl%rmax * s1, zmax]
            outer_top_2 = [cyl%xc + cyl%rmax * c2, cyl%yc + cyl%rmax * s2, zmax]
            outer_bot_1 = [cyl%xc + cyl%rmax * c1, cyl%yc + cyl%rmax * s1, zmin]
            outer_bot_2 = [cyl%xc + cyl%rmax * c2, cyl%yc + cyl%rmax * s2, zmin]

            call surf%append_triangle(outer_bot_1, outer_bot_2, outer_top_2, &
                cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
            call surf%append_triangle(outer_bot_1, outer_top_2, outer_top_1, &
                cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)

            if (cyl%rmin > 0.0_dp) then
                inner_top_1 = [cyl%xc + cyl%rmin * c1, cyl%yc + cyl%rmin * s1, zmax]
                inner_top_2 = [cyl%xc + cyl%rmin * c2, cyl%yc + cyl%rmin * s2, zmax]
                inner_bot_1 = [cyl%xc + cyl%rmin * c1, cyl%yc + cyl%rmin * s1, zmin]
                inner_bot_2 = [cyl%xc + cyl%rmin * c2, cyl%yc + cyl%rmin * s2, zmin]

                call surf%append_triangle(inner_bot_1, inner_top_2, inner_bot_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
                call surf%append_triangle(inner_bot_1, inner_top_1, inner_top_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)

                call surf%append_triangle(inner_top_1, outer_top_2, outer_top_1, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
                call surf%append_triangle(inner_top_1, inner_top_2, outer_top_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)

                call surf%append_triangle(inner_bot_1, outer_bot_1, outer_bot_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
                call surf%append_triangle(inner_bot_1, outer_bot_2, inner_bot_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
            else
                call surf%append_triangle(top_center, outer_top_2, outer_top_1, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
                call surf%append_triangle(bot_center, outer_bot_1, outer_bot_2, &
                    cyl%cell_id, cyl%material_id, cyl%surface_id, cyl%universe_id)
            end if
        end do
    end subroutine append_cylinder_surface

    subroutine append_sphere_surface(surf, sph, clip_bbox, nseg)
        type(poly_surface_dataset_t), intent(inout) :: surf
        type(sphere_primitive_t), intent(in) :: sph
        type(aabb_t), intent(in) :: clip_bbox
        integer, intent(in) :: nseg

        real(dp), parameter :: two_pi = 6.2831853071795864769_dp
        real(dp), parameter :: pi = 3.14159265358979323846_dp
        integer :: nlat, nlon, i, j
        real(dp) :: phi1, phi2, theta1, theta2
        real(dp) :: p11(3), p12(3), p21(3), p22(3)

        if (sph%rmax <= 0.0_dp) return
        if (sph%xc + sph%rmax < clip_bbox%xmin .or. sph%xc - sph%rmax > clip_bbox%xmax) return
        if (sph%yc + sph%rmax < clip_bbox%ymin .or. sph%yc - sph%rmax > clip_bbox%ymax) return
        if (sph%zc + sph%rmax < clip_bbox%zmin .or. sph%zc - sph%rmax > clip_bbox%zmax) return

        nlat = max(8, nseg / 2)
        nlon = max(12, nseg)

        do j = 0, nlat - 1
            phi1 = pi * real(j, dp) / real(nlat, dp)
            phi2 = pi * real(j + 1, dp) / real(nlat, dp)
            do i = 0, nlon - 1
                theta1 = two_pi * real(i, dp) / real(nlon, dp)
                theta2 = two_pi * real(i + 1, dp) / real(nlon, dp)

                call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmax, phi1, theta1, p11)
                call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmax, phi1, theta2, p12)
                call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmax, phi2, theta1, p21)
                call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmax, phi2, theta2, p22)
                if (j == 0) then
                    call surf%append_triangle(p11, p22, p21, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                else if (j == nlat - 1) then
                    call surf%append_triangle(p11, p12, p21, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                else
                    call surf%append_triangle(p11, p12, p22, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                    call surf%append_triangle(p11, p22, p21, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                end if

                if (sph%rmin > 0.0_dp) then
                    call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmin, phi1, theta1, p11)
                    call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmin, phi1, theta2, p12)
                    call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmin, phi2, theta1, p21)
                    call sphere_point(sph%xc, sph%yc, sph%zc, sph%rmin, phi2, theta2, p22)
                    if (j == 0) then
                        call surf%append_triangle(p11, p21, p22, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                    else if (j == nlat - 1) then
                        call surf%append_triangle(p11, p21, p12, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                    else
                        call surf%append_triangle(p11, p22, p12, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                        call surf%append_triangle(p11, p21, p22, sph%cell_id, sph%material_id, sph%surface_id, sph%universe_id)
                    end if
                end if
            end do
        end do
    end subroutine append_sphere_surface

    subroutine sphere_point(xc, yc, zc, radius, phi, theta, point)
        real(dp), intent(in) :: xc, yc, zc, radius, phi, theta
        real(dp), intent(out) :: point(3)

        point(1) = xc + radius * sin(phi) * cos(theta)
        point(2) = yc + radius * sin(phi) * sin(theta)
        point(3) = zc + radius * cos(phi)
    end subroutine sphere_point
end module vis3d_surface_patch
