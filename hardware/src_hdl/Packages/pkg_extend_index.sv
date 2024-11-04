///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Package for Extension of Index-Compression
//	Package Name:	pkg_extend_index
//	Function:
//                  used for Extension of Index-Compression
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_extend_index;


	//// Index Width used for Sparse Operations						////
	parameter int WIDTH_INDEX					= 8;


	//// Flag for Extension											////
	//	 used for index-compression
	parameter int ExtdConfig					= 0;


    //// Extension-Enables
	`define EXTEND

	`define EXTEND_MEM

	//
	parameter int WIDTH_ICTRL					= 3;


	//// MFA Control (FSM)											////
	//	 MFA Main Control
	typedef enum logic [3:0] {
		MFA_INIT			= 4'h0,
		MFA_STOREREQ		= 4'h1,
		MFA_ATTRIBST		= 4'h2,
		MFA_SNOOPCFG		= 4'h3,
		MFA_ATTRIBDAT		= 4'h4,
		MFA_SHAREDDAT		= 4'h5,
		MFA_STORE			= 4'h6,
		MFA_ENDSTORE		= 4'h7,
		MFA_SETHEADST		= 4'h8,
		MFA_SETATTRIBST		= 4'h9,
		MFA_SETCFGST		= 4'ha,
		MFA_SETHEADLD		= 4'hb,
		MFA_SETATTRIBLD		= 4'hc,
		MFA_SETCFGLD		= 4'hd,
		MFA_RESTORE			= 4'he,
		MFA_TERM			= 4'hf
	} fsm_mfa;

	//	 Configuration Data Snoop Control
	typedef enum logic [3:0] {
		MFA_CFG_INIT		= 4'h0,
		MFA_CFG_GET_R		= 4'h1,
		MFA_CFG_DUMMY		= 4'h2,
		MFA_CFG_GET_L		= 4'h3,
		MFA_CFG_GET_S		= 4'h4,
		MFA_CFG_GET_B		= 4'h5,
		MFA_CFG_WAIT		= 4'h6,
		MFA_CFG_READ_S		= 4'h7,
		MFA_CFG_READ_L		= 4'h8
	} fsm_cfg_gen;


	//// Skip Unit													////
	//	 Control (FSM)
	typedef enum logic [1:0] {
		SKIP_INIT			= 2'b00,
		SKIP_LTA			= 2'b01,
		SKIP_LTB			= 2'b10,
		SKIP_EQ				= 2'b11
	} fsm_skip;

	//	 Initilazation Control (FSM)
	typedef enum logic [1:0] {
		SKIP_IINIT			= 2'b00,
		SKIP_NZRO			= 2'b01,
		SKIP_ZERO			= 2'b10,
		SKIP_RUN			= 2'b11
	} fsm_skip_init;

	//	 Output Control (FSM)
	typedef enum logic [1:0] {
		SKIP_NOP			= 2'b00,
		SKIP_RFTk			= 2'b01,
		SKIP_FFTk			= 2'b10,
		SKIP_POSE			= 2'b11
	} fsm_skip_ctl;

endpackage