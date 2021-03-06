!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright (C) 2011 UNESCO-IHE, WL|Delft Hydraulics and Delft University !
! Dano Roelvink, Ap van Dongeren, Ad Reniers, Jamie Lescinski,            !
! Jaap van Thiel de Vries, Robert McCall                                  !
!                                                                         !
! d.roelvink@unesco-ihe.org                                               !
! UNESCO-IHE Institute for Water Education                                !
! P.O. Box 3015                                                           !
! 2601 DA Delft                                                           !
! The Netherlands                                                         !
!                                                                         !
! This library is free software; you can redistribute it and/or           !
! modify it under the terms of the GNU Lesser General Public              !
! License as published by the Free Software Foundation; either            !
! version 2.1 of the License, or (at your option) any later version.      !
!                                                                         !
! This library is distributed in the hope that it will be useful,         !
! but WITHOUT ANY WARRANTY; without even the implied warranty of          !
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU        !
! Lesser General Public License for more details.                         !
!                                                                         !
! You should have received a copy of the GNU Lesser General Public        !
! License along with this library; if not, write to the Free Software     !
! Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307     !
! USA                                                                     !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
module ship_module
   use typesandkinds
   implicit none
   save
   type ship
      character(slen)                 :: name
      real*8                          :: dx
      real*8                          :: dy
      integer                         :: nx
      integer                         :: ny
      integer                         :: compute_force  ! option (0/1) to compute forces on ship (can be switched on/off per ship)
      integer                         :: compute_motion ! option (0/1) to compute ship motion due to waves
      integer                         :: flying
      character(slen)                 :: shipgeom
      real*8                          :: xCG            ! x location of center of gravity w.r.t. ship grid
      real*8                          :: yCG            ! y location of center of gravity w.r.t. ship grid
      real*8                          :: zCG            ! z location of center of gravity w.r.t. ship grid
      real*8, dimension(:,:), pointer :: x
      real*8, dimension(:,:), pointer :: y
      real*8, dimension(:,:), pointer :: depth        ! ship depth defined on local grid relative to plane fixed to ship
      real*8, dimension(:,:), pointer :: zhull        ! actual z-coordinate of ship hull relative to horizontal reference plane
      real*8, dimension(:,:), pointer :: zs           ! water level defined on ship grid, interpolated from XBeach
      real*8, dimension(:,:), pointer :: ph           ! pressure head at ship hull = zs-zhull
      character(slen)                 :: shiptrack
      integer                         :: track_nt
      real*8 , dimension(:)  , pointer :: track_t
      real*8 , dimension(:)  , pointer :: track_x
      real*8 , dimension(:)  , pointer :: track_y
      real*8 , dimension(:)  , pointer :: track_z
      real*8 , dimension(:)  , pointer :: track_dir
      real*8                           :: mass
      real*8                           :: Jx
      real*8                           :: Jy
      real*8                           :: Jz
      real*8 , dimension(:)  , pointer :: xs
      real*8 , dimension(:)  , pointer :: ys
      integer, dimension(:)  , pointer :: nrx
      integer, dimension(:)  , pointer :: nry
      integer, dimension(:)  , pointer :: nrin
      integer, dimension(:)  , pointer :: iflag
      integer, dimension(:,:), pointer :: iref
      real*8 , dimension(:,:), pointer :: w
      integer, dimension(:)  , pointer :: covered
   end type ship

contains

   subroutine ship_init(s,par,sh)
      use params
      use xmpi_module
      use spaceparams
      use readkey_module
      use filefunctions
      use interp

      implicit none

      type(parameters)                            :: par
      type(spacepars),target                      :: s
      type(ship), dimension(:), pointer           :: sh

      integer                                     :: i,fid,iy,it
      integer                                     :: n2
      logical                                     :: toall = .true.

      !include 's.ind'
      !include 's.inp'
      if(par%ships==1) then
         ! Read ship names (== filenames with ship geometry and track data)

         par%nship = count_lines(par%shipfile)

         allocate(sh(par%nship))
         if (xmaster) then
            fid=create_new_fid()
            open(fid,file=par%shipfile)
            do i=1,par%nship
               read(fid,'(a)') sh(i)%name
            enddo
            close(fid)
         endif
#ifdef USEMPI
         do i=1,par%nship
            call xmpi_bcast(sh(i)%name,toall)
         enddo
#endif
         do i=1,par%nship
            ! Read ship geometry
            sh(i)%dx  = readkey_dbl(sh(i)%name,'dx',  5.d0,   0.d0,      100.d0)
            sh(i)%dy  = readkey_dbl(sh(i)%name,'dy',  5.d0,   0.d0,      100.d0)
            sh(i)%nx  = readkey_int(sh(i)%name,'nx',  20,        1,      1000  )
            sh(i)%ny  = readkey_int(sh(i)%name,'ny',  20,        1,      1000  )
            sh(i)%shipgeom = readkey_name(sh(i)%name,'shipgeom',required=.true.)
            sh(i)%xCG  = readkey_dbl(sh(i)%name,'xCG',  0.d0,   -1000.d0,      1000.d0)
            sh(i)%yCG  = readkey_dbl(sh(i)%name,'yCG',  0.d0,   -1000.d0,      1000.d0)
            sh(i)%zCG  = readkey_dbl(sh(i)%name,'zCG',  0.d0,   -1000.d0,      1000.d0)
            sh(i)%shiptrack = readkey_name(sh(i)%name,'shiptrack',required=.true.)
            sh(i)%compute_force  = readkey_int(sh(i)%name,'compute_force' ,  0,  0, 1)
            sh(i)%compute_motion = readkey_int(sh(i)%name,'compute_motion',  0,  0, 1)
            sh(i)%flying         = readkey_int(sh(i)%name,'flying',  0,  0, 1)

            allocate (sh(i)%depth(sh(i)%nx+1,sh(i)%ny+1))
            allocate (sh(i)%zhull(sh(i)%nx+1,sh(i)%ny+1))
            allocate (sh(i)%ph(sh(i)%nx+1,sh(i)%ny+1))
            allocate (sh(i)%zs(sh(i)%nx+1,sh(i)%ny+1))
            allocate (sh(i)%x(sh(i)%nx+1,sh(i)%ny+1))
            allocate (sh(i)%y(sh(i)%nx+1,sh(i)%ny+1))
            n2=(sh(i)%nx+1)*(sh(i)%ny+1)
            allocate (sh(i)%xs(n2))
            allocate (sh(i)%ys(n2))
            allocate (sh(i)%nrx(n2))
            allocate (sh(i)%nry(n2))
            allocate (sh(i)%nrin(n2))
            allocate (sh(i)%iflag(n2))
            allocate (sh(i)%iref(4,n2))
            allocate (sh(i)%w(4,n2))
            allocate (sh(i)%covered(n2))
            sh(i)%ph = 0.d0
            sh(i)%zs = 0.d0

            fid=create_new_fid()
            !open(fid,file=sh(i)%shipgeom)
            if(xmaster) open(fid,file=sh(i)%shipgeom)

            do iy=1,sh(i)%ny+1
               call read_v(fid,sh(i)%depth(:,iy))
            enddo
            if(xmaster) close(fid)

            if (sh(i)%compute_motion==0) then
               sh(i)%zhull=-sh(i)%depth
            endif
            if (sh(i)%compute_force==0) then
               sh(i)%ph=sh(i)%depth
            endif

            ! Read t,x,y of ship position

            sh(i)%track_nt=count_lines(sh(i)%shiptrack)

            fid=create_new_fid()
            if(xmaster) open(fid,file=sh(i)%shiptrack)

            allocate(sh(i)%track_t(sh(i)%track_nt))
            allocate(sh(i)%track_x(sh(i)%track_nt))
            allocate(sh(i)%track_y(sh(i)%track_nt))
            allocate(sh(i)%track_z(sh(i)%track_nt))
            allocate(sh(i)%track_dir(sh(i)%track_nt))

            if (sh(i)%flying==0) then
               do it=1,sh(i)%track_nt
                  call read_v(fid,sh(i)%track_t(it),sh(i)%track_x(it),sh(i)%track_y(it))
               enddo
               sh(i)%track_z=0.d0
            else
               do it=1,sh(i)%track_nt
                  call read_v(fid,sh(i)%track_t(it),sh(i)%track_x(it),sh(i)%track_y(it),sh(i)%track_z(it))
               enddo
            endif
            if(xmaster)close(fid)

            !  Compute ship direction

            sh(i)%track_dir(1)=atan2(sh(i)%track_y(2)-sh(i)%track_y(1),sh(i)%track_x(2)-sh(i)%track_x(1))
            do it=2,sh(i)%track_nt-1
               sh(i)%track_dir(it)=atan2(sh(i)%track_y(it+1)-sh(i)%track_y(it-1),sh(i)%track_x(it+1)-sh(i)%track_x(it-1))
            enddo
            it=sh(i)%track_nt
            sh(i)%track_dir(it)=atan2(sh(i)%track_y(it)-sh(i)%track_y(it-1),sh(i)%track_x(it)-sh(i)%track_x(it-1))

         enddo ! loop over ships

         ! Initialize ship-related global variables
         if (xmaster) then
            ! only on xmaster, rest is done automatically by call from libxbeach
            allocate(s%shipxCG (par%nship))
            allocate(s%shipyCG (par%nship))
            allocate(s%shipzCG (par%nship))
            allocate(s%shipFx  (par%nship))
            allocate(s%shipFy  (par%nship))
            allocate(s%shipFz  (par%nship))
            allocate(s%shipMx  (par%nship))
            allocate(s%shipMy  (par%nship))
            allocate(s%shipMz  (par%nship))
            allocate(s%shipphi (par%nship))
            allocate(s%shipchi (par%nship))
            allocate(s%shippsi (par%nship))
            s%shipxCG=0.d0
            s%shipyCG=0.d0
            s%shipzCG=0.d0
            s%shipFx=0.d0
            s%shipFy=0.d0
            s%shipFz=0.d0
         endif
      else ! (par%ships==0)
         if (xmaster) then
            ! just allocate address for memory, only on xmaster, rest is
            ! done automatically by call from libxbeach
            allocate(s%shipxCG (par%nship))
            allocate(s%shipyCG (par%nship))
            allocate(s%shipzCG (par%nship))
            allocate(s%shipFx  (par%nship))
            allocate(s%shipFy  (par%nship))
            allocate(s%shipFz  (par%nship))
            allocate(s%shipMx  (par%nship))
            allocate(s%shipMy  (par%nship))
            allocate(s%shipMz  (par%nship))
            allocate(s%shipphi (par%nship))
            allocate(s%shipchi (par%nship))
            allocate(s%shippsi (par%nship))
         endif
      endif

   end subroutine ship_init

   subroutine shipwave(s,par,sh)
      use params
      use xmpi_module
      use spaceparams
      use readkey_module
      use filefunctions
      use interp

      implicit none

      type(parameters)                            :: par
      type(spacepars),target                      :: s
      type(ship), dimension(:), pointer           :: sh

      integer                                     :: i,ix,iy,shp_indx
      logical, save                               :: firstship=.true.
      real*8                                      :: shipx_old,shipy_old,dirship,radius,cosdir,sindir
      integer                                     :: n1,n2,iprint=0
      real                                        :: xymiss=-999

      real*8, dimension(:,:),allocatable :: zsvirt
      !include 's.ind'
      !include 's.inp'

      if (.not. allocated(zsvirt)) allocate(zsvirt(s%nx+1,s%ny+1))
      zsvirt=s%zs+s%ph
      s%ph=0.d0

      do i=1,par%nship

         ! Find actual position and orientation of ship

         shipx_old = s%shipxCG(i)
         shipy_old = s%shipyCG(i)
         call linear_interp(sh(i)%track_t,sh(i)%track_x,sh(i)%track_nt,par%t,s%shipxCG(i),shp_indx)
         call linear_interp(sh(i)%track_t,sh(i)%track_y,sh(i)%track_nt,par%t,s%shipyCG(i),shp_indx)
         if (sh(i)%flying==1) then
            call linear_interp(sh(i)%track_t,sh(i)%track_z,sh(i)%track_nt,par%t,s%shipzCG(i),shp_indx)
         else
            s%shipzCG(i) = 0.d0
         endif
         call linear_interp(sh(i)%track_t,sh(i)%track_dir,sh(i)%track_nt,par%t,dirship,shp_indx)
         radius=max(sh(i)%nx*sh(i)%dx,sh(i)%ny*sh(i)%dy)/2
         cosdir=cos(dirship)
         sindir=sin(dirship)

         ! Compute pressures on ship based on water levels from XBeach
         !------------------------------------------------------------
         ! Update locations of x ship grid points
         do iy=1,sh(i)%ny+1
            do ix=1,sh(i)%nx+1
               sh(i)%x(ix,iy)=s%shipxCG(i)+(ix-sh(i)%nx/2-1)*sh(i)%dx*cosdir - (iy-sh(i)%ny/2-1)*sh(i)%dy*sindir
               sh(i)%y(ix,iy)=s%shipyCG(i)+(ix-sh(i)%nx/2-1)*sh(i)%dx*sindir + (iy-sh(i)%ny/2-1)*sh(i)%dy*cosdir
            end do
         end do
         ! Interpolate XBeach water levels to ship grid when required
         n1=(s%nx+1)*(s%ny+1)
         n2=(sh(i)%nx+1)*(sh(i)%ny+1)
         ! Only carry out (costly) MKMAP once when ship is not moving
         !! If XBeach grid is regular rectangular a more efficient mapper can be used; TBD
         call MKMAP (s%wetz    ,s%xz      ,s%yz          ,s%nx+1     ,s%ny+1  , &
         & sh(i)%x   ,sh(i)%y   ,n2            ,sh(i)%xs   ,sh(i)%ys, &
         & sh(i)%nrx ,sh(i)%nry ,sh(i)%iflag   ,sh(i)%nrin ,sh(i)%w , &
         & sh(i)%iref,iprint    ,sh(i)%covered ,xymiss)
         call GRMAP (zsvirt   ,n1      ,sh(i)%zs      ,n2         ,sh(i)%iref, &
         & sh(i)%w     ,4       ,iprint    )

         if (sh(i)%compute_force==1) then
            ! Compute pressure head (m) on ship grid including small-scale motions
            !-----------------------------------------------------
            sh(i)%ph = sh(i)%zs-sh(i)%zhull

            ! Compute forces on ship when required
            !-------------------------------------
            call ship_force(i,sh(i),s,par)

            if (sh(i)%compute_motion==1) then
               ! Update vertical position and rotations when required
               !-----------------------------------------------------
               !    TBD

               ! Compute actual z position of ship hull on ship grid when required
               !------------------------------------------------------------------
               do iy=1,sh(i)%ny+1
                  do ix=1,sh(i)%nx+1
                     sh(i)%zhull(ix,iy)=s%shipzCG(i)-sh(i)%zCG-sh(i)%depth(ix,iy) &
                     & -(sh(i)%x(ix,iy)-sh(i)%xCG)*sin(s%shipchi(i))  &
                     & +(sh(i)%y(ix,iy)-sh(i)%yCG)*sin(s%shipphi(i))
                  enddo
               enddo
            endif ! compute_motion
            ! Compute pressure head (m) on ship grid ti feed back into XBeach
            !-----------------------------------------------------
            ! Next line to be implemented in combination with vertical motion only
            ! sh(i)%ph = sum(sh(i)%zs)/((sh(i)%nx+1)*(sh(i)%ny+1))-sh(i)%zhull
            sh(i)%ph = -sh(i)%zhull
            do iy=1,sh(i)%ny+1
               do ix=1,sh(i)%nx+1
                  if (sh(i)%depth(ix,iy)==0) sh(i)%ph(ix,iy)=0.d0
               enddo
            enddo
         else
            sh(i)%ph = -sh(i)%zhull-s%shipzCG(i)
            sh(i)%ph = max(sh(i)%ph,0.d0)
         endif ! compute_forces

         ! Compute pressure head (m) on XBeach grid
         !-----------------------------------------
         call grmap2(s%ph,  s%dsdnzi ,n1      ,sh(i)%ph, sh(i)%dx*sh(i)%dy      ,n2         ,sh(i)%iref, &
         & sh(i)%w     ,4          )
         !        do iy=1,s%ny+1
         !           do ix=1,s%nx+1
         !              ! Convert XBeach cell center coordinates to coordinates in local ship grid
         !              x1 =  (xz(ix,iy)-shipxCG(i))*cosdir + (yz(ix,iy)-shipyCG(i))*sindir!
         !              y1 = -(xz(ix,iy)-shipxCG(i))*sindir + (yz(ix,iy)-shipyCG(i))*cosdir
         !              ! Convert to (float) grid number
         !              xrel=x1/sh(i)%dx+sh(i)%nx/2
         !              yrel=y1/sh(i)%dy+sh(i)%ny/2
         !              i1=floor(xrel)
         !              j1=floor(yrel)
         !              ! Carry out bilinear interpolation
         !              if (i1>=0 .and. i1<SH(i)%nx .and. j1>=0 .and. j1<sh(i)%ny) then
         !                 s%ph(ix,iy)=s%ph(ix,iy)+(1.d0-(xrel-float(i1)))*(1.d0-(yrel-float(j1)))*sh(i)%depth(i1+1,j1+1)  &
         !                                        +(      xrel-float(i1) )*(1.d0-(yrel-float(j1)))*sh(i)%depth(i1+2,j1+1  )  &
         !                                        +(1.d0-(xrel-float(i1)))*(      yrel-float(j1) )*sh(i)%depth(i1+1,j1+2)  &
         !                                        +(      xrel-float(i1) )*(      yrel-float(j1) )*sh(i)%depth(i1+2,j1+2)
         !                 s%ph(ix,iy)=s%ph(ix,iy)+(1.d0-(xrel-float(i1)))*(1.d0-(yrel-float(j1)))*sh(i)%ph(i1+1,j1+1)  &
         !                                        +(      xrel-float(i1) )*(1.d0-(yrel-float(j1)))*sh(i)%ph(i1+2,j1+1  )  &
         !                                        +(1.d0-(xrel-float(i1)))*(      yrel-float(j1) )*sh(i)%ph(i1+1,j1+2)  &
         !                                        +(      xrel-float(i1) )*(      yrel-float(j1) )*sh(i)%ph(i1+2,j1+2)

         !             endif
         !          enddo
         !       enddo
      enddo


      ! Compute

      if (firstship) then

         ! apply initial condition

         s%zs=s%zs-s%ph
      endif

      firstship=.false.

   end subroutine shipwave

   subroutine ship_force(i,sh,s,par)
      use params
      use spaceparams
      type (ship)              :: sh
      type (parameters)        :: par
      type (spacepars),target  :: s
      integer                  :: ix,iy,i
      real*8                   :: dFx,dFy,dFz,hdx,hdy

      !include 's.ind'
      !include 's.inp'

      s%shipFx(i) = 0.d0
      s%shipFy(i) = 0.d0
      s%shipFz(i) = 0.d0
      s%shipMx(i) = 0.d0
      s%shipMy(i) = 0.d0
      s%shipMz(i) = 0.d0
      hdx=.5d0*sh%dx
      hdy=.5d0*sh%dy
      do iy=1,sh%ny
         do ix=1,sh%nx
            dFx=.5*(sh%ph(ix,iy)+sh%ph(ix+1,iy))*(sh%depth(ix+1,iy)-sh%depth(ix,iy))*sh%dy
            dFy=.5*(sh%ph(ix,iy)+sh%ph(ix,iy+1))*(sh%depth(ix,iy+1)-sh%depth(ix,iy))*sh%dx
            dFz=sh%ph(ix,iy)*sh%dx*sh%dy
            s%shipFx(i)=s%shipFx(i)+dFx
            s%shipFy(i)=s%shipFy(i)+dFy
            s%shipFz(i)=s%shipFz(i)+dFz
            s%shipMx(i)=s%shipMx(i)+((sh%y(ix,iy)+hdy)-sh%yCG)*dFz-(.5d0*(sh%zhull(ix,iy)+sh%zhull(ix,iy+1))-sh%zCG)*dFy
            s%shipMy(i)=s%shipMy(i)-((sh%x(ix,iy)+hdx)-sh%xCG)*dFz+(.5d0*(sh%zhull(ix,iy)+sh%zhull(ix+1,iy))-sh%zCG)*dFx
            !shipMz(i)=shipMz(i)-((sh%y(ix,iy)+hdy)-sh%yCG)*dFx+((sh%x(ix,iy)+hdx)-sh%xCG)*dFy
            s%shipMz(i)=s%shipMz(i)-(.5*(((iy-sh%ny/2-1)*sh%dy-sh%yCG)+((iy+1-sh%ny/2-1)*sh%dy-sh%yCG)))*dFx &
            & +(.5*(((ix-sh%nx/2-1)*sh%dx-sh%xCG)+((ix+1-sh%nx/2-1)*sh%dx-sh%xCG)))*dFy
         enddo
      enddo
      s%shipFx(i)=s%shipFx(i)      *par%rho*par%g
      s%shipFy(i)=s%shipFy(i)      *par%rho*par%g
      s%shipFz(i)=s%shipFz(i)      *par%rho*par%g
      s%shipMx(i)=s%shipMx(i)      *par%rho*par%g
      s%shipMy(i)=s%shipMy(i)      *par%rho*par%g
      s%shipMz(i)=s%shipMz(i)      *par%rho*par%g


   end subroutine ship_force

end module ship_module
