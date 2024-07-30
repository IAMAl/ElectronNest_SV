///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Package for Reconfigurable ALU
//	Package Name:	pkg_alu
//	Function:
//                  used for reconfigurable ALU
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_alu;
import pkg_en::*;


	`define PIPE_MLT


	//// Parameters in ALU											////
	parameter int WIDTH_CMD			= 24;

	//	 Constant (used in DataPath) Width
	parameter int WIDTH_CONSTANT	= 8;

	//	 Opcode for Mult/Shift
	parameter int WIDTH_OPMS		= 5;

	//	 Opcode for Add/Logic
	parameter int WIDTH_OPAL		= 7;

	//	 Condition LUT
	parameter int WIDTH_COND		= 8;

	//	 Command
	parameter int MSB_COMMAND		= WIDTH_DATA-1;
	parameter int LSB_COMMAND		= WIDTH_DATA-WIDTH_CMD;

	//	 Configuration Data
	parameter int MSB_CFG			= 23;
	parameter int LSB_CFG			= 21;

	//	 Select Mult/Shift
	parameter int MSB_SELMS			= 1;
	parameter int LSB_SELMS			= 0;

	//	 Select Add/Logic
	parameter int MSB_SELAL			= 1;
	parameter int LSB_SELAL			= 0;

	//	 Opcode for Mult/Shift
	parameter int MSB_OPMS			= 20;
	parameter int LSB_OPMS			= 16;

	//	 Opcode for Add/Logic
	parameter int MSB_OPAL			= 14;
	parameter int LSB_OPAL			=  8;

	//	 Condition Code
	parameter int MSB_COND			=  7;
	parameter int LSB_COND			=  0;


	//// Base Types													////
	typedef logic	[WIDTH_CONSTANT-1:0]	const_t;

	typedef logic	[WIDTH_OPMS-1:0]		opcode_ms_t;
	typedef logic	[WIDTH_OPAL-1:0]		opcode_al_t;
	typedef logic	[WIDTH_COND-1:0]		cond_t;


	//// FSM State													////
	//	 Wait Unit
	typedef enum logic [1:0] {
		eMPTY_W				= 2'b00,
		fILL_W				= 2'b01,
		wAIT_W				= 2'b10,
		cHECK_W				= 2'b11
	} fsm_wait;

	//	 ALU Port
	typedef enum logic [3:0] {
		iNIT				= 4'h0,
		hEADER				= 4'h1,
		cHK_ATTRIB			= 4'h2,
		rOUTE				= 4'h3,
		pCONFIG				= 4'h4,
		rCONFIG				= 4'h5,
		bYPASS				= 4'h6,
		oUT_ATTRIB			= 4'h7,
		wAIT_OPRAND 		= 4'h8,
		wAIT_DATA			= 4'h9,
		dATA				= 4'ha,
		eND_SEQ				= 4'hb,
		sHARED				= 4'hc
	} fsm_port;


	//// Opcode Encodings											////
	//	 Add Unit
	//			Operation
	typedef enum logic [1:0] {
		Unsigned_Out_Add	= 2'b00,
		Unsigned_Out_Sub	= 2'b01,
		Signed_Out_Add		= 2'b10,
		Signed_Out_Sub		= 2'b11
	} AddOp;

	//			Constant
	typedef enum logic {
		Op_Var_A			= 1'b0,
		Op_Cst_A			= 1'b1
	} AddConst;

	//			Opcode
	typedef struct packed {
		AddOp				OpAdd;
		AddConst			OpConst;
	} op_add_t;

	//	 Mlt Unit
	//		Operation
	typedef enum logic {
		uuMlt				= 1'b0,
		ssMlt				= 1'b1
	} MultOp;

	//		Constant
	typedef enum logic {
		Op_Var_M			= 1'b0,
		Op_Cst_M			= 1'b1
	} MultConst;

	//		Opcode
	typedef struct packed {
		MultOp				OpMult;
		MultConst			OpConst;
	} op_mult_t;

	//	MltAddUnit Opcode
	typedef enum logic [1:0] {
		Add					= 2'b00,
		Mlt					= 2'b01,
		Mlt_Add				= 2'b10,
		Mad					= 2'b11
	} MultAdd;

	//	 ShiftUnit
	//		Operation
	typedef enum logic [1:0] {
		LRSHFT				= 2'b00,
		ARSHFT				= 2'b01,
		LLSHFT				= 2'b10,
		ROTATE				= 2'b11
	} ShiftOp;

	//		Constant
	typedef enum logic {
		Op_Var_S			= 1'b0,
		Op_Cst_S			= 1'b1
	} ShiftConst;

	//		Opcode
	typedef struct packed {
		ShiftOp				OpShift;
		ShiftConst			OpConst;
	} op_shift_t;

	//	Logic Unit
	//		Operation
	typedef enum logic [1:0] {
		Op_Awy				= 2'b00,
		Op_And				= 2'b01,
		Op_Or				= 2'b10,
		Op_Xor				= 2'b11
	} LogicOp;

	//			Not Select
	typedef enum logic {
		Op_Any				= 1'b0,
		Op_Not				= 1'b1
	} LogicNot;

	//			Constant
	typedef enum logic {
		Op_Var_L			= 1'b0,
		Op_Cst_L			= 1'b1
	} LogicConst;

	//			Opcode
	typedef struct packed {
		LogicOp				OpLogic;
		LogicNot			OpNot;
		LogicConst			OpConst;
	} op_logic_t;

endpackage