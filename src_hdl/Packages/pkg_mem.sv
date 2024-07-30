///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Package for Load/Store Sequences
//	Package Name:	pkg_mem
//	Function:
//                  used for CRAM_Ld and CRAM_St
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_mem;

	`define NumWordsLength;
	`define NumWordsStride;
	`define NumWordsBase;

	parameter int SIZE_CRAM			= 256;
	parameter int WIDTH_ADDR		= $clog2(SIZE_CRAM);
	parameter int DEPTH_FIFO_LD		= 8;
	parameter int DEPTH_FIFO_LDST	= 8;


	//// Load Unit													////
	//	 Front-End Main Control (FSM)
	typedef enum logic [3:0] {
		lD_FRONTEND_INIT	= 4'h0,
		lD_FRONTEND_ID		= 4'h1,
		lD_FRONTEND_ATTRIB	= 4'h2,
		lD_FRONTEND_RCFG	= 4'h3,
		lD_FRONTEND_LENGTH	= 4'h4,
		lD_FRONTEND_STRIDE	= 4'h5,
		lD_FRONTEND_BASE	= 4'h6,
		lD_FRONTEND_MyID	= 4'h7,
		lD_FRONTEND_ID_T	= 4'h8,
		lD_FRONTEND_ID_F	= 4'h9,
		lD_FRONTEND_BYPASS	= 4'ha,
		lD_FRONTEND_LOAD	= 4'hb,
		lD_FRONTEND_IACCESS	= 4'hc,
		lD_FRONTEND_IEND	= 4'hd
	} fsm_ldfe;

	//	 Back-End Main Control (FSM)
	typedef enum logic [3:0] {
		lD_BACKEND_INIT		= 4'h0,
		lD_BACKEND_ID		= 4'h1,
		lD_BACKEND_ATTRIB	= 4'h2,
		lD_BACKEND_SHARED	= 4'h3,
		lD_BACKEND_FIRST_LD	= 4'h4,
		lD_BACKEND_LOAD		= 4'h5,
		lD_BACKEND_CHK_ID	= 4'h6,
		lD_BACKEND_RENAME	= 4'h7,
		lD_BACKEND_END_TEST = 4'h8
	} fsm_ldbe;

	typedef enum logic [2:0] {
		lD_BLOCK_INIT		= 3'h0,
		lD_BLOCK_MYID		= 3'h1,
		lD_BLOCK_ID			= 3'h2,
		lD_BLOCK_ATTRIB		= 3'h3,
		lD_BLOCK_BLOCK		= 3'h4,
		lD_BLOCK_TAIL		= 3'h5
	} fsm_ldbe_block;

	typedef enum logic [3:0] {
		lD_LOAD_INIT		= 4'h0,
		lD_LOAD_SET_RCFG	= 4'h1,
		lD_LOAD_SET_ATTRIB	= 4'h2,
		lD_LOAD_LOAD		= 4'h3,
		lD_LOAD_TAIL		= 4'h4,
		lD_LOAD_END			= 4'h5
	} fsm_ldbe_load;

	//	 Indirect Access
	typedef enum logic [4:0] {
		lOAD_INIT_LD		= 5'h00,
		lOAD_TAG_LD			= 5'h01,
		lOAD_DST_LD			= 5'h02,
		lOAD_SET_ROUTE_X_LD	= 5'h03,
		sEND_RATTRIB_X_LD	= 5'h04,
		sEND_ROUTE_X_LD		= 5'h05,
		lOAD_SET_ROUTE_Y_LD	= 5'h06,
		sEND_RATTRIB_Y_LD	= 5'h07,
		sEND_ROUTE_Y_LD		= 5'h08,
		sEND_ATTRIB_R_LD	= 5'h09,
		sEND_ROUTE_R_LD		= 5'h0a,
		sEND_ATTRIB_A_LD	= 5'h0b,
		sEND_ROUTE_A_LD		= 5'h0c,
		sEND_RCONFIG_LD		= 5'h0d,
		sEND_RCATTRIB_X_LD	= 5'h0e,
		sEND_RCROUTE_X_LD	= 5'h0f,
		sEND_RCATTRIB_Y_LD	= 5'h10,
		sEND_RCROUTE_Y_LD	= 5'h11,
		sEND_RETARGET_LD	= 5'h12,
		sEND_ATTRIB_C_LD	= 5'h13,
		sEND_ROUTE_C_LD		= 5'h14

	} fsm_indirect;


	//// Store Unit													////
	//	 Main Control (FSM)
	typedef enum logic [2:0] {
		iNIT_CTRL_ST		= 3'h0,
		gET_ATTRIB_ST		= 3'h1,
		gET_CONFIG_ST		= 3'h2,
		gET_ATTRIB2_ST		= 3'h3,
		rEADY_ST			= 3'h4,
		aCTIVE_ST			= 3'h5
	} fsm_stcore;

	//	 Store IDs
	typedef enum logic [1:0] {
		iNIT_ST_ID			= 2'h0,
		sT_T_ID				= 2'h1,
		sT_F_ID				= 2'h2
	} fsm_storeids;

	//	 Set Configuration
	typedef enum logic [2:0] {
		iNIT_CONFIG_ST		= 3'h0,
		sET_CONFIG_ST		= 3'h1,
		sET_LENGTH_ST		= 3'h2,
		sET_STRIDE_ST		= 3'h3,
		sET_BASE_ST			= 3'h4
	} fsm_config_st;

endpackage