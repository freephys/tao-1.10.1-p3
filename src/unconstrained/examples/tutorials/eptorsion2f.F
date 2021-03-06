! "$Id$";
!
!  Program usage: mpirun -np <proc> eptorsion2f [all TAO options] 
!
!  Description:  This example demonstrates use of the TAO package to solve
!  unconstrained minimization problems in parallel.  This example is based 
!  on the Elastic-Plastic Torsion (dept) problem from the MINPACK-2 test suite.
!  The command line options are:
!    -mx <xg>, where <xg> = number of grid points in the 1st coordinate direction
!    -my <yg>, where <yg> = number of grid points in the 2nd coordinate direction
!    -par <param>, where <param> = angle of twist per unit length
!
!/*T
!   Concepts: TAO - Solving an unconstrained minimization problem
!   Routines: TaoInitialize(); TaoFinalize(); 
!   Routines: TaoCreate(); TaoDestroy();
!   Routines: TaoApplicationCreate(); TaoAppDestroy();
!   Routines: TaoAppSetObjectiveAndGradientRoutine();
!   Routines: TaoAppSetHessianMat(); TaoAppSetHessianRoutine();
!   Routines: TaoSetOptions();
!   Routines: TaoAppSetInitialSolutionVec(); TaoSolveApplication(); TaoDestroy();
!   Routines: TaoGetSolutionStatus();
!   Processors: n
!T*/
!
! ---------------------------------------------------------------------- 
!
!  Elastic-plastic torsion problem.  
!
!  The elastic plastic torsion problem arises from the determination 
!  of the stress field on an infinitely long cylindrical bar, which is
!  equivalent to the solution of the following problem:
!     min{ .5 * integral(||gradient(v(x))||^2 dx) - C * integral(v(x) dx)}
!  where C is the torsion angle per unit length.
!
!  The C version of this code is eptorsion2.c
!
! ---------------------------------------------------------------------- 

      implicit none
#include "eptorsion2f.h"

! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
!                   Variable declarations
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
!
!  See additional variable declarations in the file eptorsion2f.h
!
      integer          info           ! used to check for functions returning nonzeros
      Vec              x              ! solution vector
      Mat              H              ! hessian matrix
      PetscInt         Nx, Ny         ! number of processes in x- and y- directions
      TAO_SOLVER       tao            ! TAO_SOLVER solver context
      TAO_APPLICATION  torsionapp     ! TAO application context (PETSc)
      TaoTerminateReason reason
      PetscTruth       flg
      PetscInt         iter           ! iteration information
      PetscScalar      ff,gnorm,cnorm,xdiff
      PetscInt         i1
      

!  Note: Any user-defined Fortran routines (such as FormGradient)
!  MUST be declared as external.

      external FormInitialGuess,FormFunctionGradient,ComputeHessian

      i1 = 1

!     Initialize TAO, PETSc  contexts
      call PetscInitialize(PETSC_NULL_CHARACTER,info)
      call TaoInitialize(PETSC_NULL_CHARACTER,info)

!     Specify default parameters 
      param = 5.0d0
      mx = 10
      my = 10
      Nx = PETSC_DECIDE
      Ny = PETSC_DECIDE

!     Check for any command line arguments that might override defaults
      call PetscOptionsGetInt(PETSC_NULL_CHARACTER,"-mx",mx,flg,info)
      call PetscOptionsGetInt(PETSC_NULL_CHARACTER,"-my",my,flg,info)
      call PetscOptionsGetReal(PETSC_NULL_CHARACTER,"-par",              &
     &                         param,flg,info)

      
!     Set up distributed array and vectors
      call DACreate2d(MPI_COMM_WORLD,DA_NONPERIODIC,DA_STENCIL_BOX,      &
     &     mx,my,Nx,Ny,i1,i1,PETSC_NULL_INTEGER,PETSC_NULL_INTEGER,      &
     &     da,info)

!     Create vectors
      call DACreateGlobalVector(da,x,info)
      call DACreateLocalVector(da,localX,info)

!     Create Hessian
      call DAGetMatrix(da,MATAIJ,H,info)
      call MatSetOption(H,MAT_SYMMETRIC,PETSC_TRUE,info)

!     The TAO code begins here

!     Create TAO solver
      call TaoCreate(MPI_COMM_WORLD,'tao_cg',tao,info)
      call TaoApplicationCreate(MPI_COMM_WORLD,torsionapp,info)

!     Set routines for function and gradient evaluation

!     TaoAppSetObjectiveAndGradientRoutine is shortened to 31 chars to comply with some compilers
      call TaoAppSetObjectiveAndGradientRo(torsionapp,                       &
     &     FormFunctionGradient,TAO_NULL_OBJECT,info)
      call TaoAppSetHessianMat(torsionapp,H,H,info)
      call TaoAppSetHessianRoutine(torsionapp,ComputeHessian,                &
     &    TAO_NULL_OBJECT,info)

!     Set initial guess
      call FormInitialGuess(x,info)
      call TaoAppSetInitialSolutionVec(torsionapp,x,info)

!     Check for any TAO command line options
      call TaoSetOptions(torsionapp, tao,info)


!     SOLVE THE APPLICATION
      call TaoSolveApplication(torsionapp,tao,info)

!     Get information on termination
      call TaoGetSolutionStatus(tao,iter,ff,gnorm,cnorm,xdiff,           &
     &                          reason,info)
      if (reason .lt. 0) then
         print *,'TAO did not terminate successfully'
      endif

      
!     Free TAO data structures
      call TaoDestroy(tao,info)
      call TaoAppDestroy(torsionapp,info);  

  
!     Free PETSc data structures 
      call VecDestroy(x,info)
      call VecDestroy(localX,info)
      call MatDestroy(H,info)
      call DADestroy(da,info)


!     Finalize TAO and PETSc
      call PetscFinalize(info)
      call TaoFinalize(info)

      end


! ---------------------------------------------------------------------
!
!   FormInitialGuess - Computes an initial approximation to the solution.
!
!   Input Parameters:
!   X    - vector
!
!   Output Parameters:
!   X    - vector
!   info - error code
!
      subroutine FormInitialGuess(X,info)
      implicit none

! mx, my are defined in eptorsion2f.h
#include "eptorsion2f.h"

!  Input/output variables:
      Vec              X
      integer          info

!  Local variables:
      PetscInt         i, j, k, xe, ye
      PetscScalar      temp, val, hx, hy
      PetscInt         xs, ys, xm, ym
      PetscInt         gxm, gym, gxs, gys
      PetscInt         i1

      i1 = 1
      hx = 1.0d0/(mx + 1)
      hy = 1.0d0/(my + 1)

!  Get corner information
      call DAGetCorners(da,xs,ys,PETSC_NULL_INTEGER,xm,ym,               &
     &                  PETSC_NULL_INTEGER,info) 
      call DAGetGhostCorners(da,gxs,gys,PETSC_NULL_INTEGER,              &
     &                   gxm,gym,PETSC_NULL_INTEGER,info)



!  Compute initial guess over locally owned part of mesh
      xe = xs+xm
      ye = ys+ym
      do j=ys,ye-1
         temp = min(j+1,my-j)*hy
         do i=xs,xe-1
            k   = (j-gys)*gxm + i-gxs
            val = min((min(i+1,mx-i))*hx,temp)
            call VecSetValuesLocal(X,i1,k,val,ADD_VALUES,info)
         end do
      end do
      call VecAssemblyBegin(X,info)
      call VecAssemblyEnd(X,info)
      return
      end


! ---------------------------------------------------------------------
!
!  FormFunctionGradient - Evaluates gradient G(X). 
!
!  Input Parameters:
!  tao   - the TAO_SOLVER context
!  X     - input vector
!  dummy - optional user-defined context (not used here)
!    
!  Output Parameters:
!  f     - the function value at X
!  G     - vector containing the newly evaluated gradient
!  info  - error code
!
!  Notes:
!  This routine serves as a wrapper for the lower-level routine
!  "ApplicationGradient", where the actual computations are 
!  done using the standard Fortran style of treating the local
!  input vector data as an array over the local mesh.
!
      subroutine FormFunctionGradient(taoapp,X,f,G,dummy,info)
      implicit none

! da, mx, my, param, localX declared in eptorsion2f.h
#include "eptorsion2f.h"

!  Input/output variables:
      TAO_APPLICATION  taoapp
      Vec              X, G
      PetscScalar      f
      integer          info
      PetscInt         dummy

!  Declarations for use with local array:


! PETSc's VecGetArray acts differently in Fortran than it does in C.
! Calling VecGetArray((Vec) X, (PetscScalar) x_array(0:1), (PetscOffset) x_index, info)
! will return an array of doubles referenced by x_array offset by x_index.
!  i.e.,  to reference the kth element of X, use x_array(k + x_index).
! Notice that by declaring the arrays with range (0:1), we are using the C 0-indexing practice.
      PetscScalar      lx_v(0:1)
      PetscOffset      lx_i

!  Local variables:
      PetscScalar      zero, p5, area, cdiv3
      PetscScalar      val, flin, fquad,floc
      PetscScalar      v, vb, vl, vr, vt, dvdx
      PetscScalar      dvdy, hx, hy
      PetscInt         xe, ye, xsm, ysm
      PetscInt         xep, yep, i, j, k, ind
      PetscInt         xs, ys, xm, ym 
      PetscInt         gxs, gys, gxm, gym
      PetscInt         i1

      i1 = 1
      info  = 0
      cdiv3 = param/3.0d0
      zero = 0.0d0
      p5   = 0.5d0
      hx = 1.0d0/(mx + 1)
      hy = 1.0d0/(my + 1)
      fquad = zero
      flin = zero

!  Initialize gradient to zero
      call VecSet(G,zero,info)

!  Scatter ghost points to local vector
      call DAGlobalToLocalBegin(da,X,INSERT_VALUES,localX,info)
      call DAGlobalToLocalEnd(da,X,INSERT_VALUES,localX,info)


!  Get corner information
      call DAGetCorners(da,xs,ys,PETSC_NULL_INTEGER,xm,ym,               &
     &                  PETSC_NULL_INTEGER,info)
      call DAGetGhostCorners(da,gxs,gys,PETSC_NULL_INTEGER,              &
     &                   gxm,gym,PETSC_NULL_INTEGER,info)

!  Get pointer to vector data.
      call VecGetArray(localX,lx_v,lx_i,info)


!  Set local loop dimensions
      xe = xs+xm
      ye = ys+ym
      if (xs .eq. 0) then
         xsm = xs-1
      else
         xsm = xs
      endif
      if (ys .eq. 0) then
         ysm = ys-1
      else
         ysm = ys
      endif
      if (xe .eq. mx) then
         xep = xe+1
      else
         xep = xe
      endif
      if (ye .eq. my) then
         yep = ye+1
      else
         yep = ye
      endif

!     Compute local gradient contributions over the lower triangular elements
     
      do j = ysm, ye-1
         do i = xsm, xe-1
            k  = (j-gys)*gxm + i-gxs
            v  = zero
            vr = zero
            vt = zero
            if (i .ge. 0 .and. j .ge. 0)      v = lx_v(lx_i+k)
            if (i .lt. mx-1 .and. j .gt. -1) vr = lx_v(lx_i+k+1)
            if (i .gt. -1 .and. j .lt. my-1) vt = lx_v(lx_i+k+gxm)
            dvdx = (vr-v)/hx
            dvdy = (vt-v)/hy
            if (i .ne. -1 .and. j .ne. -1) then
               ind = k
               val = - dvdx/hx - dvdy/hy - cdiv3
               call VecSetValuesLocal(G,i1,k,val,ADD_VALUES,info)
            endif
            if (i .ne. mx-1 .and. j .ne. -1) then
               ind = k+1
               val =  dvdx/hx - cdiv3
               call VecSetValuesLocal(G,i1,ind,val,ADD_VALUES,info)
            endif
            if (i .ne. -1 .and. j .ne. my-1) then
              ind = k+gxm
              val = dvdy/hy - cdiv3
              call VecSetValuesLocal(G,i1,ind,val,ADD_VALUES,info)
            endif
            fquad = fquad + dvdx*dvdx + dvdy*dvdy
            flin = flin - cdiv3 * (v+vr+vt)
         end do
      end do

!     Compute local gradient contributions over the upper triangular elements

      do j = ys, yep-1
         do i = xs, xep-1
            k  = (j-gys)*gxm + i-gxs
            vb = zero
            vl = zero
            v  = zero
            if (i .lt. mx .and. j .gt. 0) vb = lx_v(lx_i+k-gxm)
            if (i .gt. 0 .and. j .lt. my) vl = lx_v(lx_i+k-1)
            if (i .lt. mx .and. j .lt. my) v = lx_v(lx_i+k)
            dvdx = (v-vl)/hx
            dvdy = (v-vb)/hy
            if (i .ne. mx .and. j .ne. 0) then
               ind = k-gxm
               val = - dvdy/hy - cdiv3
               call VecSetValuesLocal(G,i1,ind,val,ADD_VALUES,info)
            endif
            if (i .ne. 0 .and. j .ne. my) then
               ind = k-1
               val =  - dvdx/hx - cdiv3
               call VecSetValuesLocal(G,i1,ind,val,ADD_VALUES,info)
            endif
            if (i .ne. mx .and. j .ne. my) then
               ind = k
               val =  dvdx/hx + dvdy/hy - cdiv3
               call VecSetValuesLocal(G,i1,ind,val,ADD_VALUES,info)
            endif
            fquad = fquad + dvdx*dvdx + dvdy*dvdy
            flin = flin - cdiv3*(vb + vl + v)
         end do
      end do

!  Restore vector
      call VecRestoreArray(localX,lx_v,lx_i,info)
      if (info .ne. 0) print *,'VecRestoreArray'
!  Assemble gradient vector
      call VecAssemblyBegin(G,info)
      call VecAssemblyEnd(G,info)

! Scale the gradient      
      area = p5*hx*hy
      floc = area *(p5*fquad+flin)
      call VecScale(G,area,info)


!  Sum function contributions from all processes
      call MPI_Allreduce(floc,f,1,MPI_DOUBLE_PRECISION,MPI_SUM,           &
     &                   MPI_COMM_WORLD,info)
      if (info .ne. 0) print *,'MPI_Allreduce'
      call PetscLogFlops((ye-ysm)*(xe-xsm)*20+(xep-xs)*(yep-ys)*16,       &
     &                    info)



      return
      end




      subroutine ComputeHessian(taoapp, X, H, Hpre, flag, dummy, info)
      implicit none
#include "eptorsion2f.h"      
      TAO_APPLICATION taoapp
      Vec             X
      Mat             H,Hpre
      MatStructure    flag
      integer         info
      PetscInt        dummy

      
      PetscInt i,j,k
      PetscInt col(0:4),row
      PetscInt xs,xm,gxs,gxm
      PetscInt ys,ym,gys,gym
      PetscScalar v(0:4)
      PetscInt i1

      i1 = 1

!     Get local grid boundaries
      call DAGetCorners(da,xs,ys,TAO_NULL_INTEGER,xm,ym,                &
     &                TAO_NULL_INTEGER,info)
      call DAGetGhostCorners(da,gxs,gys,TAO_NULL_INTEGER,gxm,gym,        &
     &                TAO_NULL_INTEGER,info)

      do j=ys,ys+ym-1
         do i=xs,xs+xm-1
            row = (j-gys)*gxm + (i-gxs)

            k = 0
            if (j .gt. gys) then
               v(k) = -1.0d0
               col(k) = row-gxm
               k = k + 1
            endif

            if (i .gt. gxs) then
               v(k) = -1.0d0
               col(k) = row - 1
               k = k +1
            endif

            v(k) = 4.0d0
            col(k) = row
            k = k + 1

            if (i+1 .lt. gxs + gxm) then
               v(k) = -1.0d0
               col(k) = row + 1
               k = k + 1
            endif

            if (j+1 .lt. gys + gym) then
               v(k) = -1.0d0
               col(k) = row + gxm
               k = k + 1
            endif

            call MatSetValuesLocal(H,i1,row,k,col,v,INSERT_VALUES,info)
         enddo
      enddo

      
!     Assemble matrix
      call MatAssemblyBegin(H,MAT_FINAL_ASSEMBLY,info)
      call MatAssemblyEnd(H,MAT_FINAL_ASSEMBLY,info)


!     Tell the matrix we will never add a new nonzero location to the
!     matrix.  If we do it will generate an error.

      call MatSetOption(H,MAT_NEW_NONZERO_LOCATION_ERR,PETSC_TRUE,info)
      call MatSetOption(H,MAT_SYMMETRIC,PETSC_TRUE,info)


      call PetscLogFlops(9*xm*ym + 49*xm,info)

      info = 0
      return 
      end
      
               
      







