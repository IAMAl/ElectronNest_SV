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
	logic						Des;

	logic	[WIDTH_BUFF+1:0]	R_Num;
	logic						R_Dec;


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
	assign Full				= ( O_Num == (NUM_ENTRY-2) ) & ~( Dec | R_Dec );
	assign Empty			= ( O_Num == '0 );
	assign O_Full			= Full;
	assign O_Empty			= Empty;


	////
	assign Dec				= ( R_Num > O_Num ) & ( R_Num == (NUM_ENTRY-1) );
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Num			<= '0;
		end
		else begin
			R_Num			<= O_Num;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Dec			<= 1'b0;
		end
		else if (  ( O_Num != (NUM_ENTRY-2) ) ) begin
			R_Dec			<= 1'b0;
		end
		else if ( ( O_Num == (NUM_ENTRY-2) ) & ( R_Num == (NUM_ENTRY-1) ) ) begin
			R_Dec			<= 1'B1;
		end
	end


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
