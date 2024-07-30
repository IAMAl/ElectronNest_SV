///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Package for Link Element
//	Package Name:	pkg_link
//	Function:
//                  used for FanInLink and FanOutLink
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_link;


	//// FSM State													////
	//	 LinkIn
	typedef enum logic [2:0] {
		iD_INIT_IN			= 3'b000,
		rEAD_MY_ID_IN		= 3'b001,
		rEAD_T_ID_IN		= 3'b010,
		rEAD_F_ID_IN		= 3'b011,
		oUT_FIFO2_IN		= 3'b100,
		oUT_FIFO1_IN		= 3'b101,
		oUT_FIFO0_IN		= 3'b110,
		dEFAULT_IN			= 3'b111
	} fsm_link_in;

	typedef enum logic [1:0] {
		wRITE_My_ID			= 2'h0,
		wRITE_T_ID			= 2'h1,
		wRITE_F_ID			= 2'h2
	} fsm_link_in_id;

	//	 LinkOut
	typedef enum logic [2:0] {
		iD_INIT_OUT			= 3'h0,
		rEAD_ID_OUT			= 3'h1,
		rEAD_ATTRIB_OUT		= 3'h2,
		rEAD_ROUTE_OUT		= 3'h3,
		oUTPUT_BODY_OUT		= 3'h4
	} fsm_link_out;

	typedef enum logic [1:0] {
		rEAD_FIFO2_OUT		= 2'h0,
		rEAD_FIFO1_OUT		= 2'h1,
		rEAD_FIFO0_OUT		= 2'h2
	} fsm_link_out_id;

	typedef enum logic [2:0] {
		lINKFORNTEND_INIT	= 3'h0,
		lINKFRONTEND_ST_ID	= 3'h1,
		lINKFRONTEND_SEND_ID= 3'h2,
		lINKFRONTEND_RUN	= 3'h3,
		lINKFRONTEND_TERM	= 3'h4
	} fsm_link_out_frontend;

	typedef enum logic [1:0] {
		lINKBACKEND_INIT	= 2'h0,
		lINKBACKEND_SEND_ID	= 2'h1,
		lINKBACKEND_RUN		= 2'h2
	} fsm_link_out_backend;

endpackage