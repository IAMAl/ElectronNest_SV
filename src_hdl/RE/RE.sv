///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Storage Element
//	Module Name:	RE
//	Function:
//					Retiming Unit
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RE
	import  pkg_en::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int WIDTH_ADDR		= 8,
	parameter int NUM_CRAM			= 1,
	parameter int NUM_LINK			= 5,
	parameter int NUM_CHANNEL		= 1,
	parameter int WIDTH_LENGTH		= 10,
	parameter int DEPTH_FIFO		= 12,
	parameter int WIDTH_UNIT		= 8,
	parameter int NUM_MEMUNIT		= 4,
	parameter int SIZE_CRAM			= 256,
	parameter int ExtdConfig		= 0
)(
	input							clock,
	input							reset,
	input	FTk_cl_t				I_FTk,							//Input Forward-Tokens
	output	BTk_cl_t				O_BTk,							//Output Backward-Tokens
	output	FTk_cl_t				O_FTk,							//Output Forward-Tokens
	input	BTk_cl_t				I_BTk,							//Input Backward-Tokens
	input	bit2_cl_t				I_InC,							//Input Cond Signal
	output	bit2_cl_t				O_InC							//Output Cond Signal
);


	//// Module I/O Connection										////
	FTk_cl_t					LI_P_FTk;
	BTk_cl_t					LI_P_BTk;
	FTk_cl_t					P_LO_FTk;
	BTk_cl_t					P_LO_BTk;


	//// LE <-> LE Connection										////
	FTk_cfml_t					LO_M_FTk;
	BTk_cfml_t					LO_M_BTk;
	FTk_cfml_t					M_LI_FTk;
	BTk_cfml_t					M_LI_BTk;

	bit2_cfm_t					F_InC;
	bit2_cfm_t					B_InC;


	//// LE -> MB-In												////
	FTk_fm_t					M_B_FTk;
	BTk_fm_t					M_B_BTk;
	FTk_fm_t					M_F_FTk;
	BTk_fm_t					M_F_BTk;


	//// MB -> CRAM													////
	FTk_re_t					F_M_FTk;
	BTk_re_t					F_M_BTk;
	FTk_re_t					B_M_FTk;
	BTk_re_t					B_M_BTk;

	bit2_cmem_t					F_InC_M;
	bit2_cmem_t					B_InC_M;

	assign F_InC_M			= '0;


	//// Module I/O													////
	for ( genvar i = 0; i < NUM_LINK; ++i ) begin: g_port_connect
		for ( genvar k = 0; k < NUM_CHANNEL; ++k ) begin
			assign O_FTk[ i ][ k ]		= LI_P_FTk[ i ][ k ];
			assign O_BTk[ i ][ k ]		= P_LO_BTk[ i ][ k ];

			assign P_LO_FTk[ i ][ k ]	= I_FTk[ i ][ k ];
			assign LI_P_BTk[ i ][ k ]	= I_BTk[ i ][ k ];
		end
	end


	//// Fan-Out to Fan-In											////
	for ( genvar i = 0; i < NUM_LINK; ++i ) begin: g_out_to_in_connect
		for ( genvar j = 0; j < NUM_LINK; ++j ) begin
			for ( genvar k = 0; k < NUM_CHANNEL; ++k ) begin
				assign M_LI_FTk[ i ][ j ][ k ] = LO_M_FTk[ j ][ i ][ k ];
				assign LO_M_BTk[ j ][ i ][ k ] = M_LI_BTk[ i ][ j ][ k ];
			end
		end
	end


	//// Fan-Out to Fan-In											////
	for ( genvar i = 0; i < NUM_CRAM; ++i ) begin
		for ( genvar j = 0; j < NUM_LINK; ++j ) begin
			for ( genvar k = 0; k < NUM_CHANNEL; ++k ) begin: g_out_to_in_module
				assign M_B_FTk[ i ][ j*NUM_CHANNEL+k ]	= LO_M_FTk[ j ][ NUM_LINK+i ][ k ];
				assign LO_M_BTk[ j ][ NUM_LINK+i ][ k ]	= M_B_BTk[ i ][ j*NUM_CHANNEL+k ];
			end
		end
	end


	//// CRAM <-> LE												////
	for ( genvar i = 0; i < NUM_CRAM; ++i ) begin: g_cram_le
		for ( genvar j = 0; j < NUM_LINK; ++j ) begin
			for ( genvar k = 0; k < NUM_CHANNEL; ++k ) begin
				assign M_LI_FTk[ j ][ NUM_LINK+i ][ k ]	= M_F_FTk[ i ][ j*NUM_CHANNEL+k ];
				assign M_F_BTk[ i ][ j*NUM_CHANNEL+k ]	= M_LI_BTk[ j ][ NUM_LINK+i ][ k ];
			end
		end
	end


	for ( genvar l = 0; l < NUM_LINK; ++l ) begin: g_link_re
		FanOut_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	NUM_CHANNEL					),
			.NUM_LINK(		NUM_M						),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.DEPTH_FIFO(	DEPTH_FIFO					),
			.TYPE_FTK(		FTk_cfm_t					),
			.TYPE_BTK(		BTk_cfm_t					),
			.TYPE_BITS(		bit_cfm_t					)
			) Link_Out
			(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			P_LO_FTk[ l ]				),
			.O_BTk(			P_LO_BTk[ l ]				),
			.O_FTk(			LO_M_FTk[ l ]				),
			.I_BTk(			LO_M_BTk[ l ]				),
			.O_InC(			O_InC[ l ]					)
		);

		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	NUM_CHANNEL					),
			.NUM_LINK(		NUM_M						),
			.TYPE_FTK(		FTk_cfm_t					),
			.TYPE_BTK(		BTk_cfm_t					),
			.TYPE_FTKM(		FTk_cfm_t					),
			.TYPE_BTKM(		BTk_cfm_t					),
			.TYPE_DATA(		data_fmc_t					),
			.TYPE_LOGN(		log_re_t					),
			.TYPE_BITS(		bit_fmc_t					)
			) Link_In
			(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			M_LI_FTk[ l ]				),
			.O_BTk(			M_LI_BTk[ l ]				),
			.O_FTk(			LI_P_FTk[ l ]				),
			.I_BTk(			LI_P_BTk[ l ]				),
			.I_InC(			I_InC[ l ]					)
		);
	end


	for ( genvar m = 0; m < NUM_CRAM; ++m ) begin: g_mem
		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK (		NUM_F						),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_FTKM(		FTk_1f_t					),
			.TYPE_BTKM(		BTk_1f_t					),
			.TYPE_DATA(		data_f1_t					),
			.TYPE_LOGN(		log_f1_t					),
			.TYPE_BITS(		bit_f1_t					),
			.EN_CLR_DIRTY(	0							),
			.TYPE_O_FTK(	FTk_1_t						),
			.TYPE_I_BTK(	BTk_1_t						)
		) MB_InData
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			M_B_FTk[ m ]				),
			.O_BTk(			M_B_BTk[ m ]				),
			.O_FTk(			F_M_FTk[ m ]				),
			.I_BTk(			F_M_BTk[ m ]				),
			.I_InC(			F_InC_M[ m ]				)
		);

		FanOut_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK(		NUM_F						),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.DEPTH_FIFO(	DEPTH_FIFO					),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_BITS(		bit_f1_t					),
			.TYPE_I_FTK(	FTk_1_t						),
			.TYPE_O_BTK(	BTk_1_t						)
		) MB_OutDat
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			B_M_FTk[ m ]				),
			.O_BTk(			B_M_BTk[ m ]				),
			.O_FTk(			M_F_FTk[ m ]				),
			.I_BTk(			M_F_BTk[ m ]				),
			.O_InC(			B_InC_M[ m ]				)
		);

		CRAM #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.WIDTH_ADDR(	WIDTH_ADDR					),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.WIDTH_UNIT(	WIDTH_UNIT					),
			.NUM_MEMUNIT(	NUM_MEMUNIT					),
			.SIZE_CRAM(		SIZE_CRAM					),
			.ExtdConfig(	ExtdConfig					)
		) CRAM
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_Boot(		1'b0						),
			.I_FTk(			F_M_FTk[ m ]				),
			.O_BTk(			F_M_BTk[ m ]				),
			.O_FTk(			B_M_FTk[ m ]				),
			.I_BTk(			B_M_BTk[ m ]				)
		);
	end

endmodule
