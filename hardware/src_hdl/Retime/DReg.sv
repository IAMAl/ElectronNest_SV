///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Retiming Register
//	Module Name:	DReg
//	Function:
//					Retiming Register with Tokens
//					Valid and nack tokens are used for avoiding data-drop.
//					Pair of register works as double buffer, and
//						one register works to capture dropping data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module DReg
	import  pkg_en::*;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input							I_We,							//Write-Enable
	input	FTk_t					I_FTk,							//Input Forward-Tokens
	input	BTk_t					I_BTk,							//Input Backward-Tokens
	output	FTk_t					O_FTk,							//Output Forward-Tokens
	output	BTk_t					O_BTk							//Output Backward-Tokens
);


	//// Tokens														////
	//	 Valid Token
	logic						I_Valid;
	assign I_Valid			= I_FTk.v;

	logic						Valid;

	//	 Nack Token
	logic						I_Nack;
	assign I_Nack			= I_BTk.n;

	logic						Nack;


	//// Register Bodies											////
	//	 Register Write/Read
	logic						We;
	logic						WNo;
	logic						RNo;

	//	 Capture Registers
	FTk_2_t						FTk;
	BTk_t						BTk;

	TokenUnit TokenUnit (
		.clock(				clock						),
		.reset(				reset						),
		.I_Valid(			I_Valid						),
		.I_Nack(			I_Nack						),
		.I_We(				I_We						),
		.O_Valid(			Valid						),
		.O_Nack(			Nack						),
		.O_We(				We							),
		.O_WNo(				WNo							),
		.O_RNo(				RNo							)
	);


	//// Output Selection											////
	assign O_FTk.v			= Valid;
	assign O_FTk.a			= FTk[ RNo ].a;
	assign O_FTk.c			= FTk[ RNo ].c;
	assign O_FTk.r			= FTk[ RNo ].r;
	`ifdef EXTEND
	assign O_FTk.i			= FTk[ RNo ].i;
	`endif
	assign O_FTk.d			= FTk[ RNo ].d;

	assign O_BTk.n			= Nack;
	assign O_BTk.t			= BTk.t;
	assign O_BTk.v			= BTk.v;
	assign O_BTk.c			= BTk.c;


	//// Capture Tokens												////
	//	 Foward Tokens
	always_ff @( posedge clock ) begin: ff_forwardtokens
		if ( reset ) begin
			FTk[0].v	<= 1'b0;
			FTk[1].v	<= 1'b0;
			FTk[0].a	<= 1'b0;
			FTk[1].a	<= 1'b0;
			FTk[0].c	<= 1'b0;
			FTk[1].c	<= 1'b0;
			FTk[0].r	<= 1'b0;
			FTk[1].r	<= 1'b0;
			`ifdef EXTEND
				FTk[0].i	<= '0;
				FTk[1].i	<= '0;
			`endif
			FTk[0].d	<= 32'h0;
			FTk[1].d	<= 32'h0;
		end
		else if ( We ) begin
			FTk[ WNo ].a	<= I_FTk.a;
			FTk[ WNo ].c	<= I_FTk.c;
			FTk[ WNo ].r	<= I_FTk.r;
			//`ifdef EXTEND
				FTk[ WNo ].i	<= I_FTk.i;
			//`endif
			FTk[ WNo ].d	<= I_FTk.d;
		end
	end

	//	 Backward Tokens
	always_ff @( posedge clock ) begin: ff_backwardtokens
		if ( reset ) begin
			BTk.n			<= 1'b0;
			BTk.t			<= 1'b0;
			BTk.v			<= 1'b0;
			BTk.c			<= 1'b0;
		end
		else begin
			BTk.n			<= 1'b0;
			BTk.t			<= I_BTk.t;
			BTk.v			<= I_BTk.v;
			BTk.c			<= I_BTk.c;
		end
	end

endmodule
