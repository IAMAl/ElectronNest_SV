///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Ring Buffer Control
//		Module Name:	RingBuffCTRL
//		Function:
//						Controller for Ring Buffer
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RingBuffCTRL2
#(
	parameter int NUM_ENTRY			= 16,
	parameter int OFFSET			= 1
)(
	input							clock,
	input							reset,
	input							I_We,				//Write-Enable
	input							I_Re,				//Read-Enable
	output	[$clog2(NUM_ENTRY)-1:0]	O_WAddr,			//Write Address
	output	[$clog2(NUM_ENTRY)-1:0]	O_RAddr,			//Read Address
	output	logic					O_Full,				//Flag: Full
	output	logic					O_Empty,			//Flag: Empty
    output  [$clog2(NUM_ENTRY):0]	O_Num				//Remained Number of Entries
);

	localparam int WIDTH_BUFF	= $clog2(NUM_ENTRY);


	//// Logic Connect												////
	//	 Pointers
    logic 	[WIDTH_BUFF:0]		W_WPtr;
    logic 	[WIDTH_BUFF:0]		W_RPtr;
    logic 	[WIDTH_BUFF+1:0]	W_CNT;

	logic						Full;
	logic						Empty;


	//// Capture Signal												////
	//	 Count Registers
    logic 	[WIDTH_BUFF+1:0]	R_WCNT;
    logic 	[WIDTH_BUFF+1:0]	R_RCNT;


    assign W_WPtr			= R_WCNT[WIDTH_BUFF:0];
    assign W_RPtr			= R_RCNT[WIDTH_BUFF:0];
    assign W_CNT			= R_WCNT - R_RCNT;


	//// Output 													////
    assign O_WAddr			= W_WPtr;
	assign O_RAddr			= W_RPtr;
    assign O_Num            = ( W_CNT[WIDTH_BUFF+1] ) ?	W_CNT[WIDTH_BUFF:0] + NUM_ENTRY :
														W_CNT[WIDTH_BUFF:0] ;


	//// Buffer Status												////
	assign Full				= ( O_Num  == NUM_ENTRY );
	assign Empty			= ( O_Num  == '0 );
	assign O_Full			= Full;
	assign O_Empty			= Empty;


	//// Pointers													////
	always_ff @( posedge clock ) begin: ff_wcnt
		if ( reset ) begin
			R_WCNT		<= '0;
		end
		else if ( I_We ) begin
			R_WCNT  	<= R_WCNT + 1'b1;
		end
	end

	always_ff @( posedge clock ) begin: ff_rcnt
		if ( reset ) begin
			R_RCNT		<= '0;
		end
		else if  ( I_Re ) begin
			R_RCNT  	<= R_RCNT + 1'b1;
		end
	end

endmodule
/*
module RingBuffCTRL2
#(
	parameter NUM_ENTRY		= 4,						// Should be POWER OF 2
	parameter int OFFSET	= 1
)(
	input							clock,
	input							reset,
	input							I_We,			// Write-Enable
	input							I_Re,			// Read-Enable
	output	[$clog2(NUM_ENTRY)-1:0]	O_WAddr,		// Write Address
	output	[$clog2(NUM_ENTRY)-1:0]	O_RAddr,		// Read Address
	output	logic					O_Full,			// Flag: Full
	output	logic					O_Empty,		// Flag: Empty
	output  [$clog2(NUM_ENTRY):0]	O_Num
);

	localparam WIDTH_BUFF	= $clog2(NUM_ENTRY);

    logic 	[WIDTH_BUFF:0]		R_WCNT;
    logic 	[WIDTH_BUFF:0]		R_RCNT;

    wire 	[WIDTH_BUFF-1:0]	W_WPtr;
    wire 	[WIDTH_BUFF-1:0]	W_RPtr;
    wire 	[WIDTH_BUFF:0]		W_CNT;


    assign W_WPtr			= R_WCNT[WIDTH_BUFF-1:0];
    assign W_RPtr			= R_RCNT[WIDTH_BUFF-1:0];

    assign W_CNT			= R_WCNT - R_RCNT;

    assign O_WAddr			= W_WPtr;
	assign O_RAddr			= W_RPtr;

    assign O_Full			= W_CNT[WIDTH_BUFF];
    assign O_Empty			= W_CNT == '0;

    assign O_Num            = ( W_CNT[WIDTH_BUFF] ) ?	W_CNT[WIDTH_BUFF:0] + NUM_ENTRY :
														W_CNT[WIDTH_BUFF:0] ;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_WCNT	<= '0;
		end
		else if ( I_We )begin
			R_WCNT  <= R_WCNT + 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RCNT	<= '0;
		end
		else if ( I_Re ) begin
			R_RCNT  <= R_RCNT + 1'b1;
		end
	end

endmodule
*/