///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Integer Datapath
//	Module Name:	IntDataPath
//	Function:
//					Integer Arithmetic and Logic Unit
//					- Integer Add/Sub
//					- Integer Multipy
//					- Logic
//					- Shift/Rotate
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IntDataPath
	import	pkg_en::*;
	import	pkg_alu::*;
#(
	parameter int WIDTH_DATA			= 32,
	parameter int WIDTH_CMD				= 24
)(
	input							clock,
	input							reset,
	input							I_Active,			//Activate Module
	input	[WIDTH_CMD-1:0]			I_Command,			//Command
	input	cond_t					I_Cond,				//Condition Code
	input	[7:0]					I_Imm,				//Immediate Value
	input							I_EnSrcA,			//Source-Input Enable
	input							I_EnSrcB,			//Source-Input Enable
	input							I_EnSrcC,			//Source-Input Enable
	input	FTk_t		            I_OperandA,			//Source Operand
	input	FTk_t		            I_OperandB,			//Source Operand
	input	FTk_t		            I_OperandC,			//Source Operand
	output	FTk_t		            O_Result,			//Result
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTkA,				//Backward Tokens
	output	BTk_t					O_BTkB,				//Backward Tokens
	output	BTk_t					O_BTkC				//Backward Tokens
);


	//// Logic Connect												////
	FTk_t						FTk_Imm;
	cond_t	[7:0]				Cond;
	logic	[2:0]				ConfigData;
	logic	[1:0]				SelA;
	logic	[1:0]				SelB;
	logic						SelD;

	logic						SelMS;
	logic						SelAL;

	opcode_ms_t					Opcode_MS;
	opcode_al_t					Opcode_AL;

	cond_t						Cond_MS;
	cond_t						Cond_AL;

	logic                       ValidA;
	logic                       ValidB;
	logic                       ValidC;

	logic						Active_MS;
	logic						EnSrcA_MS;
	logic						EnSrcB_MS;
	FTk_t						OperandA_MS;
	FTk_t						OperandB_MS;
	FTk_t						ResultMS;
	BTk_t						BTk_MS;
	BTk_t						BTkA_MS;
	BTk_t						BTkB_MS;

	logic						Active_AL;
	logic						EnSrcA_AL;
	logic						EnSrcB_AL;
	FTk_t						OperandA_AL;
	FTk_t						OperandB_AL;
	FTk_t						ResultAL;
	BTk_t						BTkA_AL;
	BTk_t						BTkB_AL;
	BTk_t						BTk_AL;


	//// Decode Configuration										////
	assign ConfigData		= I_Command[MSB_CFG:LSB_CFG];

	assign Opcode_MS		= I_Command[MSB_OPMS:LSB_OPMS];
	assign Opcode_AL		= I_Command[MSB_OPAL:LSB_OPAL];

	assign SelMS			= ConfigData[MSB_SELMS:MSB_SELMS];
	assign SelAL			= ( ConfigData[MSB_SELAL:LSB_SELAL] == 2'h0 ) | ConfigData[LSB_SELAL];

	assign Cond				= I_Cond[MSB_COND:LSB_COND];

	assign SelA				= ( ConfigData[1:0] == 2'h3 ) ?		2'h2 :
								( ConfigData[2:0] == 3'h5 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h4 ) ?	2'h0 :
								( ConfigData[2:0] == 3'h2 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h1 ) ?	2'h1 :
																2'h0;

	assign SelB				= ( ConfigData[1:0] == 2'h3 ) ?		2'h2 :
								( ConfigData[2:0] == 3'h5 ) ?	2'h0 :
								( ConfigData[2:0] == 3'h4 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h2 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h1 ) ?	2'h1 :
																2'h0;

	assign SelD				= ( ConfigData[1:0] == 2'h3 ) ?		1'b1 :
								( ConfigData[2:0] == 3'h2 ) ?	1'b1 :
								( ConfigData[2:1] == 2'h3 ) ?	1'b0 :
																1'b0;

	assign Cond_MS			= Cond;
	assign Cond_AL			= Cond;


	//// Valid Token                                                ////
	assign ValidA           = I_Active & ~( I_EnSrcA ^ I_OperandA.v );
	assign ValidB           = I_Active & ~( I_EnSrcB ^ I_OperandB.v );
	assign ValidC           = I_Active & ~( I_EnSrcC ^ I_OperandC.v );


	//// Immwdiate COnposition
	assign FTk_Imm.v		= 1'b1;
	assign FTk_Imm.a		= 1'b0;
	assign FTk_Imm.c		= 1'b0;
	assign FTk_Imm.r		= 1'b1;
	assign FTk_Imm.i		= '0;
	assign FTk_Imm.d		= '0 | I_Imm;


	//// Backward Token                                             ////
	assign BTk_MS			= ( SelMS ) ? I_BTk : '0;

	assign O_BTkA			= ( ConfigData == 3'h1 ) ?		BTkA_AL :
								( ConfigData == 3'h2 ) ?	BTkA_MS :
								( ConfigData == 3'h3 ) ?	BTkA_MS :
								( ConfigData == 3'h4 ) ?	'0 :
								( ConfigData == 3'h5 ) ?	BTkA_AL :
								( ConfigData == 3'h6 ) ?	BTkA_MS :
															BTkA_MS;

	assign O_BTkB			= ( ConfigData == 3'h1 ) ?		BTkB_AL :
								( ConfigData == 3'h2 ) ?	BTkB_MS :
								( ConfigData == 3'h3 ) ?	BTkB_MS :
								( ConfigData == 3'h4 ) ?	BTkB_AL :
								( ConfigData == 3'h5 ) ?	'0 :
								( ConfigData == 3'h6 ) ?	'0 :
															'0;

	assign O_BTkC			= ( ConfigData[1:0] == 2'h3 ) ? BTkB_AL :
															'0;


	//// Multiply and Shift Unit									////
	assign Active_MS		= I_Active & SelMS;

	assign EnSrcA_MS		= Active_MS;
	assign EnSrcB_MS		= ( SelD ) ?	Active_MS :
											'0;

	assign OperandA_MS		= ( SelMS ) ?	I_OperandA :
											'0;

	assign OperandB_MS		= ( SelD ) ?	I_OperandB :
											'0;

	MultShift MultShift
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			Active_MS					),
		.I_Opcode(			Opcode_MS					),
		.I_Cond(			Cond_MS						),
		.I_EnSrcA(			EnSrcA_MS					),
		.I_EnSrcB(			EnSrcB_MS					),
		.I_OperandA(		OperandA_MS					),
		.I_OperandB(		OperandB_MS					),
		.O_Result(			ResultMS					),
		.I_BTk(				BTk_MS						),
		.O_BTkA(			BTkA_MS						),
		.O_BTkB(			BTkB_MS						)
	);


	//// Addition and Logic Unit									/////
	assign Active_AL		= I_Active & SelAL;

	assign EnSrcA_AL		= Active_AL & I_EnSrcA;

	assign EnSrcB_AL		= ( SelAL & ( SelB == 2'h1 ) ) ?	Active_AL & I_EnSrcB :
								( ConfigData[1:0] == 2'h3 ) ?	Active_AL & I_EnSrcC :
																'0;

	assign OperandA_AL		= ( SelAL & ( SelA == 2'h1 ) ) ?	I_OperandA :
								( ConfigData[2:0] == 3'h4 ) ?	FTk_Imm :
								( SelA == 2'h2 ) ?				ResultMS :
																'0;

	assign OperandB_AL		= ( ConfigData[1:0] == 2'h3 ) ?		I_OperandC :
								( ConfigData[2:0] == 3'h5 ) ?	FTk_Imm :
								( SelAL & ( SelB == 2'h1 ) ) ?	I_OperandB :
																'0;

	assign BTk_AL			= ( Active_AL ) ?					I_BTk :
																'0;

	AddLogic AddLogic
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			Active_AL					),
		.I_Opcode(			Opcode_AL					),
		.I_Cond(			Cond_AL						),
		.I_EnSrcA(			EnSrcA_AL					),
		.I_EnSrcB(			EnSrcB_AL					),
		.I_OperandA(		OperandA_AL					),
		.I_OperandB(		OperandB_AL					),
		.O_Result(			ResultAL					),
		.I_BTk(				BTk_AL						),
		.O_BTkA(			BTkA_AL						),
		.O_BTkB(			BTkB_AL						)
	);


	//// Output														////
	assign O_Result			= ( SelMS ) ?	ResultMS :
								( SelAL ) ?	ResultAL :
											'0;

endmodule