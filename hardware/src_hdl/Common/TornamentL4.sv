///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Tournament (Base-4) Unit
//		Module Name:	TournamentL4
//		Function:
//						Base unit for TournamenL
//						Select One Entry having Largest Value
//						Generate One Valid for Winner
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module TournamentL4
import pkg_bram_if::*;
(
	input	[WIDTH_UNITS:0]			I_Entry0,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry1,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry2,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry3,						//Tournament-Entry
	output 	[WIDTH_UNITS:0]			O_Entry,						//Winning Entry
	output	logic					O_Valid,						//Flag:Output-Validation
	output	logic					O_Valid0,						//Win-Validation
	output	logic					O_Valid1,						//Win-Validation
	output	logic					O_Valid2,						//Win-Validation
	output	logic					O_Valid3						//Win-Validation
);


	//// Logic Connect												////
	logic						Great2than3;
	logic						Great0than1;

	logic	[WIDTH_UNITS:0]		Entry_TGt2;
	logic	[WIDTH_UNITS:0]		Entry_OGt0;

	logic						TTGt10;
	logic	[WIDTH_UNITS:0]		Entry_TTGt10;


	//// Validate Inputs											////
	assign O_Valid			= I_Entry0[WIDTH_UNITS] |
								I_Entry1[WIDTH_UNITS] |
								I_Entry2[WIDTH_UNITS] |
								I_Entry3[WIDTH_UNITS];


	//// Select-Tree												////
	assign Great2than3		= I_Entry3 < I_Entry2;
	assign Great0than1		= I_Entry1 < I_Entry0;
	assign Entry_TGt2		= ( Great2than3 ) ? I_Entry2 : I_Entry3;
	assign Entry_OGt0		= ( Great0than1 ) ? I_Entry0 : I_Entry1;

	assign TTGt10			= Entry_TGt2 < Entry_OGt0;
	assign Entry_TTGt10		= ( TTGt10 ) ? Entry_OGt0 : Entry_TGt2;


	//// Output														////
	//	 Winner's Entry-No
	assign O_Entry			= Entry_TTGt10;

	//	 Validation (Grant Ack)
	assign O_Valid0			=  TTGt10 &  Great0than1;
	assign O_Valid1			=  TTGt10 & ~Great0than1;
	assign O_Valid2			= ~TTGt10 &  Great2than3;
	assign O_Valid3			= ~TTGt10 & ~Great2than3;

endmodule
