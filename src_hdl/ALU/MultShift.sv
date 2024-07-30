///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Integer Multiplier and Shifter
//	Module Name:	MultLogic
//	Function:
//					Integer Multiplier and Shifter Cluster
//					Integer multiplication supports signed and unsigned type,
//						and also supports saturation.
//					Shifter supports, arithmentic right shift, logic left/right shift, and
//						left rotation.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MultShift
	import	pkg_en::*;
	import	pkg_alu::*;
(
	input							clock,
	input							reset,
	input							I_Active,			//Activate Module
	input	opcode_ms_t				I_Opcode,			//Opcode
	input	cond_t					I_Cond,				//Condition LUT
	input							I_EnSrcA,			//Source-Input Enable
	input							I_EnSrcB,			//Source-Input Enable
	input	FTk_t		            I_OperandA,			//Source Operand
	input	FTk_t		            I_OperandB,			//Source Operand
	output	FTk_t		            O_Result,			//Result
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTkA,				//Backward Tokens
	output	BTk_t					O_BTkB				//Backward Tokens
);


	//// Logic Connect												////
	logic						Valid_MS;

	FTk_t						W_FTk_A;
	FTk_t						W_FTk_B;

	logic						SelShift;

	FTk_t						SourceA_Mult;
	FTk_t						SourceB_Mult;

	FTk_t						SourceA_Shift;
	FTk_t						SourceB_Shift;

	BTk_t						BTk_Mult;
	BTk_t						BTk_Shift;

	logic						EnMult;
	logic						EnShift;

	FTk_t						ResultMult;
	FTk_t						ResulShift;

	BTk_t						WBTk_Mult;
	BTk_t						WBTk_Shift;

	FTk_t						Result;


	FTk_t						FTk_MS;
	BTk_t						BTk_MS;

	logic						Fired;
	logic						is_Rls;

	FTk_t						SFTk_A;
	FTk_t						SFTk_B;
	FTk_t						TSFTk_A;
	FTk_t						TSFTk_B;

	logic						Shared;
	BTk_t						WBTk;
	logic						TS;


	BTk_t						BTk_A;
	BTk_t						BTk_B;
	BTk_t						BTk_C;

	logic						Nack_A;
	logic						Nack_B;


	//// Tokens														////
	//	 Valid Token
	assign Valid_MS			= ( I_EnSrcA & I_EnSrcB ) & I_Active;


	`ifdef EXTEND
	//// Skip Unit													////
	SyncUnit  SyncUnit_ML
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			I_Active					),
		.I_EnSrcA(			I_EnSrcA					),
		.I_EnSrcB(			I_EnSrcB					),
		.I_FTk_A(			I_OperandA					),
		.I_FTk_B(			I_OperandB					),
		.O_BTk_A(			O_BTkA						),
		.O_BTk_B(			O_BTkB						),
		.O_FTk_A(			W_FTk_A						),
		.O_FTk_B(			W_FTk_B						),
		.I_BTk_A(			WBTk						),
		.I_BTk_B(			WBTk						),
		.O_SFTk_A(			SFTk_A						),
		.O_SFTk_B(			SFTk_B						),
		.O_Zero_A(										),
		.O_Zero_B(										),
		.O_Shared(			Shared						)
	);
	`else
	//// Input Pipeline Register									////
	assign W_BTkA.n			= BTk_A.n | Nack_A;
	assign W_BTkA.t			= BTk_A.t;
	assign W_BTkA.v			= BTk_A.v | W_FTk_A.r;
	assign W_BTkA.c			= BTk_A.c;

	assign W_BTkB.n			= BTk_B.n | Nack_B;
	assign W_BTkB.t			= BTk_B.t;
	assign W_BTkB.v			= BTk_B.v | W_FTk_B.r;
	assign W_BTkB.c			= BTk_B.c;

	DReg InReg0
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				I_FTk_A						),
		.O_BTk(				O_BTkA						),
		.I_We(				1'b1						),
		.O_FTk(				W_FTk_A						),
		.I_BTk(				WBTk						)
	);

	DReg InReg1
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				I_FTk_B						),
		.O_BTk(				O_BTkB						),
		.I_We(				1'b1						),
		.O_FTk(				W_FTk_B						),
		.I_BTk(				WBTk						)
	);

	assign SFTk_A			= '0;
	assign SFTk_B			= '0;


	//// Wait Unit													////
	WaitUnit WaitUnit_ML
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			I_Active					),
		.I_En_A(			I_EnSrcA					),
		.I_En_B(			I_EnSrcB					),
		.I_Valid_A(			W_FTk_A.v					),
		.I_Valid_B(			W_FTk_B.v					),
		.I_Nack_A(			BTk_A.n						),
		.I_Nack_B(			BBk_B.n						),
		.I_Rls(				Result.r					),
		.O_Nack_A(			Nack_A						),
		.O_Nack_B(			Nack_B						)
	);
	`endif


	//// Execution Body												////
	assign SelShift			= I_Opcode[4];

	//	 Source Distribution
	assign SourceA_Mult		= ( SelShift ) ? '0 : W_FTk_A;
	assign SourceB_Mult		= ( SelShift ) ? '0 : W_FTk_B;

	assign SourceA_Shift	= ( SelShift ) ? W_FTk_A : '0;
	assign SourceB_Shift	= ( SelShift ) ? W_FTk_B : '0;

	assign BTk_Mult			= ( SelShift ) ? '0 : BTk_C;
	assign BTk_Shift		= ( SelShift ) ? I_BTk : '0;

	assign WBTk				= ( SelShift ) ? WBTk_Shift : WBTk_Mult;

	//	 Multiplier
	assign EnMult			= Valid_MS & ~SelShift;
	IntMultUnit IntMultUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_En(				EnMult						),
		.I_Opcode(			I_Opcode					),
		.I_Cond(			I_Cond						),
		.I_OperandA(		SourceA_Mult				),
		.I_OperandB(		SourceB_Mult				),
		.I_SharedA(			SFTk_A						),
		.I_SharedB(			SFTk_B						),
		.O_Result(			ResultMult					),
		.I_BTk(				BTk_Mult					),
		.O_BTk(				WBTk_Mult					),
		.O_TS(				TS							),
		.O_TSFTk_A(			TSFTk_A						),
		.O_TSFTk_B(			TSFTk_B						)
	);

	//	 Shifter
	assign EnShift			= Valid_MS & SelShift;
	ShiftUnit ShiftUnit
	(
		.I_En(				EnShift						),
		.I_Opcode(			I_Opcode					),
		.I_Cond(			I_Cond						),
		.I_OperandA(		SourceA_Shift				),
		.I_OperandB(		SourceB_Shift				),
		.O_Result(			ResulShift					),
		.I_BTk(				BTk_Shift					),
		.O_BTk(				WBTk_Shift					)
	);


	//// Output														////
	assign Result			= ( SelShift ) ? ResulShift : ResultMult;

	assign Fired			= Result.v & I_Active;
	assign is_Rls			= Result.r & I_Active;

	`ifdef EXTEND
	OutBuff #(
		.SIZE_OUT_BUFF(		8							),
		.PIPE_DEPTH(		8							)
	) OutBuff_MS
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			I_Active					),
		.I_Fired(			Fired						),
		.I_FTk(				Result						),
		.O_FTk(				FTk_MS						),
		.I_TSFTk(			TSFTk_A						),
		.I_TS(				TS							),
		.I_BTk(				BTk_MS						),
		.O_BTk(				BTk_C						)
	);
	`else
	DReg OutReg_MS
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				Result						),
		.I_BTk(				BTk_MS						),
		.I_We(				1'b1						),
		.O_FTk(				FTk_MS						),
		.O_BTk(				BTk_C						)
	);
	`endif

	assign O_Result			= FTk_MS;
	assign BTk_MS			= I_BTk;

endmodule