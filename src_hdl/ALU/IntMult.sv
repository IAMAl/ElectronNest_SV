///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Integer Multiplier
//	Module Name:	IntMultUnit
//	Function:
//					Integer Multiplier
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IntMultUnit
	import	pkg_en::*;
	import	pkg_alu::*;
#(
	parameter WIDTH_DATA			= 32
)(
	input							clock,
	input							reset,
	input                           I_En,				//Enable to Execute
	input	opcode_ms_t				I_Opcode,			//Opcode
	input	cond_t					I_Cond,				//Condition LUT
	input	FTk_t		            I_OperandA,			//Source Operand
	input	FTk_t		            I_OperandB,			//Source Operand
	input   FTk_t                   I_SharedA,			//Shared Value
	input   FTk_t                   I_SharedB,			//Shared Value
	output	FTk_t		            O_Result,			//Result
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTk,				//Backward TOkens
	output							O_TS,				//Skip Enable
	output	FTk_t					O_TSFTk_A,			//Skip Value
	output	FTk_t					O_TSFTk_B			//Skip Value
);

	localparam VALIDSKIP = 1;
	localparam VALIDTHRU = 1;


	//// Logic Connect												////
	//	 Opcode Assignment
	logic	    				SelSigned;
	logic                       SelSaturate;
	logic						OutCondB;
	logic						OutCondF;

	logic						Valid;

	FTk_t						W_SrcA;
	FTk_t						W_SrcB;

	logic						Signed;
	logic						SignedA;
	logic						SignedB;
	logic						SignedC;

	logic	[WIDTH_DATA-1:0]	SignedSrcA;
	logic	[WIDTH_DATA-1:0]	SignedSrcB;

	logic	[WIDTH_DATA-1:0]	UnsignedSrcA;
	logic	[WIDTH_DATA-1:0]	UnsignedSrcB;

	logic	[WIDTH_DATA-1:0]	SrcA;
	logic	[WIDTH_DATA-1:0]	SrcB;

	logic	[WIDTH_DATA/2-1:0]	SrcMSW_A;
	logic	[WIDTH_DATA/2-1:0]	SrcLSW_A;

	logic	[WIDTH_DATA/2-1:0]	SrcMSW_B;
	logic	[WIDTH_DATA/2-1:0]	SrcLSW_B;

	//	 Partial Products
	FTk_t						PProd_LALB;
	FTk_t						PProd_MALB;
	FTk_t						PProd_LAMB;

	FTk_t						FTk_LALB;
	FTk_t						FTk_MALB;
	FTk_t						FTk_LAMB;

	BTk_t						BTk_LALB;
	BTk_t						BTk_LAMB;

	FTk_t						PSumL;
	FTk_t						PSumM;

	FTk_t						FTk_L;
	FTk_t						FTk_M;

	logic	[WIDTH_DATA+WIDTH_DATA/2-1:0]	UnsignedResult;
	logic	[WIDTH_DATA+WIDTH_DATA/2-1:0]	SignedResult;
	logic	[WIDTH_DATA+WIDTH_DATA/2-1:0]	PreResult;

	logic						Sign;
	logic						Overflowed;
	logic	[WIDTH_DATA-1:0]	Result;

	logic	[WIDTH_COND-1:0]	LUTAddr;
	logic						Cond;


	//// Capture Signal												////
	logic						R_En;


	assign SelSigned		= I_Opcode[0];
	assign SelSaturate		= I_Opcode[1];

	assign OutCondB			= I_Opcode[2];
	assign OutCondF			= I_Opcode[3];


	//// Remove First Data Word										////
	//	 First Word arriving here is Attribute Word
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_En	<= 1'b0;
		end
		else if ( W_SrcA.r & W_SrcB.r ) begin
			R_En	<= 1'b0;
		end
		else if ( I_En ) begin
			R_En	<= 1'b1;
		end
		else begin
			R_En	<= R_En;
		end
	end


	//// Skip Interface												////
	//	 Detection whether Skip or Thru
	SkipIF #(
		.SKIPVAL( 			32'h00000000				),
		.THRUVAL(			32'h00000001				),
		.VALIDSKIP(			VALIDSKIP					),
		.VALIDTHRU(			VALIDTHRU					)
	) SkipIF_M
	(
		.I_En(				R_En & I_En					),
		.I_FTk_A(			I_OperandA					),
		.I_FTk_B(			I_OperandB					),
		.I_SFTk_A(			I_SharedA					),
		.I_SFTk_B(			I_SharedB					),
		.O_FTk_A(			W_SrcA						),
		.O_FTk_B(			W_SrcB						),
		.O_TS(				O_TS						),
		.O_TSFTk_A(			O_TSFTk_A					),
		.O_TSFTk_B(			O_TSFTk_B					)
	);


	//// Preprocess													////
	//	 Check Sign Flag
	assign Signed			= SelSigned;
	assign SignedA			= ( Signed ) ? $signed( W_SrcA.d ) < '0 : 1'b0;
	assign SignedB			= ( Signed ) ? $signed( W_SrcB.d ) < '0 : 1'b0;
	assign SignedC			= SignedA ^ SignedB;

	//	 Make Two's Complement for Signed Operation
	assign SignedSrcA		= ~( W_SrcA.d ) + 1'b1;
	assign SignedSrcB		= ~( W_SrcB.d ) + 1'b1;

	//	 Unsigned/Signed Operation Source
	assign UnsignedSrcA		= W_SrcA.d;
	assign UnsignedSrcB		= W_SrcB.d;

	//	 Setting Unsigned Sources
	assign SrcA				= ( SignedA ) ? SignedSrcA : UnsignedSrcA;
	assign SrcB				= ( SignedB ) ? SignedSrcB : UnsignedSrcB;

	//	 Splitting Sources
	assign SrcMSW_A			= SrcA[WIDTH_DATA-1:WIDTH_DATA/2];
	assign SrcLSW_A			= SrcA[WIDTH_DATA/2-1:0];

	assign SrcMSW_B			= SrcB[WIDTH_DATA-1:WIDTH_DATA/2];
	assign SrcLSW_B			= SrcB[WIDTH_DATA/2-1:0];


	//// Pipeline Stage-1											////
	assign Valid			= W_SrcA.v & W_SrcB.v & I_En & ~O_TS;

	//   Partial Product LS-16-A and LS-16-B
	assign PProd_LALB.v		= Valid;
	assign PProd_LALB.a		= SignedC;
	assign PProd_LALB.c		= W_SrcA.c;
	assign PProd_LALB.r		= W_SrcA.r;
	`ifdef EXTEND
	assign PProd_LALB.i		= W_SrcA.i;
	`endif
	assign PProd_LALB.d		= SrcLSW_A * SrcLSW_B;

	//   Partial Product MS-16-A and LS-16-B
	assign PProd_MALB.v		= Valid;
	assign PProd_MALB.a		= SignedC;
	assign PProd_MALB.c		= W_SrcA.c;
	assign PProd_MALB.r		= W_SrcA.r;
	`ifdef EXTEND
	assign PProd_MALB.i		= W_SrcA.i;
	`endif
	assign PProd_MALB.d		= SrcMSW_A * SrcLSW_B;

	//   Partial Product LS-16-A and MS-16-B
	assign PProd_LAMB.v		= Valid;
	assign PProd_LAMB.a		= SignedC;
	assign PProd_LAMB.c		= W_SrcA.c;
	assign PProd_LAMB.r		= W_SrcA.r;
	`ifdef EXTEND
	assign PProd_LAMB.i		= W_SrcA.i;
	`endif
	assign PProd_LAMB.d		= SrcLSW_A * SrcMSW_B;

	//	 Pipeline Register
	DReg Pipe_LALB (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				PProd_LALB					),
		.O_BTk(											),
		.O_FTk(				FTk_LALB					),
		.I_BTk(				BTk_LALB					)
	);

	DReg Pipe_MALB (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				PProd_MALB					),
		.O_BTk(											),
		.O_FTk(				FTk_MALB					),
		.I_BTk(				BTk_LALB					)
	);

	DReg Pipe_LAMB (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				PProd_LAMB					),
		.O_BTk(											),
		.O_FTk(				FTk_LAMB					),
		.I_BTk(				BTk_LAMB					)
	);


	//// Pipeline Stage-2											////
	//	 Partial Sums
	assign PSumM.v			= FTk_LALB.v;
	assign PSumM.a			= FTk_MALB.a;
	assign PSumM.c			= FTk_MALB.c;
	assign PSumM.r			= FTk_MALB.r;
	assign PSumM.d			= FTk_MALB.d + FTk_LAMB.d;
	`ifdef EXTEND
	assign PSumM.i			= FTk_LAMB.i;
	`endif

	assign PSumL.v			= FTk_LALB.v;
	assign PSumL.a			= FTk_LALB.a;
	assign PSumL.c			= FTk_LALB.c;
	assign PSumL.r			= FTk_LALB.r;
	assign PSumL.d			= FTk_LALB.d;
	`ifdef EXTEND
	assign PSumL.i			= FTk_LALB.i;
	`endif

	//	 Pipeline Register
	DReg Pipe_L (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				PSumL						),
		.O_BTk(				BTk_LALB					),
		.O_FTk(				FTk_L						),
		.I_BTk(				I_BTk						)
	);

	DReg Pipe_M (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				PSumM						),
		.O_BTk(				BTk_LAMB					),
		.O_FTk(				FTk_M						),
		.I_BTk(				I_BTk						)
	);


	//// Pipeline Stage-3											////
	//	 Final Sum and Sign/Unsign Select
	assign UnsignedResult	= FTk_L.d + { FTk_M.d, 16'h00 };
	assign SignedResult		= ~UnsignedResult + 1'b1;

	assign PreResult		= ( FTk_L.a ) ?	SignedResult : UnsignedResult;

	assign Sign				= PreResult[WIDTH_DATA+WIDTH_DATA/2-1];
	assign Overflowed		= PreResult[WIDTH_DATA+WIDTH_DATA/2-1:WIDTH_DATA] != '0;

	assign Result			= ( SelSaturate & Overflowed ) ? -1 : PreResult[WIDTH_DATA-1:0];

	assign O_Result.v		= FTk_L.v;
	assign O_Result.a		= FTk_L.a;
	assign O_Result.c		= ( OutCondF ) ? Cond : FTk_L.c;
	assign O_Result.r		= FTk_L.r;
	`ifdef EXTEND
	assign O_Result.i		= FTk_L.i;
	`endif
	assign O_Result.d		= Result;


	//// Condition Code Generation									////
	assign LUTAddr			= { Sign, Overflowed, Result[WIDTH_DATA-1:0] == '0 };

	assign Cond				= I_Cond[ LUTAddr ];

	assign O_BTk.n			= I_BTk.n;
	assign O_BTk.t			= I_BTk.t;
	assign O_BTk.v			= ( OutCondB ) ? FTk_L.c : I_BTk.v;
	assign O_BTk.c			= ( OutCondB ) ? Cond : I_BTk.c;

endmodule