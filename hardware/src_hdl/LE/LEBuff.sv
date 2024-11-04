///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Buffer Unit for Link Element
//		Module Name:	Buff
//		Function:
//						Buffering Data
//						Ring-Based Buffer
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Buff
	import	pkg_en::*;
#(
	parameter int DEPTH_FIFO		= 16,
	parameter int THRESHOLD			= 4,
	parameter int PASS				= 0,
	parameter int BUFF				= 1,
	parameter int WIDTH_NUM			= $clog2(DEPTH_FIFO)
)(
	input							clock,
	input							reset,
	input	FTk_t					I_FTk,				//Data
	output	BTk_t					O_BTk,				//Back-Prop Token
	output	FTk_t					O_FTk,				//Data
	input	BTk_t					I_BTk,				//Back-Prop Token
	input							I_We,				//Write-Enable
	input							I_Re,				//Read-Enable
	input							I_Chg_Buff,			//Charge Buffer
	input							I_Rls_Buff,			//Release Buffer
	input							I_SendID,			//Send ID
	output	logic					O_Empty,			//Flag: Empty in Buffer
	output	logic					O_Full,				//Flag: Full in Buffer
	output	logic	[WIDTH_NUM:0]	O_Num				//Number of Entries in Buffer
);


	//// Logic Connect												////
	logic						I_Stay;
	logic 						Pass;

	FTk_t						Buff_FTk;
	FTk_t						Out_FTk;

	logic						Up;
	logic						EndUp;

	logic						Stop;
	logic						FirstNack;
	logic						CommonDown;
	logic						Down;
	logic						Stay;
	logic						Nop;

	logic						We;
	logic						Re;

	logic						ChkPulse;
	logic						ChkPulse_Bar;

	logic						Full;
	logic						Empty;
	logic	[WIDTH_NUM:0]		Num;


	//// Capture Signal												////
	logic						R_Repair;

	logic						R_ChkPulse_Bar;

	logic						R_NackD1;
	logic						R_NackD2;
	logic						R_Up;
	logic						R_Full;


	assign I_Stay			= I_SendID;
	assign Pass				= PASS;


	//	Forwarrd Tokens
	assign Out_FTk			= ( Empty & ~R_Full & ~ChkPulse_Bar ) ? I_FTk : ( Empty & ~R_Full & ChkPulse_Bar ) ? '0 :  Buff_FTk;
	assign O_FTk			= ( I_Chg_Buff & I_Rls_Buff ) ? Out_FTk : ( ( I_Chg_Buff & ~I_Rls_Buff ) | ( ( ( ~I_FTk.v & Empty ) | R_NackD1 ) ^ ChkPulse ) | Nop | Stop ) ? '0 : Out_FTk;

	//	 Backward Tokens
	assign O_BTk.n			= I_BTk.n | R_Full;
	assign O_BTk.t			= I_BTk.t;
	assign O_BTk.v			= I_BTk.v;
	assign O_BTk.c			= I_BTk.c;

	assign O_Empty			= Empty;
	assign O_Full			= R_Full;
	assign O_Num			= Num;


	//// Buffer Control												////
	//	 Buffering
	//		Count-Up
	assign Up				= ( Num < (DEPTH_FIFO-1)) & ( ChkPulse_Bar | ( ~ChkPulse & I_BTk.n ) );

	//		End of Up
	assign EndUp			= R_Up & ~Up;

	//	 Buffering by Nack token or Some Request (I_Chg_Buff)
	assign Stop				= I_We & I_FTk.v & ((( I_Chg_Buff ) & ~I_Rls_Buff ) | Up | (( Num < (DEPTH_FIFO-1)) & R_Repair & EndUp ));

	//	 Consume Buffer
	//		Sending for First Nack
	assign FirstNack		= I_BTk.n & ~R_NackD1 & ~Empty;

	//		Sending for Common Case
	assign CommonDown		= ~I_BTk.n & ~Empty;

	//		Count-Down
	assign Down				= I_Re & (( ~I_FTk.v & ~I_Stay & ~I_Chg_Buff & (( ~R_Full & Pass ) | CommonDown | FirstNack )) | I_Rls_Buff ) & ( ChkPulse | ~R_NackD1 );

	//		Keep Current Buffer Depth
	assign Stay				= ( I_We & I_Re & I_FTk.v & ~Empty ) | ( I_We & I_FTk.v & I_Chg_Buff & I_Rls_Buff );


	//// NOP														////
	assign Nop				= ~( Down | Stay | Stop ) & ~Full & ~Empty;


	//// Enable Signal												////
	//	 Write-Enable
	assign We				= Stay | Stop;

	//	 Read-Enable
	assign Re				= ( Stay | Down ) & ~Stop & ( ChkPulse | ~R_NackD1 ) | R_ChkPulse_Bar;


	//// Nack Token													////
	//	 Pulse-Nack Detection
	assign ChkPulse			= ~I_BTk.n & R_NackD1 & ~R_NackD2;
	assign ChkPulse_Bar		= I_BTk.n & ~R_NackD1 & R_NackD2;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Repair		<= 1'b0;
		end
		else if ( EndUp | Down ) begin
			R_Repair		<= 1'b0;
		end
		else if ( ~I_FTk.v & I_BTk.n & ~R_NackD1 ) begin
			R_Repair		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_NackD1		<= '0;
			R_NackD2		<= '0;
			R_Up			<= 1'b0;
			R_ChkPulse_Bar	<= 1'b0;
		end
		else begin
			R_NackD1		<= I_BTk.n;
			R_NackD2		<= R_NackD1;
			R_Up			<= Up;
			R_ChkPulse_Bar	<= I_BTk.n & ~R_NackD1 & R_NackD2;
		end
	end


	//// Buffer Full State Detection								////
	//	 Continues Output by DEPTH_FIFO/4 after Full-state
	assign Full				= ( Num == (DEPTH_FIFO-3) );
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Full			<= 1'b0;
		end
		else if ( Full ) begin
			R_Full			<= 1'b1;
		end
		else if ( ~( I_We | I_Re ) | ( Num < THRESHOLD )) begin
			R_Full			<= 1'b0;
		end
	end


	//// Buffer Body												////
	RingBuff #(
		.DEPTH_BUFF(		DEPTH_FIFO					),
		.TYPE_FWRD(			FTk_t						)
	) RingBuff
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We							),
		.I_Re(				Re							),
		.I_FTk(				I_FTk						),
		.O_FTk(				Buff_FTk					),
		.O_Full(										),
		.O_Empty(			Empty						),
		.O_Num(				Num							)
	);

endmodule
