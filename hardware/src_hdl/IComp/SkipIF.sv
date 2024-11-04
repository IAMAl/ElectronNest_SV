///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Skip Interface
//	Module Name:	SkipIF
//	Function:
//					used for Index Compression
//					attatched to ALU
//					bypassing Data Word to Output Buffer
//					This unit works for synchronizing source operands.
//					DReg supports a retiming,
//						therefore the pipeline does not guarantee the timing.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module SkipIF
	import	pkg_en::*;
	import	pkg_extend_index::*;
#(
	parameter int SKIPVAL			= 32'h00000000,
	parameter int THRUVAL			= 32'h00000001,
	parameter int RESERVE			= 32'h00000000,
	parameter int VALIDSKIP 		= 1,
	parameter int VALIDTHRU 		= 1
)(
	input							I_En,				//Enable to Detect
	input	FTk_t					I_FTk_A,			//Source Data Word
	input	FTk_t					I_FTk_B,			//Source Data Word
	input	FTk_t					I_SFTk_A,			//Shared Data Word
	input	FTk_t					I_SFTk_B,			//Shared Data Word
	output	FTk_t 					O_FTk_A,			//To ALU logic circuit
	output	FTk_t					O_FTk_B,			//To ALU logic circuit
	output	logic					O_TS,				//Flag: Thru/Skip
	output	FTk_t					O_TSFTk_A,			//Thru/Skip Data Word
	output	FTk_t					O_TSFTk_B,			//Thru/Skip Data Word
	output	logic					O_Fired				//Flag: Fired for Output Buffer
);


	//// Logic Connect												////
	//	 Skip
	logic						EqSkipVal_A;
	logic						EqSkipVal_B;
	logic						EnSkip;

	//	 Equal to Shared Data
	logic						EqShareVal_A;
	logic						EqShareVal_B;

	//	 Remove Output for Skippinh
	logic						RemoveOutput;

	//	 Equal for Through
	logic						EqThruVal_A;
	logic						EqThruVal_B;
	logic						Thru;

	FTk_t						Reserve;
	FTk_t						Thrue;


	//// Skip Detection												////
	//	 Check Same Value as Skip Value
	assign EqSkipVal_A		= I_FTk_A.v & ( I_FTk_A.d == SKIPVAL ) & ( VALIDSKIP == 1 ) & I_SFTk_A.v & I_En;
	assign EqSkipVal_B		= I_FTk_B.v & ( I_FTk_B.d == SKIPVAL ) & ( VALIDSKIP == 1 ) & I_SFTk_B.v & I_En;
	assign EnSkip			= EqSkipVal_A | EqSkipVal_B;

	//	 Check Same Value as Shared Data
	assign EqShareVal_A		= I_FTk_A.v & ( I_FTk_A.d == I_SFTk_A.d ) & I_SFTk_A.v & I_En;
	assign EqShareVal_B		= I_FTk_B.v & ( I_FTk_B.d == I_SFTk_B.d ) & I_SFTk_B.v & I_En;


	//// Output-Remove Detection									////
	assign RemoveOutput		= ( EqSkipVal_A & EqShareVal_A ) | ( EqSkipVal_B & EqShareVal_B );


	//// Thru Detection												////
	assign EqThruVal_B		= I_FTk_A.v & ( I_FTk_A.d == THRUVAL ) & ( VALIDTHRU == 1 ) & I_En;
	assign EqThruVal_A		= I_FTk_B.v & ( I_FTk_B.d == THRUVAL ) & ( VALIDTHRU == 1 ) & I_En;
	assign Thru				= EqThruVal_A | EqThruVal_B;


	//// Output														////
	//	 Skip Value Composition
	assign Reserve.v		= 1'b1;
	assign Reserve.a		= 1'b0;
	assign Reserve.c		= 1'b0;
	assign Reserve.r		= I_FTk_A.r & I_FTk_B.r;
	assign Reserve.i		= I_FTk_A.i;
	assign Reserve.d		= RESERVE;

	//	 Zero Composition for Another Source for Thru
	assign Thrue.v			= 1'b1;
	assign Thrue.a			= 1'b0;
	assign Thrue.c			= 1'b0;
	assign Thrue.r			= 1'b0;
	assign Thrue.i			= 1'b0;
	assign Thrue.d			= '0;

	//	 To Output Buffer in case of Thru and SKip
	assign O_TSFTk_A		= ( RemoveOutput ) ? 	'0 :
								( EqThruVal_A ) ? 	I_FTk_A :
								( EqThruVal_B ) ?	Thrue :
								( EqSkipVal_A ) ?	Reserve :
													'0;

	assign O_TSFTk_B		= ( RemoveOutput ) ? 	'0 :
								( EqThruVal_B ) ?	I_FTk_B :
								( EqThruVal_A ) ?	Thrue :
								( EqSkipVal_B ) ?	Reserve :
													'0;

	//	 Flag indicating Thru and Skip
	assign O_TS				= ( EnSkip | Thru ) & ~RemoveOutput & ~Reserve.r;

	//	 To Execution Unit
	assign O_FTk_A			= ( Reserve.r ) ?		I_FTk_A :
								( RemoveOutput ) ?	'0 :
								( Thru ) ?			'0 :
								( EqSkipVal_A ) ?	'0 :
													I_FTk_A;

	assign O_FTk_B			= ( Reserve.r ) ?		I_FTk_B :
								( RemoveOutput ) ?	'0 :
								( Thru ) ?			'0 :
								( EqSkipVal_B ) ?	'0 :
													I_FTk_B;

	//	 To Output Buffer
	assign O_Fired			= ( O_FTk_A.v & O_FTk_B.v );

endmodule