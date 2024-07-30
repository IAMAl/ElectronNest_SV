///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load/Store Unit for Retiming Element
//		Module Name:	ReLdStUnit
//		Function:
//						Load unit and Store unit are integrated in this module.
//						The module is used for retiming element.
//						Load and store units have its own request, access-mode and address ports.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module ReLdStUnit
	import  pkg_en::*;
	import	pkg_mem::DEPTH_FIFO_LDST;
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
	output	BTk_t					O_St_BTk,						//Backward Token for Storing
	input	BTk_t					I_St_BTk						//Responce from Storing Destination
);

	localparam int WIDTH_INDEX	= $clog2(SIZE_CRAM);

	//	 Quad Datum Width
	localparam int POS_B0		= WIDTH_DATA/4;
	localparam int POS_B1		= POS_B0*2;
	localparam int POS_B2		= POS_B0*3;
	localparam int POS_B3		= POS_B0*4;

	//	 Number of Bytes in a Data Word
	localparam int NUM_BYTES	= WIDTH_DATA / WIDTH_UNIT;


	//// Logic Connect												////
	// End of Access
	logic						St_AccessEnd;
	logic						Ld_AccessEnd;


	// State in Busy
	logic						Ld_Busy;
	logic						St_Busy;

	logic						is_Zero;


	//// Branch to CRAM_St or CRAM_Ld								////
	// StLdRAM -> CRAM_St
	FTk_12_t					StLdCRAM_O_FTk;
	BTk_12_t					StLdCRAM_I_BTk;

	FTk_t						StLd_FTk;
	BTk_t						StLd_O_BTk;

	FTk_t						StLd_O_FTk;


	//// Store Path													////
	FTk_t						St_FTk_Path;		// Forward for Store
	BTk_t						St_BTk_Path;		// Back-Prop for Store
	logic						St_Req;				// Store Request
	logic [WIDTH_ADDR-1:0]		St_Addr;			// Store Address
	FTk_t						St_Data;			// Store Data
	logic [1:0]					St_Mode;			// Store Mode

	//	 End of Store Flag
	logic						End_St;				// End of Storing


	//// Load Path													////
	//	 Load Enable (retiming)
	logic						Ld_En;

	//	 Load Path
	FTk_t						Ld_FTk_Path;		// Forward for Load
	BTk_t						Ld_BTk_Path;		// Back-Prop for Load
	logic						Ld_Req;				// Load Request
	logic [WIDTH_ADDR-1:0]		Ld_Addr;			// Load Address
	FTk_t						Ld_Data;			// Load Data
	logic [1:0]					Ld_Mode;			// Load Mode

	FTk_t						Ld_FTk_CRAM;		// Output from Load unit
	BTk_t						Ld_BTk_CRAM;		// Input to Load unit
	FTk_t						Ld_FTk_CRAM_Bps;	// Input to MFA unit (Bypassing)

	//	 End of Loading
	logic						End_Load;			// End of Loading
	logic						End_Ld;				// Intermediate (needed for extension)

	//	 Extension
	logic						Ld_Index_En;		// Enable to Index Unit
	logic						End_Index;			// Flag: End of Loading
	logic						Busy_MFA;			// Flag: MFA unit is Busy
	logic						is_SharedAttrib;	// Flsg: Shared in Attribute Word
	logic						is_SharedConfig;	// Flag: Shared in R-Config Data
	logic						Str_Restore;		// Start Restoring
	logic						Run_Restore;		// Running State
	logic						W_Restore;			// State in Restoring
	logic						Send_Shared;		// Send Shared Data Word
	logic						NeLoad;				// Disable Loading

	logic						is_Shared;

	logic	[WIDTH_LENGTH+1:0]	Actual_Length;


	//// Capture Signal												////
	logic						R_Boot;
	logic						R_Ld_AccessEnd;
	logic						R_Ld_AccessEndD1;


	////
	assign O_St_Req			= St_Req;
	assign O_St_Mode		= St_Mode;
	assign O_St_Address		= St_Addr;
	assign O_St_Data		= St_Data;
	assign O_St_BTk			= St_BTk_Path;

	assign End_St			= St_Data.r;


	//// Loading Data												////
	assign O_Ld_Req			= Ld_Req;
	assign O_Ld_Mode		= Ld_Mode;
	assign O_Ld_Address		= Ld_Addr;

	assign O_FTk			= ( Busy_MFA | NeLoad | Run_Restore ) ? '0 : Ld_FTk_CRAM_Bps;


	//// Branch to Store/Load Path									////
	assign StLdCRAM_I_BTk[0]= StLd_O_BTk;

	assign StLd_FTk.v		= ( I_FTk.v & ~I_Boot ) | Busy_MFA;
	assign StLd_FTk.a		= I_FTk.a;
	assign StLd_FTk.c		= I_FTk.c;
	assign StLd_FTk.r		= I_FTk.r;
	`ifdef EXTEND
	assign StLd_FTk.i		= I_FTk.i;
	`endif
	assign StLd_FTk.d		= I_FTk.d;

	FanOut_Link #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.NUM_LINK(			2							),
		.NUM_CHANNEL(		1							),
		.WIDTH_LENGTH(		WIDTH_ADDR					),
		.DEPTH_FIFO(		DEPTH_FIFO_LDST				),
		.TYPE_FTK(			FTk_12_t					),
		.TYPE_BTK(			BTk_12_t					),
		.TYPE_BITS(			bit_12_t					),
		.TYPE_I_FTK(		FTk_1_t						),
		.TYPE_O_BTK(		BTk_1_t						)
	) StLdCRAM
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				StLd_FTk					),
		.O_BTk(				O_BTk						),
		.O_FTk(				StLdCRAM_O_FTk				),
		.I_BTk(				StLdCRAM_I_BTk				),
		.O_InC(											)
	);


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Boot			<= 1'b0;
		end
		else begin
			R_Boot			<= I_Boot;
		end
	end

	assign StLd_O_FTk		= StLdCRAM_O_FTk[0];


	`ifdef EXTEND_MEM
	//// With Extension												////
	logic						St_End;

	//	 Avoid Unnecesary Storing
	logic						Next_Restore;

	//	 Write Enable for Index Memory
	logic						We_Index;

	//	 Write Index Value
	logic	[WIDTH_INDEX-1:0]	W_Index;

	//	 Read Index Value
	logic	[WIDTH_INDEX-1:0]	R_Index;

	//	 Bypass for Shared Data Word
	logic	[WIDTH_DATA-1:0]	Shared_Data;

	//	 Shared Data Token Composition
	FTk_t						Ld_Shared_FTk_CRAM;

	//	Load having Non-Zero Shared Data Word
	logic						Ld_is_NotZero;
	logic						Ld_Nack;

	always_ff @( posedge clock ) begin: ld_nack
		if ( reset ) begin
			Ld_Nack		<= 1'b0;
		end
		else begin
			Ld_Nack		<= Ld_BTk_CRAM.n;
		end
	end

	assign Ld_En			= Ld_Req;
	assign W_Restore		= Str_Restore | Run_Restore;
	assign Ld_Index_En		= ( W_Restore ) ? Ld_Req & ~Ld_Nack : Ld_Req & is_SharedConfig;

	assign End_Ld			= 	( Str_Restore ) ? 	1'b0 : End_Load;

	assign Ld_Shared_FTk_CRAM.v	= 1'b1;
	assign Ld_Shared_FTk_CRAM.a	= 1'b0;
	assign Ld_Shared_FTk_CRAM.c	= 1'b0;
	assign Ld_Shared_FTk_CRAM.r	= 1'b0;
	assign Ld_Shared_FTk_CRAM.i	= '0;
	assign Ld_Shared_FTk_CRAM.d	= Shared_Data;

	//	 Wrapping
	assign Ld_FTk_CRAM_Bps	= Ld_FTk_CRAM;

	//	 Loading Data Word Select and Composition
	assign Send_Shared		= '0;
	assign Ld_Data.v		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.v	: I_Ld_Data.v;
	assign Ld_Data.a		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.a	:
								( Run_Restore ) ?	R_Ld_AccessEndD1		: End_Index;
	assign Ld_Data.r		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.r	| End_Index :
								( Run_Restore ) ?	R_Ld_AccessEndD1		: End_Index;
	assign Ld_Data.c		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.c	: 1'b0;
	assign Ld_Data.i		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.i	: R_Index;
	assign Ld_Data.d		= ( Send_Shared ) ?		Ld_Shared_FTk_CRAM.d	: I_Ld_Data.d;

	//	 Most Significantly Appeared Value Handling
	BTk_t					StLdCRAM_BTk;
	assign StLdCRAM_I_BTk[1][0]		= StLdCRAM_BTk;

	assign is_Zero			= ~Ld_is_NotZero;

	FTk_t					MFA_FTk;
	assign MFA_FTk			= StLd_O_FTk;

	BTk_t					MFA_BTk;
	assign StLd_O_BTk		= MFA_BTk;

	MFA_CRAM MFA_Extd (
		.clock(				clock						),
		.reset(				reset						),
		.I_Ld_Bps(			Ld_FTk_CRAM_Bps				),			//Bypassing from Loading Path
		.I_Ld_FTk(			MFA_FTk						),			//Load Config. Data from StLdCRAM
		.O_Ld_FTk(			Ld_FTk_Path					),			//to Ld_BTk_Path Ld_CRAM
		.I_Ld_BTk(			Ld_BTk_Path					),			//from Ld_BTk_Path Ld_CRAM
		.O_Ld_BTk(			MFA_BTk						),			//to StLdCRAM
		.I_End_Ld(			Ld_FTk_Path.r				),			//Flag: End of Loading
		.I_Ld_End(			End_Ld						),			//End of Access for Loading
		.I_St_FTk(			StLdCRAM_O_FTk[1]			),			//Store Config. Data from StLdCRAM
		.O_St_FTk(			St_FTk_Path					),			//to St_CRAM
		.I_St_BTk(			St_BTk_Path					),			//from StLDCRAM
		.O_St_BTk(			StLdCRAM_BTk				),			//to StLdCRAM
		.I_End_St(			End_St						),			//Flag: End of Storing
		.I_St_End(			St_End						),			//End of Access for Storing
		.I_Index(			R_Index						),			//Read Index from IndexCODEC
		.is_SharedConfig(	is_SharedConfig				),			//Flag: Share Flag in Attribute Word for RConfig
		.is_SharedAttrib(	is_SharedAttrib				),			//Flag: Share Flag in Attribute Word for Data
		.O_Busy_MFA(		Busy_MFA					),			//Flag: MFA is in busy state
		.O_Str_Restore(		Str_Restore					),			//Flag: Start Restoring
		.O_Run_Restore(		Run_Restore					),			//Flag: State in Restroring
		.O_NeLoad(			NeLoad						),			//Flag: Not-Enable Loading
		.O_Next_Restore(	Next_Restore				),			//Flag: Doing Restore at next phase
		.O_Shared_Valid(	is_Shared           	  	),			//Flag: Sharing is Valid
		.O_Shared_Data(		Shared_Data					),			//Shared Data Word (Value)
		.O_is_NotZero(		Ld_is_NotZero				),			//Flag: Shared Value is Not Zero
		.O_LengthAttrib(	Actual_Length				)
	);


	//// Index Storage												////
	//	 Write-Index
	assign W_Index			= ( is_SharedAttrib & Busy_MFA ) ?	StLd_O_FTk.i :
								( Run_Restore ) ?				St_Data.i :
																St_Addr;

	//	 Write-Enable
	assign We_Index			= ( is_SharedConfig & Busy_MFA ) ?	St_Data.v :
								( Run_Restore ) ?				St_Data.v :
																1'b0;

	assign St_End			= St_AccessEnd & ~Next_Restore;

	assign Ld_BTk_CRAM		= Busy_MFA ? '0 : I_BTk;

	IndexMem #(
		.WIDTH_ADDR(		WIDTH_INDEX					),
		.WIDTH_INDEX(		WIDTH_INDEX					)
	) IndexMem
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_Index					),
		.I_Re(				Ld_Index_En					),
		.I_Restore(			Run_Restore					),
		.is_Share(			is_SharedConfig				),
		.I_Index(			W_Index						),
		.O_Index(			R_Index						),
		.I_St_End(			St_End						),
		.I_Ld_End(			St_FTk_Path.r				),
		.O_Ld_End(			End_Index					)
	);

	`else
	//// Without Extension											////
	//
	assign is_SharedConfig	= 1'b0;

	// Not Use of Shared
	assign is_SharedAttrib	= 1'b0;

	// End of Loading
	assign End_Ld			= End_Load;

	// Not Use of MFA
	assign Busy_MFA			= 1'b0;

	// Loading Data Word Composition
	assign Ld_Data.v		= I_Ld_Data.v;
	assign Ld_Data.a		= ( Run_Restore ) ? R_Ld_AccessEndD1 : End_Load;
	assign Ld_Data.r		= ( Run_Restore ) ? R_Ld_AccessEndD1 : End_Load;
	assign Ld_Data.c		= 1'b0;
	assign Ld_Data.d		= I_Ld_Data.d;

	// Path Wrapping
	assign Ld_FTk_Path		= StLd_O_FTk;
	assign Ld_BTk			= Ld_BTk_Path;

	// Store Path
	assign St_FTk_Path				= StLdCRAM_O_FTk[1];
	assign StLdCRAM_I_BTk[1][0]		= St_BTk_Path;

	assign Ld_BTk_CRAM		= I_BTk;

	assign is_Zero			= '0;
	assign is_Shared		= '0;
	assign Send_Shared		= '0;
	assign Shared_Data		= '0;
	`endif


	//// Store Server												////
	CRAM_St #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_ADDR(		WIDTH_LENGTH				),
		.NumWordsLength(	1							),
		.NumWordsStride(	1							),
		.NumWordsBase(		1							)
	) CRAM_St
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				St_FTk_Path					),
		.O_BTk(				St_BTk_Path					),
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
	//	 Timing Adjustment
	always_ff @( posedge clock ) begin: ff_accessend
		if ( reset ) begin
			R_Ld_AccessEnd	<= 1'b0;
			R_Ld_AccessEndD1<= 1'b0;
		end
		else if ( ~Ld_BTk_CRAM.n ) begin
			R_Ld_AccessEnd	<= End_Load;
			R_Ld_AccessEndD1<= R_Ld_AccessEnd;
		end
	end

	LdUnit #(
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				),
		.EXTERNAL(			0							)
	) LdUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Boot(			R_Boot						),
		.is_Zero(			is_Zero						),
		.is_Shared(			is_Shared & ~Run_Restore	),
		.I_Actual_Length(	Actual_Length				),
		.I_Shared_Data(		Shared_Data					),
		.I_FTk(				Ld_FTk_Path					),
		.O_BTk(				Ld_BTk_Path					),
		.O_FTk(				Ld_FTk_CRAM					),
		.I_BTk(				Ld_BTk_CRAM					),
		.I_Ld_FTk(			Ld_Data						),
		.O_Ld_BTk(			O_Ld_BTk					),
		.O_Req(				Ld_Req						),
		.O_AccessMode(		Ld_Mode						),
		.O_Address(			Ld_Addr						),
		.O_End_Load(		End_Load					),
		.O_Busy(			Ld_Busy						)
	);

endmodule