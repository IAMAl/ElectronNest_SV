///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load/Store Unit
//		Module Name:	LdStUnit
//		Function:
//						Load/Store Unit for External Access
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module LdStUnit
	import  pkg_en::FTk_t;
	import  pkg_en::BTk_t;
	import	pkg_extend_index::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int WIDTH_ADDR		= 10,
	parameter int WIDTH_LENGTH		= 10,
	parameter int WIDTH_UNIT		= 8,
	parameter int NUM_MEMUNIT		= 4,
	parameter int SIZE_CRAM			= 256,
	parameter int ExtdConfig		= 0
)(
	input							clock,
	input							reset,
	input							I_Boot,							//Boot Signal
	input	FTk_t					I_FTk,							//Input Forward-Tokens
	output	BTk_t					O_BTk,							//Output Backward-Tokens
	output	FTk_t					O_FTk,							//Output Forward-Tokens
	input	BTk_t					I_BTk,							//Input Backward-Tokens
	output							O_Ld_Req,						//Request for Loading
	output	[1:0]					O_Ld_Mode,						//Accesss-Mode
	output	[WIDTH_ADDR-1:0]		O_Ld_Address,					//Mmeory Address
	input	FTk_t					I_Ld_Data,						//Loading Data
	output	BTk_t					O_Ld_BTk,						//Responce to Loading Source
	output							O_St_Req,						//Request for Storing
	output	[1:0]					O_St_Mode,						//Accesss-Mode
	output	[WIDTH_ADDR-1:0]		O_St_Address,					//Mmeory Address
	output	FTk_t					O_St_Data,						//Storing Data
	input	FTk_t					I_St_FTk,						//Storing Data
	output	BTk_t					O_St_BTk,						//Responce to Storing Source
	input	BTk_t					I_St_BTk						//Respence from Storing Destination
);

	localparam int WIDTH_INDEX			= $clog2(SIZE_CRAM);
	localparam int WIDTH_BLOCK_LENGTH	= 8;

	//	 Quad Datum Width
	localparam int POS_B0		= WIDTH_DATA/4;
	localparam int POS_B1		= POS_B0*2;
	localparam int POS_B2		= POS_B0*3;
	localparam int POS_B3		= POS_B0*4;

	//	 NUmber of Bytes in a Data Word
	localparam int NUM_BYTES	= WIDTH_DATA / WIDTH_UNIT;


	//// Logic Connect												////
	logic						St_AccessEnd;
	logic						Ld_AccessEnd;

	logic						Ld_Busy;
	logic						St_Busy;

	logic						is_Zero;


	//// Store Path													////
	logic						St_Req;				// Store Request
	logic [WIDTH_ADDR-1:0]		St_Addr;			// Store Address
	FTk_t						St_Data;			// Store Data
	logic [1:0]					St_Mode;			// Store Mode

	//	 End of Store Flag
	logic						End_St;


	//// Load Path													////
	logic						Ld_Req;				// Load Request
	logic [WIDTH_ADDR-1:0]		Ld_Addr;			// Load Address
	FTk_t						Ld_Data;			// Load Data
	logic [1:0]					Ld_Mode;			// Load Mode


	//	 End of Loading
	logic						End_Load;
	logic						End_Ld;


	//// Capture Boot Signal										////
	logic					R_Boot;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Boot			<= 1'b0;
		end
		else begin
			R_Boot			<= I_Boot;
		end
	end


	//// Storing Data												////
	assign O_St_Req			= St_Req;
	assign O_St_Mode		= St_Mode;
	assign O_St_Address		= St_Addr;
	assign O_St_Data		= St_Data;
	assign End_St			= St_Data.r;


	//// Loading Data												////
	assign O_Ld_Req			= Ld_Req;
	assign O_Ld_Mode		= Ld_Mode;
	assign O_Ld_Address		= Ld_Addr;

	// Loading Data Word Composition
	assign Ld_Data.v		= I_Ld_Data.v;
	assign Ld_Data.a		= 1'b0;
	assign Ld_Data.r		= 1'b0;
	assign Ld_Data.c		= 1'b0;
	assign Ld_Data.d		= I_Ld_Data.d;
	assign Ld_Data.i		= I_Ld_Data.i;

	// End of Loading
	assign End_Ld			= End_Load;

	assign is_Zero			= '0;


	//// Store Server												////
	CRAM_St #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.NumWordsLength(	1							),
		.NumWordsStride(	1							),
		.NumWordsBase(		1							),
		.EXTERN(			1							)
	) CRAM_St
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				I_St_FTk					),
		.O_BTk(				O_St_BTk					),
		.O_St_Req(			St_Req						),
		.O_St_Addr(			St_Addr						),
		.O_St_FTk(			St_Data						),
		.I_St_BTk(			I_St_BTk					),
		.O_Mode(			St_Mode						),
		.O_AccessEnd(		St_AccessEnd				),
		.I_St_End(			End_St						),
		.O_Busy(			St_Busy						)
	);


	//// Load Server												////
	LdUnit #(
		.EXTERNAL(			1							),
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) LdUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Boot(			R_Boot						),
		.is_Zero(			is_Zero						),
		.is_Shared(			1'b0						),
		.I_Shared_Data(		'0							),
		.I_FTk(				I_FTk						),
		.O_BTk(				O_BTk						),
		.O_FTk(				O_FTk						),
		.I_BTk(				I_BTk						),
		.I_Ld_FTk(			Ld_Data						),
		.O_Ld_BTk(			O_Ld_BTk					),
		.O_Req(				Ld_Req						),
		.O_AccessMode(		Ld_Mode						),
		.O_Address(			Ld_Addr						),
		.O_End_Load(		End_Load					),
		.O_Busy(			Ld_Busy						)
	);

endmodule
