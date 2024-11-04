///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Integer Adder
//	Module Name:	IntAddUnit
//	Function:
//					Integer Addition and Subtraction
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IntAddUnit
	import	pkg_en::*;
	import	pkg_alu::*;
#(
	parameter WIDTH_DATA			= 32
)(
	input							I_En,				//Enable to Execute
	input	opcode_al_t				I_Opcode,			//Opcode
	input	cond_t					I_Cond,				//Condition LUT
	input	FTk_t					I_OperandA,			//Source Operand
	input	FTk_t					I_OperandB,			//Source Operand
	output	FTk_t					O_Result,			//Result
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTk				//Backward Tokens
);


	//// Opcode Assignment											////
	logic						SelSub;
	logic	    				SelSigned;
	logic                       SelSaturate;
	logic						OutCondB;
	logic						OutCondF;

	logic 	[WIDTH_DATA-1:0]	SourceA;
	logic 	[WIDTH_DATA-1:0]	SourceB;

	logic						Valid;
	logic						CarryOut;

	logic	[WIDTH_DATA-1:0]	SelectedSourceB;
	logic	[WIDTH_DATA:0]		PreResult;
	logic	[WIDTH_DATA:0]		Result;
	logic	[WIDTH_COND-1:0]	LUTAddr;
	logic						Cond;


	assign SelSub			= I_Opcode[0];
	assign SelSigned		= I_Opcode[1];
	assign SelSaturate		= I_Opcode[2];

	assign OutCondB			= I_Opcode[4];
	assign OutCondF			= I_Opcode[5];


	//// Source Composition                                         ////
	assign SourceA			= I_OperandA.d;
	assign SourceB			= I_OperandB.d;

	assign SelectedSourceB  = ( SelSub ) ?   ~SourceB : SourceB;

	assign PreResult		= SourceA + SelectedSourceB + SelSub;
	assign CarryOut			= PreResult[WIDTH_DATA];
	assign Result			= ( SelSaturate & CarryOut ) ? -1 : PreResult[WIDTH_DATA-1:0];

	assign Valid			= I_OperandA.v & I_OperandB.v & I_En;

	assign O_Result.v		= Valid;
	assign O_Result.a		= I_OperandA.a;
	assign O_Result.c		= ( OutCondF ) ? Cond : I_OperandA.c;
	assign O_Result.r		= I_OperandA.r;
	`ifdef EXTEND
	assign O_Result.i		= I_OperandA.i;
	`endif
	assign O_Result.d		= Result;


	//// Condition Code Generation									////
	assign LUTAddr			= { 1'b0, CarryOut, Result[WIDTH_DATA-1:0] == '0 };

	assign Cond				= I_Cond[ LUTAddr ];

	assign O_BTk.n			= I_BTk.n;
	assign O_BTk.t			= I_BTk.t;
	assign O_BTk.v			= ( OutCondB ) ? I_OperandA.c : I_BTk.v;
	assign O_BTk.c			= ( OutCondB ) ? Cond :			I_BTk.c;

endmodule