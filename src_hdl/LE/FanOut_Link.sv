///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Network-on-Chip Input Router
//	Module Name:	FanOut_Link
//	Function:
//					Router for Input
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanOut_Link
	import	pkg_en::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int NUM_LINK			= 4,
	parameter int NUM_CHANNEL		= 1,
	parameter int WIDTH_LENGTH		= 10,
	parameter int DEPTH_FIFO		= 12,
	parameter type TYPE_FTK			= FTk_cl_t,
	parameter type TYPE_BTK			= BTk_cl_t,
	parameter type TYPE_I_FTK		= FTk_c_t,
	parameter type TYPE_O_BTK		= BTk_c_t,
	parameter type TYPE_BITS		= logic[NUM_CHANNEL-1:0][NUM_LINK-1:0]
)(
	input							clock,
	input							reset,
	input	TYPE_I_FTK				I_FTk,				//Forward Tokens
	output	TYPE_O_BTK				O_BTk,				//Back-Prop Tokens
	output	TYPE_FTK				O_FTk,				//Forward Tokens
	input	TYPE_BTK				I_BTk,				//Back-Prop Tokens
	output	bit2_c_t				O_InC				//Condition-Code Path
);

	data_c_t					FIFOs_O_Grt;
	bit2_c_t					FIFOs_O_InC;
	FTk_c_t						F_FTk;
	BTk_c_t						F_BTk;

	logic [NUM_LINK-1:0]		Nack [NUM_CHANNEL-1:0];

	logic [$clog2(NUM_LINK)-1:0]Sel_No [NUM_CHANNEL-1:0];

	for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin : g_fanout
		FanOut_FIFO #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.WIDTH_LENGTH(	WIDTH_LENGTH				),
			.DEPTH_FIFO(	DEPTH_FIFO					)
		) FIFO
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			I_FTk[ c ]					),
			.O_BTk(			O_BTk[ c ]					),
			.O_FTk( 		F_FTk[ c ]					),
			.I_BTk(			F_BTk[ c ]					),
			.O_Grt(			FIFOs_O_Grt[ c ]			),
			.O_InC(			FIFOs_O_InC[ c ]			)
		);
	end


	for ( genvar c = 0; c < NUM_CHANNEL; ++c) begin : g_sel_btk
		Encoder #(
			.NUM_ENTRY(		NUM_LINK					)
		) Sel_I_BTk
		(
			.I_Data(	FIFOs_O_Grt[ c ][NUM_LINK-1:0]	),
			.O_Enc(			Sel_No[ c ]					)
		);
	end


	always_comb begin: c_port
		for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
			for ( int l = 0; l < NUM_LINK; ++l ) begin
				O_FTk[ l ][ c ] = FIFOs_O_Grt[ c ][ l ] ? F_FTk[ c ] : 0;
				Nack[ c ][ l ]	= I_BTk[ l ][ c ].n;
			end
			F_BTk[ c ].n	= |Nack[ c ];
			F_BTk[ c ].t	= ( FIFOs_O_Grt[ c ][NUM_LINK-1:0] != 0 ) ? I_BTk[ Sel_No[ c ] ][ c ].t  : '0;
			F_BTk[ c ].v	= ( FIFOs_O_Grt[ c ][NUM_LINK-1:0] != 0 ) ? I_BTk[ Sel_No[ c ] ][ c ].v  : '0;
			F_BTk[ c ].c	= ( FIFOs_O_Grt[ c ][NUM_LINK-1:0] != 0 ) ? I_BTk[ Sel_No[ c ] ][ c ].c  : '0;
		end
	end


	assign O_InC			= FIFOs_O_InC;

endmodule
