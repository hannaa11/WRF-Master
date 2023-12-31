!WRF:MEDIATION_LAYER:SOLVER

#define BENCH_START(A)
#define BENCH_END(A)

MODULE g_module_first_rk_step_part1

CONTAINS

  SUBROUTINE g_first_rk_step_part1 (   grid , config_flags              &
                             , moist , g_moist, moist_tend, g_moist_tend             &
                             , chem  , chem_tend                &
                             , tracer, g_tracer, tracer_tend, g_tracer_tend  &
                             , scalar , g_scalar, scalar_tend, g_scalar_tend         &
                             , fdda3d, fdda2d                   &
                             , aerod                            &
                             , ru_tendf, g_ru_tendf, rv_tendf, g_rv_tendf               &
                             , rw_tendf, g_rw_tendf, t_tendf , g_t_tendf               &
                             , ph_tendf, g_ph_tendf, mu_tendf, g_mu_tendf               &
                             , tke_tend, g_tke_tend                         &
                             , adapt_step_flag , curr_secs      &
                             , psim , psih , gz1oz0 , chklowq &
                             , cu_act_flag , hol , th_phy , g_th_phy        &
                             , pi_phy, g_pi_phy, p_phy ,g_p_phy, t_phy ,g_t_phy  &
                             , dz8w , g_dz8w, p8w ,g_p8w, t8w ,g_t8w  &
                             , ids, ide, jds, jde, kds, kde     &
                             , ims, ime, jms, jme, kms, kme     &
                             , ips, ipe, jps, jpe, kps, kpe     &
                             , imsx,imex,jmsx,jmex,kmsx,kmex    &
                             , ipsx,ipex,jpsx,jpex,kpsx,kpex    &
                             , imsy,imey,jmsy,jmey,kmsy,kmey    &
                             , ipsy,ipey,jpsy,jpey,kpsy,kpey    &
                             , k_start , k_end                  &
                             , f_flux                           &
                             , feedback_is_ready                &
                            )
    USE module_state_description
    USE module_model_constants
    USE module_domain, ONLY : domain, domain_clock_get, get_ijk_from_subgrid
    USE module_configure, ONLY : grid_config_rec_type, model_config_rec
!   USE module_radiation_driver, ONLY : pre_radiation_driver, radiation_driver
!   USE module_surface_driver, ONLY : surface_driver
!   USE module_cumulus_driver, ONLY : cumulus_driver
!   USE module_shallowcu_driver, ONLY : shallowcu_driver
!   USE module_pbl_driver, ONLY : pbl_driver
!   USE module_fr_sfire_driver_wrf, ONLY : sfire_driver_em_step
!   USE module_fddagd_driver, ONLY : fddagd_driver
!   USE module_em, ONLY : init_zero_tendency
!   USE module_force_scm
!   USE module_convtrans_prep
!   USE module_big_step_utilities_em, ONLY : phy_prep
!use module_scalar_tables
#ifdef DM_PARALLEL
    USE module_dm, ONLY : local_communicator, mytask, ntasks, ntasks_x, ntasks_y, local_communicator_periodic, wrf_dm_maxval
    USE module_comm_dm, ONLY : halo_em_phys_a_sub,halo_em_fdda_sfc_sub,halo_em_phys_a_bl_surf_sub,halo_em_phys_a_tl_sub
#endif
    USE module_utility

    USE g_module_em, ONLY : g_init_zero_tendency
    USE g_module_big_step_utilities_em, ONLY : g_phy_prep
    USE g_module_pbl_driver, ONLY : g_pbl_driver
    USE g_module_cumulus_driver, ONLY : g_cumulus_driver
    IMPLICIT NONE

    TYPE ( domain ), INTENT(INOUT) :: grid
    TYPE ( grid_config_rec_type ), INTENT(IN) :: config_flags
    TYPE(WRFU_Time)                :: currentTime

    INTEGER, INTENT(IN) :: ids, ide, jds, jde, kds, kde,     &
                           ims, ime, jms, jme, kms, kme,     &
                           ips, ipe, jps, jpe, kps, kpe,     &
                           imsx,imex,jmsx,jmex,kmsx,kmex,    &
                           ipsx,ipex,jpsx,jpex,kpsx,kpex,    &
                           imsy,imey,jmsy,jmey,kmsy,kmey,    &
                           ipsy,ipey,jpsy,jpey,kpsy,kpey


    LOGICAL ,INTENT(IN)                        :: adapt_step_flag
    REAL, INTENT(IN)                           :: curr_secs

    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_moist),INTENT(INOUT)   :: moist
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_moist),INTENT(INOUT)   :: g_moist
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_moist),INTENT(INOUT)   :: moist_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_moist),INTENT(INOUT)   :: g_moist_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_chem),INTENT(INOUT)   :: chem
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_chem),INTENT(INOUT)   :: chem_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_tracer),INTENT(INOUT)   :: tracer
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_tracer),INTENT(INOUT)   :: g_tracer
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_tracer),INTENT(INOUT)   :: tracer_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_tracer),INTENT(INOUT)   :: g_tracer_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_scalar),INTENT(INOUT)   :: scalar
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_scalar),INTENT(INOUT)   :: g_scalar
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_scalar),INTENT(INOUT)   :: scalar_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_scalar),INTENT(INOUT)   :: g_scalar_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_fdda3d),INTENT(INOUT)  :: fdda3d
    REAL    ,DIMENSION(ims:ime,1:1,jms:jme,num_fdda2d),INTENT(INOUT)      :: fdda2d
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme,num_aerod),INTENT(INOUT)   :: aerod
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: psim
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: psih
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: gz1oz0
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: chklowq
    LOGICAL ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: cu_act_flag
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT)         :: hol

    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: th_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_th_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: pi_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_pi_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: p_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_p_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: t_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_t_phy
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: dz8w
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_dz8w
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: p8w
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_p8w
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: t8w
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_t8w

    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: ru_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_ru_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: rv_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_rv_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: rw_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_rw_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: ph_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_ph_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: t_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_t_tendf
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: tke_tend
    REAL    ,DIMENSION(ims:ime,kms:kme,jms:jme), INTENT(INOUT) :: g_tke_tend

    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT) :: mu_tendf
    REAL    ,DIMENSION(ims:ime,jms:jme), INTENT(INOUT) :: g_mu_tendf

    INTEGER, INTENT(IN)                           ::  k_start, k_end
    LOGICAL, INTENT(IN), OPTIONAL                 ::  f_flux
    LOGICAL, INTENT(IN), OPTIONAL :: feedback_is_ready  ! For WRF-CMAQ coupled model, indicates feedback information is available

! Local
    REAL, DIMENSION( ims:ime, jms:jme ) :: exch_temf  ! 1/7/09 WA

    REAL, DIMENSION( ims:ime, jms:jme ) :: ht_loc, mixht
    INTEGER                             :: ij
    INTEGER  num_roof_layers
    INTEGER  num_wall_layers
    INTEGER  num_road_layers
    INTEGER  iswater
    LOGICAL  :: l_flux
    INTEGER  :: isurban
    INTEGER  rk_step
    INTEGER                         :: yr, month, day, hr, minute, sec, rc
    CHARACTER*80                    :: mesg

   INTEGER                         :: sids , side , sjds , sjde , skds , skde , &
                                      sims , sime , sjms , sjme , skms , skme , &
                                      sips , sipe , sjps , sjpe , skps , skpe

   CHARACTER (LEN=256) :: mminlu

#if ( WRF_DFI_RADAR == 1 )
    INTEGER  do_capsupress   ! =1 do CAP supress, other = don't
#endif

  CALL get_ijk_from_subgrid (  grid ,                   &
                            sids, side, sjds, sjde, skds, skde,    &
                            sims, sime, sjms, sjme, skms, skme,    &
                            sips, sipe, sjps, sjpe, skps, skpe    )

 ! initialize all tendencies to zero in order to update physics
 ! tendencies first (separate from dry dynamics).

   l_flux=.FALSE.
   if (present(f_flux)) l_flux=f_flux

    rk_step = 1

BENCH_START(g_init_zero_tend_tim)
       !$OMP PARALLEL DO   &
       !$OMP PRIVATE ( ij )

       DO ij = 1 , grid%num_tiles

         CALL wrf_debug ( 200 , ' call init_zero_tendency' )
         CALL g_init_zero_tendency(ru_tendf,  g_ru_tendf, &
                                   rv_tendf,  g_rv_tendf, &
                                   rw_tendf,  g_rw_tendf, &
                                   ph_tendf,  g_ph_tendf, &
                                   t_tendf,   g_t_tendf,  &
                                   tke_tend, g_tke_tend, &
                                   mu_tendf,  g_mu_tendf,  &
                                   moist_tend, g_moist_tend,  &
                                   scalar_tend, g_scalar_tend, &
                                   tracer_tend, g_tracer_tend, &
                                   num_tracer,                   &
                                   num_moist,num_chem,num_scalar, &
                                   rk_step,                          &
                                   ids, ide, jds, jde, kds, kde,     &
                                   ims, ime, jms, jme, kms, kme,     &
                                   grid%i_start(ij), grid%i_end(ij), &
                                   grid%j_start(ij), grid%j_end(ij), &
                                   k_start, k_end                   )

       END DO
       !$OMP END PARALLEL DO
BENCH_END(g_init_zero_tend_tim)

#ifdef DM_PARALLEL
#     include "HALO_EM_PHYS_A_TL.inc"
#endif

      !$OMP PARALLEL DO   &
      !$OMP PRIVATE ( ij )
      DO ij = 1 , grid%num_tiles

        CALL wrf_debug ( 200 , ' call g_phy_prep' )
        CALL g_phy_prep ( config_flags,                           &
                        grid%mut,grid%g_mut, grid%muu, grid%g_muu, grid%muv, grid%g_muv, &
                        grid%u_2,grid%g_u_2, grid%v_2,grid%g_v_2,             &
                        grid%p,grid%g_p, grid%pb, grid%alt,grid%g_alt,        &
                        grid%ph_2,grid%g_ph_2, grid%phb, grid%t_2,grid%g_t_2, &
                        moist,g_moist, num_moist,                             &
                        grid%rho,grid%g_rho, th_phy,g_th_phy, p_phy,g_p_phy, pi_phy,g_pi_phy, &
                        grid%u_phy,grid%g_u_phy, grid%v_phy,grid%g_v_phy,                         &
                        p8w,g_p8w, grid%t_phy,grid%g_t_phy, t8w,g_t8w, grid%z,grid%g_z, &
                        grid%z_at_w,grid%g_z_at_w, dz8w,g_dz8w,               &
                        grid%p_hyd,grid%g_p_hyd, grid%p_hyd_w,grid%g_p_hyd_w, &
                        grid%dnw,                                             &
                        grid%fnm, grid%fnp, grid%znw, grid%p_top,             &
                        ids, ide, jds, jde, kds, kde,           &
                        ims, ime, jms, jme, kms, kme,           &
                        grid%i_start(ij), grid%i_end(ij),       &
                        grid%j_start(ij), grid%j_end(ij),       &
                        k_start, k_end                         )
      ENDDO
      !$OMP END PARALLEL DO

BENCH_END(g_phy_prep_tim)

!*********
! pbl

#ifdef DM_PARALLEL
      IF ( config_flags%bl_pbl_physics .EQ. 98 ) THEN
#     include "HALO_EM_PHYS_A_BL_SURF.inc"
      ENDIF
#endif

      CALL wrf_debug ( 200 , ' call g_pbl_driver' )
BENCH_START(g_pbl_driver_tim)
      CALL g_pbl_driver(                                                              &
     &         AKHS=grid%akhs          ,AKMS=grid%akms                              &
     &        ,BL_PBL_PHYSICS=config_flags%bl_pbl_physics                           &
     &        ,BLDT=grid%bldt, CURR_SECS=curr_secs, ADAPT_STEP_FLAG=adapt_step_flag &
     &        ,BLDTACTTIME=grid%bldtacttime                                         & 
     &        ,BR=grid%br              ,CHKLOWQ=chklowq    ,CT=grid%ct              &
     &        ,DT=grid%dt              ,DX=grid%dx              ,DZ8W=dz8w          &
     &        ,EXCH_H=grid%exch_h     ,EXCH_M=grid%exch_m                           &
     &        ,FM=grid%fm         ,FHH=grid%fh                                      &
     &        ,F=grid%f  ,GRDFLX=grid%grdflx      &
     &        ,GZ1OZ0=gz1oz0      ,HFX=grid%hfx  ,HT=grid%ht                        &
     &        ,ID=grid%id         ,ITIMESTEP=grid%itimestep     ,KPBL=grid%kpbl          &
     &        ,LH=grid%lh ,LOWLYR=grid%lowlyr ,P8W=grid%p_hyd_w, P8WD=grid%g_p_hyd_w   &
     &        ,PBLH=grid%pblh, PI_PHY=pi_phy, PI_PHYD=g_pi_phy ,PSIH=psih          &
     &        ,PSIM=psim   ,P_PHY=grid%p_hyd, QFX=grid%qfx            &
     &        ,QSFC=grid%qsfc          ,QZ0=grid%qz0  ,MIXHT=mixht                  &
     &        ,RA_LW_PHYSICS=config_flags%ra_lw_physics                   &
     &        ,RHO=grid%rho            ,RQCBLTEN=grid%rqcblten  ,RQIBLTEN=grid%rqiblten  &
     &        ,RQCBLTEND=grid%g_rqcblten  ,RQIBLTEND=grid%g_rqiblten  &
     &        ,RQVBLTEN=grid%rqvblten  ,RQVBLTEND=grid%g_rqvblten                  &
     &        ,RTHBLTEN=grid%rthblten ,RTHBLTEND=grid%g_rthblten                   &
     &        ,RUBLTEN=grid%rublten, RUBLTEND=grid%g_rublten                 &
     &        ,RVBLTEN=grid%rvblten ,RVBLTEND=grid%g_rvblten   ,SNOW=grid%snow       ,STEPBL=grid%stepbl      &
     &        ,THZ0=grid%thz0          ,TH_PHY=th_phy                               &
     &        ,TSK=grid%tsk ,T_PHY=grid%t_phy, T_PHYD=grid%g_t_phy  ,UST=grid%ust       &
     &        ,U10=grid%u10 ,UZ0=grid%uz0 ,U_FRAME=grid%u_frame ,U_PHY=grid%u_phy ,U_PHYD=grid%g_u_phy &
     &        ,V10=grid%v10 ,VZ0=grid%vz0 ,V_FRAME=grid%v_frame ,V_PHY=grid%v_phy ,V_PHYD=grid%g_v_phy &
              ,T2=grid%t2 &
     &        ,WARM_RAIN=grid%warm_rain                    ,WSPD=grid%wspd          &
     &        ,XICE=grid%xice   ,XLAND=grid%xland  ,Z=grid%z ,ZD=grid%g_z      &
     &        ,ZNT=grid%znt                                                    &
! paj: topo_wind
     &        ,CTOPO=grid%ctopo,CTOPO2=grid%ctopo2                                   &
! variables added for BEP
     &          ,FRC_URB2D=grid%frc_urb2d                                                  &
     &          ,A_U_BEP=grid%a_u_bep,A_V_BEP=grid%a_v_bep,A_T_BEP=grid%a_t_bep          &
     &          ,A_Q_BEP=grid%a_q_bep                                                    &
     &          ,B_U_BEP=grid%b_u_bep,B_V_BEP=grid%b_v_bep,B_T_BEP=grid%b_t_bep          &
     &          ,B_Q_BEP=grid%b_q_bep                                                    &
     &          ,SF_BEP=grid%sf_bep,VL_BEP=grid%vl_bep                                   &
     &          ,A_E_BEP=grid%a_e_bep,B_E_BEP=grid%b_e_bep,DLG_BEP=grid%dlg_bep          &
     &          ,DL_U_BEP=grid%dl_u_bep                                                  &
     &          ,SF_SFCLAY_PHYSICS=config_flags%sf_sfclay_physics                        &
     &          ,SF_URBAN_PHYSICS=config_flags%sf_urban_physics                          &
! Bep changes end
! add tke_pbl, and turbulent fluxes
     &          ,TKE_PBL=grid%tke_pbl,EL_PBL=grid%el_pbl,WU_TUR=grid%wu_tur,WV_tur=grid%wv_tur,WT_tur=grid%wt_tur,WQ_tur=grid%wq_tur   &
! end add tke_pbl, and turbulent fluxes
     &        ,IDS=ids,IDE=ide, JDS=jds,JDE=jde, KDS=kds,KDE=kde          &
     &        ,IMS=ims,IME=ime, JMS=jms,JME=jme, KMS=kms,KME=kme          &
     &        ,I_START=grid%i_start,I_END=min(grid%i_end, ide-1)          &
     &        ,J_START=grid%j_start,J_END=min(grid%j_end, jde-1)          &
     &        ,KTS=k_start, KTE=min(k_end,kde-1)                          &
     &        ,NUM_TILES=grid%num_tiles                                   &
          ! Variables Required by ACM PBL  - jp
     &        ,ZNU=grid%znu,ZNW=grid%znw,MUT=grid%mut,P_TOP=grid%p_top    &
     &        ,MUTD=grid%g_mut                                           &
          ! Variables required by TEMF PBL - WA 9/9/08
              ,te_temf=grid%te_temf                                 &
              ,kh_temf=grid%kh_temf,km_temf=grid%km_temf            &
              ,shf_temf=grid%shf_temf,qf_temf=grid%qf_temf          &
              ,uw_temf=grid%uw_temf,vw_temf=grid%vw_temf            &
              ,hd_temf=grid%hd_temf,lcl_temf=grid%lcl_temf          &
              ,wupd_temf=grid%wupd_temf,mf_temf=grid%mf_temf          &
              ,thup_temf=grid%thup_temf,qtup_temf=grid%qtup_temf          &
              ,qlup_temf=grid%qlup_temf          &
              ,cf3d_temf=grid%cf3d_temf,cfm_temf=grid%cfm_temf          &
              ,hct_temf=grid%hct_temf                               &
              ,flhc=grid%flhc,flqc=grid%flqc                        &
              ,exch_temf=exch_temf                      &
          ! optional
     &        ,QV_CURR=moist(ims,kms,jms,P_QV), F_QV=F_QV                 &
     &        ,QV_CURRD=g_moist(ims,kms,jms,P_QV)                        &
     &        ,QC_CURR=moist(ims,kms,jms,P_QC), F_QC=F_QC                 &
     &        ,QR_CURR=moist(ims,kms,jms,P_QR), F_QR=F_QR                 &
     &        ,QI_CURR=moist(ims,kms,jms,P_QI), F_QI=F_QI                 &
     &        ,QS_CURR=moist(ims,kms,jms,P_QS), F_QS=F_QS                 &
     &        ,QG_CURR=moist(ims,kms,jms,P_QG), F_QG=F_QG                 &
     &        ,HOL=HOL, MOL=grid%mol, REGIME=grid%REGIME                  &
!mynn mp
     &        ,QKE=scalar(ims,kms,jms,P_qke_adv), tsq=grid%tsq, qsq=grid%qsq  &
     &        ,cov=grid%cov                                               &
     &        ,DQKE=grid%dqke,QWT=grid%qWT                                &
     &        ,QSHEAR=grid%qSHEAR,QBUOY=grid%qBUOY,QDISS=grid%qDISS       &
     &        ,tke_budget=config_flags%tke_budget                         &
     &        ,rmol=grid%rmol, ch=grid%ch                                 &
     &        ,qcg=grid%qcg, grav_settling=config_flags%grav_settling     &
!GWD for ARW
     &        ,GWD_OPT=config_flags%gwd_opt &
     &        ,DTAUX3D=grid%dtaux3d,DTAUY3D=grid%dtauy3d &
     &        ,DTAUX3DD=grid%g_dtaux3d,DTAUY3DD=grid%g_dtauy3d &
     &        ,DUSFCG=grid%dusfcg,DVSFCG=grid%dvsfcg &
     &        ,DUSFCGD=grid%g_dusfcg,DVSFCGD=grid%g_dvsfcg &
     &        ,VAR2D=grid%var2d,OC12D=grid%oc12d     &
     &        ,OA1=grid%oa1,OA2=grid%oa2,OA3=grid%oa3,OA4=grid%oa4        &
     &        ,OL1=grid%ol1,OL2=grid%ol2,OL3=grid%ol3,OL4=grid%ol4        &
     &        ,MFSHCONV=grid%mfshconv                                     & 
     &        ,MASSFLUX_EDKF=grid%massflux_EDKF                           & 
     &        ,ENTR_EDKF=grid%entr_EDKF, DETR_EDKF=grid%detr_EDKF         &
     &        ,THL_UP=grid%thl_up                                         &
     &        ,THV_UP=grid%thv_up, RT_UP=grid%rt_up ,RV_UP=grid%rv_up     &
     &        ,RC_UP=grid%rc_up, U_UP=grid% u_up, V_UP=grid%v_up          &
     &        ,FRAC_UP=grid%frac_up, RC_MF=grid%RC_MF                     &
! For Wind Turbine Drag Parameterizations
     &        ,phb=grid%phb                                               &
     &        ,XLAT_U=grid%xlat_u,XLONG_U=grid%xlong_u                    &
!Variables required for camuwpbl scheme
     &        ,Z_AT_W=grid%z_at_w,CLDFRA=grid%cldfra                      &
     &        ,RTHRATENLW=grid%rthratenlw,TAURESX2D=grid%tauresx2d        &
     &        ,TAURESY2D=grid%tauresy2d                                   &
     &        ,TPERT2D=grid%tpert2d,QPERT2D=grid%qpert2d                  &
     &        ,WPERT2D=grid%wpert2d                                       &
     &        ,XLAT_V=grid%xlat_v,XLONG_V=grid%xlong_v                    &
     &        )
                                                         

BENCH_END(g_pbl_driver_tim)


! cumulus para.

      CALL wrf_debug ( 200 , ' call g_cumulus_driver' )

BENCH_START(g_cu_driver_tim)
      CALL g_cumulus_driver(grid                                             &
                 ! Prognostic variables
     &             ,U=grid%u_phy, V=grid%v_phy, TH=th_phy, THD=g_th_phy, T=grid%t_phy, TD=grid%g_t_phy  &
     &             ,W=grid%w_2, P=grid%p_hyd, PD=grid%g_p_hyd, PI=pi_phy, RHO=grid%rho, RHOD=grid%g_rho &
                 ! Other arguments
     &             ,ITIMESTEP=grid%itimestep ,DT=grid%dt      ,DX=grid%dx              &
     &             ,CUDT=grid%cudt,CURR_SECS=curr_secs,ADAPT_STEP_FLAG=adapt_step_flag &
     &             ,CUDTACTTIME=grid%cudtacttime                                       &
     &             ,RAINC=grid%rainc   ,RAINCV=grid%raincv   ,PRATEC=grid%pratec       &
     &             ,RAINCVD=grid%g_raincv, PRATECD=grid%g_pratec                       &
     &             ,NCA=grid%nca                                                       &
     &             ,HTOP=grid%cutop     ,HBOT=grid%cubot       ,KPBL=grid%kpbl         &
     &             ,Z=grid%z ,Z_AT_W=grid%z_at_w ,MAVAIL=grid%mavail ,PBLH=grid%pblh   &
     &             ,DZ8W=dz8w     ,P8W=grid%p_hyd_w, PSFC=grid%psfc, TSK=grid%tsk      &
     &             ,ZD=grid%g_z, DZ8WD=g_dz8w                                        &
     &             ,TKE_PBL=grid%tke_pbl, UST=grid%ust                                 &
     &             ,W0AVG=grid%w0avg   ,STEPCU=grid%stepcu                             &
     &             ,CLDEFI=grid%cldefi ,LOWLYR=grid%lowlyr ,XLAND=grid%xland           &
     &             ,APR_GR=grid%apr_gr ,APR_W=grid%apr_w   ,APR_MC=grid%apr_mc         &
     &             ,APR_ST=grid%apr_st ,APR_AS=grid%apr_as ,APR_CAPMA=grid%apr_capma   &
     &             ,APR_CAPME=grid%apr_capme          ,APR_CAPMI=grid%apr_capmi     &
     &             ,MASS_FLUX=grid%mass_flux          ,XF_ENS=grid%xf_ens           &
     &             ,PR_ENS=grid%pr_ens ,HT=grid%ht,EDT_OUT=grid%edt_out             &
     &             ,imomentum=grid%imomentum,clos_choice=grid%clos_choice           &
     &             ,ishallow=config_flags%ishallow                                  &
     &             ,cugd_tten=grid%cugd_tten,cugd_qvten=grid%cugd_qvten,cugd_qcten=grid%cugd_qcten   &
     &             ,cugd_ttens=grid%cugd_ttens,cugd_qvtens=grid%cugd_qvtens   &
     &             ,ENSDIM=config_flags%ensdim ,MAXIENS=config_flags%maxiens ,MAXENS=config_flags%maxens         &
     &             ,MAXENS2=config_flags%maxens2 ,MAXENS3=config_flags%maxens3       &
     &             ,CU_ACT_FLAG=cu_act_flag   ,WARM_RAIN=grid%warm_rain   &
     &             ,HFX=grid%hfx, QFX=grid%qfx                            &
     &             ,CLDFRA=grid%cldfra, TPERT2D=grid%tpert2d              &
     &             ,GSW=grid%gsw,cugd_avedx=config_flags%cugd_avedx       &
     &             ,k22_shallow=grid%k22_shallow,kbcon_shallow=grid%kbcon_shallow &
     &             ,ktop_shallow=grid%ktop_shallow,xmb_shallow=grid%xmb_shallow   &
     &             ,PERIODIC_X=(config_flags%polar .OR. config_flags%periodic_x)  &
     &             ,PERIODIC_Y=config_flags%periodic_y                    &
                 ! Zhang-McFarlane outputs
     &             ,CAPE=grid%cape ,ZMMU=grid%zmmu ,ZMMD=grid%zmmd        &
     &             ,ZMDT=grid%zmdt ,ZMDQ=grid%zmdq                        &
     &             ,DLF=grid%dlf, RLIQ=grid%rliq                          &
     &             ,PCONVB=grid%pconvb, PCONVT=grid%pconvt                &
     &             ,EVAPTZM=grid%evaptzm, FZSNTZM=grid%fzsntzm, EVSNTZM=grid%evsntzm     &
     &             ,EVAPQZM=grid%evapqzm, ZMFLXPRC=grid%zmflxprc          &
     &             ,ZMFLXSNW=grid%zmflxsnw, ZMNTPRPD=grid%zmntprpd        &
     &             ,ZMNTSNPD=grid%zmntsnpd, ZMEIHEAT=grid%zmeiheat        &
     &             ,CMFMC=grid%cmfmc, CMFMCDZM=grid%cmfmcdzm              &
     &             ,PRECCDZM=grid%preccdzm, PRECZ=grid%precz              &
     &             ,ZMMTU=grid%zmmtu, ZMMTV=grid%zmmtv  &
     &             ,ZMUPGU=grid%zmupgu, ZMUPGD=grid%zmupgd                &
     &             ,ZMVPGU=grid%zmvpgu, ZMVPGD=grid%zmvpgd                &
     &             ,ZMICUU=grid%zmicuu, ZMICUD=grid%zmicud                &
     &             ,ZMICVU=grid%zmicvu, ZMICVD=grid%zmicvd                &
     &             ,ZMDICE=grid%zmdice, ZMDLIQ=grid%zmdliq                &
                 ! Selection flag
     &             ,pgcon=config_flags%sas_pgcon                          &
     &             ,CU_PHYSICS=config_flags%cu_physics                    &
     &             ,BL_PBL_PHYSICS=config_flags%bl_pbl_physics            &
     &             ,SF_SFCLAY_PHYSICS=config_flags%sf_sfclay_physics      &
     &             ,KFETA_TRIGGER=config_flags%kfeta_trigger              &
                 ! Dimension arguments
     &             ,IDS=ids,IDE=ide, JDS=jds,JDE=jde, KDS=kds,KDE=kde     &
     &             ,IMS=ims,IME=ime, JMS=jms,JME=jme, KMS=kms,KME=kme     &
     &             ,IPS=ips,IPE=ipe, JPS=jps,JPE=jpe, KPS=kps,KPE=kpe     &
     &             ,I_START=grid%i_start,I_END=min(grid%i_end, ide-1)     &
     &             ,J_START=grid%j_start,J_END=min(grid%j_end, jde-1)     &
     &             ,KTS=k_start, KTE=min(k_end,kde-1)                     &
     &             ,NUM_TILES=grid%num_tiles                              &
                 ! Moisture tendency arguments
     &             ,RQVCUTEN=grid%rqvcuten , RQCCUTEN=grid%rqccuten       &
     &             ,RQVCUTEND=grid%g_rqvcuten                            &
     &             ,RQSCUTEN=grid%rqscuten , RQICUTEN=grid%rqicuten       &
     &             ,RQRCUTEN=grid%rqrcuten                                &
     &             ,RQVBLTEN=grid%rqvblten , RQVFTEN=grid%rqvften         &
                 ! Other tendency arguments
     &             ,RTHRATEN=grid%rthraten , RTHBLTEN=grid%rthblten       &
     &             ,RUCUTEN=grid%rucuten   , RVCUTEN=grid%rvcuten         &
     &             ,RTHCUTEN=grid%rthcuten , RTHFTEN=grid%rthften         &
     &             ,RTHCUTEND=grid%g_rthcuten                            &
                 ! Moisture tracer arguments
     &             ,QV_CURR=moist(ims,kms,jms,P_QV), F_QV=F_QV            &
     &             ,QV_CURRD=g_moist(ims,kms,jms,P_QV)                   &
     &             ,QC_CURR=moist(ims,kms,jms,P_QC), F_QC=F_QC            &
     &             ,QR_CURR=moist(ims,kms,jms,P_QR), F_QR=F_QR            &
     &             ,QI_CURR=moist(ims,kms,jms,P_QI), F_QI=F_QI            &
     &             ,QS_CURR=moist(ims,kms,jms,P_QS), F_QS=F_QS            &
     &             ,QG_CURR=moist(ims,kms,jms,P_QG), F_QG=F_QG            &
! Variables for Tiedtke and NSAS schemes
     &             ,ZNU=grid%znu                                          &
     &             ,MP_PHYSICS=config_flags%mp_physics                    &
     &             ,GD_CLOUD=grid%GD_CLOUD,GD_CLOUD2=grid%GD_CLOUD2       &
     &             ,cfu1=grid%cfu1,cfd1=grid%cfd1,dfu1=grid%dfu1,efu1=grid%efu1,dfd1=grid%dfd1,efd1=grid%efd1,f_flux=l_flux)
BENCH_END(g_cu_driver_tim)
!

  END SUBROUTINE g_first_rk_step_part1

END MODULE g_module_first_rk_step_part1
