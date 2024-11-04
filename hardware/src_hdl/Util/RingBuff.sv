///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Common Buffer Unit
//		Module Name:	RingBuff
//		Function:
//						Common Buffer based on Ring Control
//						Buffering Data with Ring manner.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RingBuff
	import	pkg_en::*;
#(
	parameter int DEPTH_BUFF		= 16,
	parameter int WIDTH_DEPTH		= $clog2(DEPTH_BUFF),
	parameter type TYPE_FWRD   		= FTk_t,
	parameter int OFFSET			= 1
)(
	input						clock,
	input						reset,
	input						I_We,				//Write-Enable
	input						I_Re,				//Read-Enable
	input	TYPE_FWRD			I_FTk,				//Data
	output	TYPE_FWRD			O_FTk,				//Data
	output	logic				O_Full,				//Flag: Empty in Buffer
	output	logic				O_Empty,			//Flag: Empty in Buffer
	output	[WIDTH_DEPTH:0]		O_Num				//Number of Remained Entries
);

	localparam int WIDTH_ADDR	= $clog2(DEPTH_BUFF);


	//// Buffer Memory												////
	TYPE_FWRD					mem [DEPTH_BUFF-1:0];


	//// Pointers													////
	logic	[WIDTH_ADDR-1:0]	WAddr;
	logic	[WIDTH_ADDR-1:0]	RAddr;

	logic						We;
	logic						Re;

	logic						Full;
	logic						Empty;


	////
	logic						R_Full;

	//// Status Flag												////
	assign O_Full			= Full;
	assign O_Empty			= Empty;


	//// Output Data												////
	assign O_FTk			= ( I_Re ) ? mem[ RAddr ] : '0;


	//// Enables													////
	assign We				= I_We;
	assign Re				= I_Re;


	////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Full		<= 1'b0;
		end
		else if ( O_Num < (DEPTH_BUFF/2) ) begin
			R_Full		<= 1'b0;
		end
		else if ( Full ) begin
			R_Full		<= 1'b1;
		end
	end

	//// Storing in Buffer by Write-Pointer							////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<DEPTH_BUFF; ++i ) begin
				mem[ i ]	<= '0;
			end
		end
		else if ( We ) begin
			mem[ WAddr ]	<= I_FTk;
		end
	end


	//// Buffer Controller											////
	RingBuffCTRL2 #(
		.NUM_ENTRY(			DEPTH_BUFF					),
		.OFFSET(			OFFSET						)
	) RingBuffCTRL
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We							),
		.I_Re(				Re							),
		.O_WAddr(			WAddr						),
		.O_RAddr(			RAddr						),
		.O_Full(			Full						),
		.O_Empty(			Empty						),
		.O_Num(				O_Num						)
	);

endmodule