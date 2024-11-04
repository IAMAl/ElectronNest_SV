///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Instruction Decoder
//	Module Name:	IDec
//	Function:
//					Instruction Decoder
//					used for connecting betwen Compute Tile and Global Buffer
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IDec
	import pkg_en::WIDTH_DATA;
	import pkg_en::FTk_t;
	import pkg_bram_if::*;
(
	input	FTk_t					I_Instr,			//Instruction
	output	logic					O_OpCode_Move,		//Move (Load-Store Comm.) Operation
	output							O_WAR_NEn,			//WAR Hazard Disable for Load/Store Unit
	output	[WIDTH_AID-1:0]			O_ADstID,			//Architecture-defined Destination ID
	output	[WIDTH_AID-1:0]			O_ASrcID			//Architecture-defined Source ID
);


	//// Operation Code												////
	// Opcode[1:0] Assignment
	//	00:	No Operation (NOP)
	//	01:	Control
	//	10: Move
	//	11: Reserved
	logic						OpCode_Move;
	logic [3:0]					Func;

	assign OpCode_Move		= I_Instr.d[POS_OPCODE_MSB:POS_OPCODE_LSB] == 4'h3;
	assign O_OpCode_Move	= OpCode_Move;

	// Function Code for Opcode
	assign Func				= I_Instr.d[POS_FUNC_MSB:POS_FUNC_LSB];
	assign O_WAR_NEn		= I_Instr.d[WIDTH_DATA-1];


	//// Architecture-Defined Index									////
	//	 Destination
	assign O_ADstID			= I_Instr.d[POS_ADSTID_MSB:POS_ADSTID_LSB];

	//	 Source
	assign O_ASrcID			= I_Instr.d[POS_ASRCID_MSB:POS_ASRCID_LSB];

endmodule
