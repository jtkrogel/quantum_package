use bitmasks

BEGIN_PROVIDER [ integer, N_states ] 
 implicit none
 BEGIN_DOC
! Number of states to consider
 END_DOC
 N_states = 1
END_PROVIDER

BEGIN_PROVIDER [ integer, N_det ]
 implicit none
 BEGIN_DOC
 ! Number of determinants in the wave function
 END_DOC
 N_det = max(1,N_states)
END_PROVIDER

 BEGIN_PROVIDER [ integer(bit_kind), psi_det, (N_int,2,N_det) ]
&BEGIN_PROVIDER [ double precision, psi_coef, (N_det,N_states) ]
 implicit none
 BEGIN_DOC
 ! The wave function. Initialized with Hartree-Fock
 END_DOC

 integer, save :: ifirst = 0

 if (ifirst == 0) then
    ifirst = 1
    psi_det = 0_bit_kind
    psi_coef = 0.d0

    integer :: i
    do i=1,N_int
      psi_det(i,1,1) = HF_bitmask(i,1)
      psi_det(i,2,1) = HF_bitmask(i,2)
    enddo

    do i=1,N_states
      psi_coef(i,i) = 1.d0
    enddo
 endif

END_PROVIDER


BEGIN_PROVIDER [ integer, N_det_generators ]
 implicit none
 BEGIN_DOC
 ! Number of generator determinants in the wave function
 END_DOC
 N_det_generators = N_det
END_PROVIDER

BEGIN_PROVIDER [ integer(bit_kind), psi_generators, (N_int,2,N_det) ]
 implicit none
 BEGIN_DOC
 ! Determinants on which H is applied
 END_DOC
 psi_generators = 0_bit_kind
 integer :: i

 do i=1,N_int
   psi_generators(i,1,1) = psi_det(i,1,1)
   psi_generators(i,2,1) = psi_det(i,1,1)
 enddo

END_PROVIDER
