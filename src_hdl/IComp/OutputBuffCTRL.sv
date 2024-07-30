///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Ring Buffer Control
//	Module Name:	OutputBuffCTRL
//	Function:
//					Controller for Ring Buffer
//					Support Two Write Enables
//					Multi-stage pipeline with skipping must buffer in-coming data.
//					Because the order of the coming is out-of-order.
//					The function is equivalent to reorder buffer used in processors.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module OutputBuffCTRL
#(
	parameter int NUM_ENTRY			= 4
)(
	input							clock,
	input							reset,
	input							I_Clr,				//Clear
	input							I_We,				//Write-Enable
	input							I_Re,				//Read-Enable
	output	[$clog2(NUM_ENTRY)-1:0]	O_WAddr,			//Write Address
	output	[$clog2(NUM_ENTRY)-1:0]	O_RAddr,			//Read Address
	output	logic					O_Full,				//Flag: Full
	output	logic					O_Empty				//Flag: Empty
);

	localparam int WIDTH_BUFF	= $clog2(NUM_ENTRY);


	//// Logic Connect												////
	//	 Write-Pointer
	logic 	[WIDTH_BUFF-1:0]	W_WPtr;

	//	 Read-Pointer
	logic 	[WIDTH_BUFF-1:0]	W_RPtr;

	//	 Status
    logic 	[WIDTH_BUFF:0]		T_CNT;
	logic						Full;
	logic						Empty;

	//	 Clear-Ponter
	logic						Clr_W;
	logic						Clr_R;


	//// Pointers													////
    logic 	[WIDTH_BUFF-1:0]	R_WCNT;
    logic 	[WIDTH_BUFF-1:0]	R_RCNT;


	//// Output 													////
    assign O_WAddr			= W_WPtr;
	assign O_RAddr			= W_RPtr;

    assign W_WPtr			= R_WCNT;
    assign W_RPtr			= R_RCNT;


	//// Buffer Status												////
    assign T_CNT			= R_WCNT - R_RCNT;

	//	 Full State
	//		If NUM_ENTRY is Power of Two than checking MS-bit is sufficient
	assign Full				= ( T_CNT[WIDTH_BUFF] ) ?	T_CNT == ( 1 - NUM_ENTRY ) :
														T_CNT == ( NUM_ENTRY - 1 );
    assign O_Full			= Full;

	//	 Empty State
	assign Empty			= T_CNT == '0;
    assign O_Empty			= Empty;


	//// Clear Counter												////
	//	 If "NUM_ENTRY" is Power of Two, not necessary
	assign Clr_W			= ( R_WCNT + I_We ) > ( NUM_ENTRY - 1 );

	assign Clr_R			= ( R_RCNT + ( I_Re & ~Empty ) ) > ( NUM_ENTRY - 1 );


	//// Pointers													////
	//	 Write-Pointer
	always_ff @( posedge clock ) begin: ff_wcnt
		if ( reset ) begin
			R_WCNT			<= '0;
		end
		else if ( I_Clr | Clr_W ) begin
			R_WCNT			<= '0;
		end
		else if ( ~Full & I_We & ( R_WCNT == (NUM_ENTRY-1) )) begin
			R_WCNT  		<= '0;
		end
		else if ( ~Full & I_We ) begin
			R_WCNT  		<= R_WCNT + 1'b1;
		end
	end

	//	 Read-Pointer
	always_ff @( posedge clock ) begin: ff_rcnt
		if ( reset ) begin
			R_RCNT	<= '0;
		end
		else if ( I_Clr | Clr_R ) begin
			R_RCNT			<= '0;
		end
		else if ( I_Re & ( R_RCNT == (NUM_ENTRY-1) )) begin
			R_RCNT  		<= '0;
		end
		else if  ( I_Re ) begin
			R_RCNT  		<= R_RCNT + 1'b1;
		end
	end

endmodule
