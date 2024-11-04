///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Compute Element
//	Module Name:	PE
//	Function:
//					Element in Grid Array
//					Operate ALU
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module PE
	import  pkg_en::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int NUM_ALU			= 1,
	parameter int NUM_LINK			= 5,
	parameter int NUM_CHANNEL		= 1,
	parameter int WIDTH_LENGTH		= 10,
	parameter int DEPTH_FIFO		= 16,
	parameter int WIDTH_OPCODE		= 8,
	parameter int WIDTH_CONSTANT	= 8,
	parameter int NUM_WORKER		= 4
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


	localparam int NUM_LINKC	= NUM_F;
	localparam int NUM_LINKA	= NUM_LINK + NUM_ALU * 3;
	localparam int NUM_LINKD	= NUM_LINK + NUM_ALU * 1;


	 //// Extern IO and Links										////
	FTk_cl_t					P_LO_FTk;
	BTk_cl_t					P_LO_BTk;
	FTk_cl_t					LI_P_FTk;
	BTk_cl_t					LI_P_BTk;


	//// Link-Element												////
	FTk_cfa3l_t					LO_A_FTk;
	BTk_cfa3l_t					LO_A_BTk;
	FTk_cfa1l_t					A_LI_FTk;
	BTk_cfa1l_t					A_LI_BTk;

	bit_cla_t					F_InC;
	bit_cla_t					B_InC;


	//// LE <-> ALU-In												////
	FTk_fa3_t					F_ALU_FTk;
	BTk_fa3_t					F_ALU_BTk;
	FTk_a1f_t					B_ALU_FTk;
	BTk_a1f_t					B_ALU_BTk;


	//// ALU-In <-> ALU												////
	FTk_ac_t					FA_FTk_A;
	BTk_ac_t					FA_BTk_A;
	FTk_ac_t					FA_FTk_B;
	BTk_ac_t					FA_BTk_B;
	FTk_ac_t					FA_FTk_C;
	BTk_ac_t					FA_BTk_C;

	//// ALU-In <-> LE												////
	FTk_ac_t					BB_FTk;
	BTk_ac_t					BB_BTk;


	bit2_a_t					F_InC_A;
	bit2_a_t					F_InC_B;
	bit2_a_t					F_InC_C;


	for ( genvar l = 0; l < NUM_LINK; ++l ) begin : g_link_pe
		FanOut_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	NUM_CHANNEL					),
			.NUM_LINK(		NUM_LINKA					),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.DEPTH_FIFO(	DEPTH_FIFO					),
			.TYPE_FTK(		FTk_cfa3_t					),
			.TYPE_BTK(		BTk_cfa3_t					),
			.TYPE_BITS(		bit_cla3_t					)
			) Link_Out
			(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			P_LO_FTk[ l ]				),
			.O_BTk(			P_LO_BTk[ l ]				),
			.O_FTk(			LO_A_FTk[ l ]				),
			.I_BTk(			LO_A_BTk[ l ]				),
			.O_InC(			O_InC[ l ]					)
		);

		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	NUM_CHANNEL					),
			.NUM_LINK(		NUM_LINKD					),
			.TYPE_FTK(		FTk_cfa1_t					),
			.TYPE_BTK(		BTk_cfa1_t					),
			.TYPE_FTKM(		FTk_cfa1_t					),
			.TYPE_BTKM(		BTk_cfa1_t					),
			.TYPE_DATA(		data_fa1c_t					),
			.TYPE_LOGN(		log_pe_t					),
			.TYPE_BITS(		bit_fa1c_t					)
			) Link_In
			(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			A_LI_FTk[ l ]				),
			.O_BTk(			A_LI_BTk[ l ]				),
			.O_FTk(			LI_P_FTk[ l ]				),
			.I_BTk(			LI_P_BTk[ l ]				),
			.I_InC(			I_InC[ l ]					)
		);
	end


	//// Module I/O	Connection										////
	for ( genvar l = 0; l < NUM_LINK; ++l ) begin: g_port_connect
		for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin
			assign P_LO_FTk[ l ][ c ]	= I_FTk[ l ][ c ];
			assign O_BTk[ l ][ c ]		= P_LO_BTk[ l ][ c ];

			assign O_FTk[ l ][ c ]		= LI_P_FTk[ l ][ c ];
			assign LI_P_BTk[ l ][ c ]	= I_BTk[ l ][ c ];
		end
	end


	//// LE <-> LE Connection										////
	for ( genvar l = 0; l < NUM_LINK; ++l ) begin: g_le_le
		for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin
			for ( genvar ll = 0; ll < NUM_LINK; ++ll ) begin
				assign A_LI_FTk[ l ][ ll ][ c ]	= LO_A_FTk[ ll ][ l ][ c ];
				assign LO_A_BTk[ ll ][ l ][ c ] = A_LI_BTk[ l ][ ll ][ c ];
			end
		end
	end


	//// ALU <-> LE Connection										////
	for ( genvar a = 0; a < NUM_ALU; ++a ) begin: g_ralu_le
		for ( genvar l = 0; l < NUM_LINK; ++l ) begin
			for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin
				//ALU-Fan-Out to Fan-In
				assign A_LI_FTk[ l ][ NUM_LINK+a ][ c ] = B_ALU_FTk[ a ][ NUM_CHANNEL*l+c ];
				assign B_ALU_BTk[ a ][ NUM_CHANNEL*l+c ] = A_LI_BTk[ l ][ NUM_LINK+a ][ c ];

				//Fan-Out to ALU-Fan-In
				assign F_ALU_FTk[ 3*a+0 ][ NUM_CHANNEL*l+c ] = LO_A_FTk[ l ][ NUM_LINK+NUM_ALU*0+a ][ c ];
				assign LO_A_BTk[ l ][ NUM_LINK+NUM_ALU*0+a ][ c ] = F_ALU_BTk[ 3*a+0 ][ NUM_CHANNEL*l+c ];

				assign F_ALU_FTk[ 3*a+1 ][ NUM_CHANNEL*l+c ] = LO_A_FTk[ l ][ NUM_LINK+NUM_ALU*1+a ][ c ];
				assign LO_A_BTk[ l ][ NUM_LINK+NUM_ALU*1+a ][ c ] = F_ALU_BTk[ 3*a+1 ][ NUM_CHANNEL*l+c ];

				assign F_ALU_FTk[ 3*a+2 ][ NUM_CHANNEL*l+c ] = LO_A_FTk[ l ][ NUM_LINK+NUM_ALU*2+a ][ c ];
				assign LO_A_BTk[ l ][ NUM_LINK+NUM_ALU*2+a ][ c ] = F_ALU_BTk[ 3*a+2 ][ NUM_CHANNEL*l+c ];
			end
		end
	end


	for ( genvar a = 0; a < NUM_ALU; ++a ) begin: g_alu
		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK(		NUM_LINKC					),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_FTKM(		FTk_1f_t					),
			.TYPE_BTKM(		BTk_1f_t					),
			.TYPE_DATA(		data_f1_t					),
			.TYPE_LOGN(		log_f1_t					),
			.TYPE_BITS(		bit_f1_t					),
			.TYPE_O_FTK(	FTk_1_t						),
			.TYPE_I_BTK(	BTk_1_t						)
		) ALU_InA
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			F_ALU_FTk[ 3*a+0 ]			),
			.O_BTk(			F_ALU_BTk[ 3*a+0 ]			),
			.O_FTk(			FA_FTk_A[ a ]				),
			.I_BTk(			FA_BTk_A[ a ]				),
			.I_InC(			F_InC_A[ a ]				)
		);

		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK(		NUM_LINKC					),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_FTKM(		FTk_1f_t					),
			.TYPE_BTKM(		BTk_1f_t					),
			.TYPE_DATA(		data_f1_t					),
			.TYPE_LOGN(		log_f1_t					),
			.TYPE_BITS(		bit_f1_t					),
			.TYPE_O_FTK(	FTk_1_t						),
			.TYPE_I_BTK(	BTk_1_t						)
		) ALU_InB
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			F_ALU_FTk[ 3*a+1 ]			),
			.O_BTk(			F_ALU_BTk[ 3*a+1 ]			),
			.O_FTk(			FA_FTk_B[ a ]				),
			.I_BTk(			FA_BTk_B[ a ]				),
			.I_InC(			F_InC_B[ a ]				)
		);

		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK(		NUM_LINKC					),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_FTKM(		FTk_1f_t					),
			.TYPE_BTKM(		BTk_1f_t					),
			.TYPE_DATA(		data_f1_t					),
			.TYPE_LOGN(		log_f1_t					),
			.TYPE_BITS(		bit_f1_t					),
			.TYPE_O_FTK(	FTk_1_t						),
			.TYPE_I_BTK(	BTk_1_t						)
		) ALU_InC
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			F_ALU_FTk[ 3*a+2 ]			),
			.O_BTk(			F_ALU_BTk[ 3*a+2 ]			),
			.O_FTk(			FA_FTk_C[ a ]				),
			.I_BTk(			FA_BTk_C[ a ]				),
			.I_InC(			F_InC_C[ a ]				)
		);

		FanOut_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_CHANNEL(	1							),
			.NUM_LINK( 		NUM_LINKC					),
			.WIDTH_LENGTH(	10							),
			.DEPTH_FIFO(	DEPTH_FIFO					),
			.TYPE_FTK(		FTk_1f_t					),
			.TYPE_BTK(		BTk_1f_t					),
			.TYPE_BITS(		bit_f1_t					),
			.TYPE_I_FTK(	FTk_1_t						),
			.TYPE_O_BTK(	BTk_1_t						)
		) ALU_Out
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			BB_FTk[ a ]					),
			.O_BTk(			BB_BTk[ a ]					),
			.O_FTk(			B_ALU_FTk[ a ]				),
			.I_BTk(			B_ALU_BTk[ a ]				),
			.O_InC(			B_InC[ a ]					)
		);

		ALU #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.WIDTH_OPCODE(	WIDTH_OPCODE				),
			.WIDTH_CONSTANT(WIDTH_CONSTANT				)
		) ALU
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTkA(		FA_FTk_A[ a ]				),
			.O_BTkA(		FA_BTk_A[ a ]				),
			.I_FTkB(		FA_FTk_B[ a ]				),
			.O_BTkB(		FA_BTk_B[ a ]				),
			.I_FTkC(		FA_FTk_C[ a ]				),
			.O_BTkC(		FA_BTk_C[ a ]				),
			.O_FTk(			BB_FTk[ a ][0]				),
			.I_BTk(			BB_BTk[ a ][0]				),
			.O_InCA(		F_InC_A[ a ]				),
			.O_InCB(		F_InC_B[ a ]				),
			.O_InCC(		F_InC_C[ a ]				)
		);
	end

endmodule
