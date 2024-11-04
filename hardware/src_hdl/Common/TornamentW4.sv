///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Tournament (Base-4) Unit
//		Module Name:	TournamentW4
//		Function:
//						Base unit for TournamentW
//						Select One Entry having Smallest Value
//						Generate One Valid for Winner
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module TournamentW4
import pkg_bram_if::*;
(
	input	[WIDTH_UNITS:0]			I_Entry0,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry1,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry2,						//Tournament-Entry
	input	[WIDTH_UNITS:0]			I_Entry3,						//Tournament-Entry
	output 	[WIDTH_UNITS:0]			O_Entry,						//Winning Entry
	output	logic					O_Valid,						//Flag:Output-Validation
	output							O_Valid0,						//Win-Validation
	output							O_Valid1,						//Win-Validation
	output							O_Valid2,						//Win-Validation
	output							O_Valid3						//Win-Validation
);

	parameter WUNITS			= $clog2(WIDTH_UNITS);


	//// Logic Connect												////
	logic						Less3than2;
	logic						Less1than0;

	logic	[WIDTH_UNITS:0]		Entry_3Lt2;
	logic	[WIDTH_UNITS:0]		Entry_1Lt0;

	logic						TTGt31;
	logic	[WIDTH_UNITS:0]		Entry_TTGt31;

	logic	[WUNITS:0]			EncIn;
	logic	[WIDTH_UNITS-1:0]	OneHot_Encode;


	//// Validate Inputs											////
	assign O_Valid			= I_Entry0[WIDTH_UNITS] |
								I_Entry1[WIDTH_UNITS] |
								I_Entry2[WIDTH_UNITS] |
								I_Entry3[WIDTH_UNITS];


	//// Select-Tree												////
	assign Less3than2		= I_Entry3 < I_Entry2;
	assign Less1than0		= I_Entry1 < I_Entry0;
	assign Entry_3Lt2		= ( Less3than2 ) ? I_Entry3 : I_Entry2;
	assign Entry_1Lt0		= ( Less1than0 ) ? I_Entry1 : I_Entry0;

	assign TTGt31			= Entry_3Lt2 < Entry_1Lt0;
	assign Entry_TTGt31		= ( TTGt31 ) ? Entry_3Lt2 : Entry_1Lt0;


	//// Output														////
	//	 Winner's Entry-No
	assign O_Entry			= Entry_TTGt31;

	assign EncIn			= { TTGt31, Less3than2, Less1than0 };
	assign OneHot_Encode[3]	=  EncIn[2] &  EncIn[1];
	assign OneHot_Encode[2]	=  EncIn[2] & ~EncIn[1];
	assign OneHot_Encode[1]	= ~EncIn[2] &  EncIn[0];
	assign OneHot_Encode[0]	= ~EncIn[2] & ~EncIn[0];

	//	 Validation (Grant Ack)
	assign O_Valid0			= OneHot_Encode[0];
	assign O_Valid1			= OneHot_Encode[1];
	assign O_Valid2			= OneHot_Encode[2];
	assign O_Valid3			= OneHot_Encode[3];

endmodule
