///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Shifter
//	Module Name:	ShiftUnit
//	Function:
//					execute logic/arithmatic shift
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module ShiftUnit
	import	pkg_en::*;
	import	pkg_alu::*;
(
	input							I_En,				//Enable to Execute
	input	opcode_ms_t				I_Opcode,			//Opcode
	input	cond_t					I_Cond,				//Condition LUT
	input	FTk_t					I_OperandA,			//Source Operand
	input	FTk_t					I_OperandB,			//Source Operand
	output	FTk_t					O_Result,			//Result
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTk				//Backward Tokens
);


	//// Opcode Assignment											////
	logic						LeftRotate;
	logic						ArithRight;
	logic						SelLeftShift;
	logic						OutCondB;
	logic						OutCondF;

	logic						Valid;

	logic	[$clog2(WIDTH_DATA)-1:0] ShiftAmount;

	logic	[WIDTH_DATA*2-1:0]	LeftSourceA;
	logic	[WIDTH_DATA*2-1:0]	LeftShifted;
	logic	[WIDTH_DATA-1:0]	LeftResult;
	logic	[WIDTH_DATA-1:0]	RightSourceA;
	logic	[WIDTH_DATA-1:0]	RightResult;
	logic	[WIDTH_DATA-1:0]	Result;

	logic	[WIDTH_COND-1:0]	LUTAddr;
	logic						Cond;


	always_comb begin
		case ( I_Opcode[1:0] )
			2'b00: begin	//Arithmetic Right
				LeftRotate		= 1'b0;
				ArithRight		= 1'b1;
				SelLeftShift	= 1'b0;
			end
			2'b01: begin	//Logic Right
				LeftRotate		= 1'b0;
				ArithRight		= 1'b0;
				SelLeftShift	= 1'b0;
			end
			2'b10: begin	//Logic Left
				LeftRotate		= 1'b0;
				ArithRight		= 1'b0;
				SelLeftShift	= 1'b1;
			end
			2'b11: begin	//Rotate Left
				LeftRotate		= 1'b1;
				ArithRight		= 1'b0;
				SelLeftShift	= 1'b1;
			end
		endcase
	end

	assign OutCondB			= I_Opcode[2];
	assign OutCondF			= I_Opcode[3];


	//// Shift Amount												////
	assign ShiftAmount		= I_OperandB.d[$clog2(WIDTH_DATA)-1:0];


	//// Left-Shift and Rotate										////
	assign LeftSourceA		= { 0 | I_OperandA.d };
	assign LeftShifted		= LeftSourceA << ShiftAmount;
	assign LeftResult		= ( LeftRotate ) ?	LeftShifted[WIDTH_DATA-1:0] | LeftShifted[WIDTH_DATA*2-1:WIDTH_DATA] :
												LeftShifted[WIDTH_DATA-1:0];


	//// Right-Shift												////
	assign RightSourceA		= I_OperandA.d;

	assign  RightResult		= ( ArithRight ) ?	RightSourceA >>> ShiftAmount :
												RightSourceA >> ShiftAmount;


	//// Shift Result Selection										////
	assign Result			= ( SelLeftShift ) ? LeftResult : RightResult;

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
	assign LUTAddr			= { I_OperandB[WIDTH_DATA-1:$clog2(WIDTH_DATA)] != '0, LeftShifted[WIDTH_DATA-1:$clog2(WIDTH_DATA)] != '0, Result == '0 };
	assign Cond				= I_Cond[ LUTAddr ];

	assign O_BTk.n			= I_BTk.n;
	assign O_BTk.t			= I_BTk.t;
	assign O_BTk.v			= ( OutCondB ) ? I_OperandA.c : I_BTk.v;
	assign O_BTk.c			= ( OutCondB ) ? Cond :			I_BTk.c;

endmodule