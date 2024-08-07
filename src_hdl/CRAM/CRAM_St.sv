///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Store-Sequencer for CRAM
//		Module Name:	CRAM_St
//		Function:
//						Sequencer for Storing in On-Chip Memory
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module CRAM_St
	import	pkg_en::*;
	import	pkg_extend_index::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int WIDTH_ADDR		= 8,
	parameter int NumWordsLength	= 1,
	parameter int NumWordsStride	= 1,
	parameter int NumWordsBase		= 1,
	parameter int EXTERN			= 0
)(
	input							clock,
	input							reset,
	input	FTk_t					I_FTk,				//Recieve Storing Data
	output	BTk_t					O_BTk,				//Back-Prop for Storing Data
	output	logic					O_St_Req,			//Store Request
	output	[WIDTH_ADDR-1:0]		O_St_Addr,			//Store Address
	output	FTk_t					O_St_FTk,			//Store Data
	input	BTk_t					I_St_BTk,			//Back-Prop for Store
	output	[1:0]					O_Mode,				//Access Mode
	output	logic					O_AccessEnd,		//End of Access
	input							I_St_End,			//Flag: used for Restoring
	output	logic					O_Busy				//Flag: State in Busy
);


	//// Logic Connect												////
	//		Token
	logic						Valid;
	logic						Nack;

	//		Token Decode
	FTk_t						TokenDec_I_FTk;
	logic						acq_message;
	logic						rls_message;
	logic						acq_flagmsg;
	logic						rls_flagmsg;
	logic	 					is_Acq;
	logic	 					is_Rls;

	logic						W_Set_Config;
	logic						Rls;
	logic						Trm;

	//		Attribute Word Decode
	logic	[WIDTH_DATA-1:0]	Attribute_St_I_Data;
	logic						Attribute_St_is_PullReq;
	logic						Attribute_St_is_DataWord;
	logic						Attribute_St_is_RConfigData;
	logic						Attribute_St_is_PConfigData;
	logic						Attribute_St_is_RoutingData;
	logic						Attribute_St_is_Shared;
	logic						Attribute_St_is_NonZero;
	logic						Attribute_St_is_Dense;
	logic						Attribute_St_is_MyAttribute;
	logic						Attribute_St_is_Term_Block;
	logic						Attribute_St_is_In_Cond;
	logic	[WIDTH_LENGTH-1:0]	Attribute_St_O_Length;

	//		Control Finite State Machie
	logic						CRAM_FSM_St_I_Valid;
	logic						CRAM_FSM_St_I_Nack;
	logic						CRAM_FSM_St_is_Acq;
	logic						CRAM_FSM_St_is_Rls;
	logic						CRAM_FSM_St_is_RConfigData;
	logic						CRAM_FSM_St_is_DataWord;
	logic						CRAM_FSM_St_is_AccessEnd;
	logic						CRAM_FSM_St_O_StoreIDs;
	logic						CRAM_FSM_St_O_Set_ConfigData;
	logic						CRAM_FSM_St_O_We_Length;
	logic						CRAM_FSM_St_O_We_Stride;
	logic						CRAM_FSM_St_O_We_Base;
	logic						CRAM_FSM_St_O_Req;
	logic						CRAM_FSM_St_O_Acq;
	logic						CRAM_FSM_St_O_Rls;
	logic						CRAM_FSM_St_O_Trm;
	logic	[1:0]				CRAM_FSM_St_O_IDNo;

	//		Condition Code
	logic						Cond_Valid;
	logic						Cond_St;

	//		Address Generation Unit
	logic						EnAddressCalc;

	logic						AddrGenUnit_St_I_En_AddrGen;
	logic						AddrGenUnit_St_I_Cond;
	logic						AddrGenUnit_St_I_Decrement;
	logic						AddrGenUnit_St_I_Set_Length;
	logic						AddrGenUnit_St_I_Set_Stride;
	logic						AddrGenUnit_St_I_Set_Base;
	logic	[WIDTH_ADDR:0]		AddrGenUnit_St_I_Length;
	logic	[WIDTH_ADDR-1:0]	AddrGenUnit_St_I_Stride;
	logic	[WIDTH_ADDR-1:0]	AddrGenUnit_St_I_Base;
	logic	[WIDTH_ADDR-1:0]	AddrGenUnit_St_O_Address;
	logic						AddrGenUnit_St_O_Term;

	//		Store Memory Address
	logic	[WIDTH_ADDR-1:0]	St_Addr;

	//		Configuration Data Decode
	FTk_t						ConfigDec_RAM_I_FTk;
	logic						ConfigDec_RAM_O_Share;
	logic						ConfigDec_RAM_O_Decrement;
	logic [WIDTH_ADDR-1:0]		ConfigDec_RAM_O_Length;
	logic [WIDTH_ADDR-1:0]		ConfigDec_RAM_O_Stride;
	logic [WIDTH_ADDR-1:0]		ConfigDec_RAM_O_Base;
	logic [1:0]					ConfigDec_RAM_O_Mode;


	//// Capture Signal												////
	logic						R_Rls;
	logic						R_is_Decrement;
	logic						R_Share;
	logic [WIDTH_ADDR-1:0] 		R_Length;
	logic [WIDTH_ADDR-1:0] 		R_Stride;
	logic [WIDTH_ADDR-1:0] 		R_Base;
	logic [1:0]					R_Mode;
	FTk_t						R_St_Data;


	assign W_Set_Config		= CRAM_FSM_St_O_Set_ConfigData;
	assign Rls				= CRAM_FSM_St_O_Rls;
	assign Trm				= CRAM_FSM_St_O_Trm | AddrGenUnit_St_O_Term;

	// End of Access
	assign O_AccessEnd		= Trm;

	// Memory Access Mode
	assign O_Mode			= R_Mode;


	//// Tokens														////
	//	 Valid Token
	assign Valid			= I_FTk.v;

	//	 Nack Token
	assign Nack				= I_St_BTk.n;

	//	 Token-Check
	assign TokenDec_I_FTk	= I_FTk;

	TokenDec TokenDec(
		.I_FTk(				TokenDec_I_FTk				),
		.O_acq_message(	 	acq_message					),
		.O_rls_message(	 	rls_message					),
		.O_acq_flagmsg(	 	acq_flagmsg					),
		.O_rls_flagmsg(	 	rls_flagmsg					)
	);

	assign is_Acq			= acq_message | acq_flagmsg;
	assign is_Rls			= rls_message | rls_flagmsg | I_St_End;

	//	 Retime Release Token
	//		Issueing Release at Storing Timing
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rls		<= 1'b0;
		end
		else begin
			R_Rls		<= is_Rls;
		end
	end


	//// Attribution Decode											////
	assign Attribute_St_I_Data	= I_FTk.d;

	AttributeDec Attribute_St
	(
		.I_Data(			Attribute_St_I_Data			),
		.is_Pull(			Attribute_St_is_PullReq		),
		.is_DataWord(		Attribute_St_is_DataWord	),
		.is_RConfigData(	Attribute_St_is_RConfigData ),
		.is_PConfigData(	Attribute_St_is_PConfigData ),
		.is_RoutingData(	Attribute_St_is_RoutingData ),
		.is_Shared(			Attribute_St_is_Shared		),
		.is_NonZero(		Attribute_St_is_NonZero		),
		.is_Dense(			Attribute_St_is_Dense		),
		.is_MyAttribute(	Attribute_St_is_MyAttribute ),
		.is_Term_Block(		Attribute_St_is_Term_Block	),
		.is_In_Cond(		Attribute_St_is_In_Cond		),
		.O_Length(			Attribute_St_O_Length		)
	);


	//// Store Controller											////
	assign CRAM_FSM_St_I_Valid			= Valid;
	assign CRAM_FSM_St_I_Nack			= Nack;
	assign CRAM_FSM_St_is_Acq			= is_Acq;
	assign CRAM_FSM_St_is_Rls			= R_Rls;
	assign CRAM_FSM_St_is_RConfigData	= Attribute_St_is_RConfigData;
	assign CRAM_FSM_St_is_DataWord		= Attribute_St_is_DataWord;
	assign CRAM_FSM_St_is_AccessEnd		= AddrGenUnit_St_O_Term | I_St_BTk.t;

	CRAM_St_CTRL #(
		.WIDTH_LENGTH(		WIDTH_ADDR					),
		.NumWordsLength(	1							),
		.NumWordsStride(	1							),
		.NumWordsBase(		1							),
		.EXTERN(			EXTERN						)
	) CRAM_St_CTRL
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Valid(			CRAM_FSM_St_I_Valid			),
		.I_Nack(			CRAM_FSM_St_I_Nack			),
		.is_Acq(			CRAM_FSM_St_is_Acq			),
		.is_Rls(			CRAM_FSM_St_is_Rls			),
		.is_RConfigData(	CRAM_FSM_St_is_RConfigData	),
		.is_AuxData(		CRAM_FSM_St_is_DataWord		),
		.is_AccessEnd(		CRAM_FSM_St_is_AccessEnd	),
		.O_StoreIDs(		CRAM_FSM_St_O_StoreIDs		),
		.O_Set_ConfigData(	CRAM_FSM_St_O_Set_ConfigData),
		.O_We_Length(		CRAM_FSM_St_O_We_Length		),
		.O_We_Stride(		CRAM_FSM_St_O_We_Stride		),
		.O_We_Base(			CRAM_FSM_St_O_We_Base		),
		.O_Req(				CRAM_FSM_St_O_Req			),
		.O_Acq(				CRAM_FSM_St_O_Acq			),
		.O_Rls(				CRAM_FSM_St_O_Rls			),
		.O_Trm(				CRAM_FSM_St_O_Trm			),
		.O_IDNo(			CRAM_FSM_St_O_IDNo			)
	);


	//// Conditinal Branch Control									////
	CRAMCondUnit CRAMCondUnit_St (
		.clock(				clock						),
		.reset(				reset						),
		.I_Clr(				CRAM_FSM_St_O_We_Base		),
		.I_BTk(				I_St_BTk					),
		.O_Valid(			Cond_Valid					),
		.O_Cond(			Cond_St						)
	);


	//// Address Generation											////
	assign EnAddressCalc				= CRAM_FSM_St_O_Req;
	assign AddrGenUnit_St_I_En_AddrGen	= EnAddressCalc;
	assign AddrGenUnit_St_I_Cond		= Cond_Valid & Cond_St;
	assign AddrGenUnit_St_I_Decrement	= R_is_Decrement;
	assign AddrGenUnit_St_I_Set_Length	= CRAM_FSM_St_O_We_Length;
	assign AddrGenUnit_St_I_Set_Stride	= CRAM_FSM_St_O_We_Stride;
	assign AddrGenUnit_St_I_Set_Base	= CRAM_FSM_St_O_We_Base;


	//if ( NumWordsLength ) begin
	assign AddrGenUnit_St_I_Length	= I_FTk.d + R_Share + 1'b1;
	//end
	//else begin
	//		logic	AddrGenUnit_St_I_Length	 = R_Length;
	//end
	//if ( NumWordsLength ) begin
	assign AddrGenUnit_St_I_Stride	= I_FTk.d;
	//end
	//else begin
	//		logic	AddrGenUnit_St_I_Stride	 = R_Stride;
	//end
	//if ( NumWordsLength ) begin
	assign AddrGenUnit_St_I_Base	= I_FTk.d;
	//end
	//else begin
	//		logic	AddrGenUnit_St_I_Base		 = R_Base;
	//end

	AddrGenUnit_St #(
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.WIDTH_LENGTH(		WIDTH_ADDR					)
	) AddrGenUnit_St
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Cond(			AddrGenUnit_St_I_Cond		),
		.I_Set_Length(		AddrGenUnit_St_I_Set_Length ),
		.I_Set_Stride(		AddrGenUnit_St_I_Set_Stride ),
		.I_Set_Base(		AddrGenUnit_St_I_Set_Base	),
		.I_En_AddrGen(		AddrGenUnit_St_I_En_AddrGen ),
		.I_Decrement(		AddrGenUnit_St_I_Decrement	),
		.I_Length(			AddrGenUnit_St_I_Length		),
		.I_Stride(			AddrGenUnit_St_I_Stride		),
		.I_Base(			AddrGenUnit_St_I_Base		),
		.O_Address(			AddrGenUnit_St_O_Address	),
		.O_Term(			AddrGenUnit_St_O_Term		)
	);

	assign St_Addr			= AddrGenUnit_St_O_Address;
	assign O_St_Addr		= St_Addr;


	//// Set Configuration Data										////
	//	 Configuration Data Decoding
	assign ConfigDec_RAM_I_FTk	= I_FTk;

	ConfigDec_RAM #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_LENGTH(		WIDTH_ADDR					)
	) ConfigDec_RAM
	(

		.I_FTk(				ConfigDec_RAM_I_FTk			),
		.O_Decrement(		ConfigDec_RAM_O_Decrement	),
		.O_Indirect(									),
		.O_Share(			ConfigDec_RAM_O_Share		),
		.O_Length(			ConfigDec_RAM_O_Length		),
		.O_Stride(			ConfigDec_RAM_O_Stride		),
		.O_Base(			ConfigDec_RAM_O_Base		),
		.O_Mode(			ConfigDec_RAM_O_Mode		)
	);
	assign O_Mode			= R_Mode;

	//	 Capture Configuration Data
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Decrement	<= 1'b0;
			R_Share			<= 1'b0;
			R_Length		<= '0;
			R_Stride		<= '0;
			R_Base			<= '0;
			R_Mode			<= '0;
		end
		else if ( AddrGenUnit_St_O_Term | R_Rls ) begin
			R_is_Decrement	<= 1'b0;
			R_Share			<= 1'b0;
			R_Length		<= '0;
			R_Stride		<= '0;
			R_Base			<= '0;
			R_Mode			<= '0;
		end
		else if ( W_Set_Config & I_FTk.v ) begin
			R_is_Decrement	<= ConfigDec_RAM_O_Decrement;
			R_Share			<= ConfigDec_RAM_O_Share;
			R_Length		<= ConfigDec_RAM_O_Length;
			R_Stride		<= ConfigDec_RAM_O_Stride;
			R_Base			<= ConfigDec_RAM_O_Base;
			R_Mode			<= ConfigDec_RAM_O_Mode;
		end
	end


	//// Storing Data Word and Tokens								////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_St_Data		<= '0;
		end
		else begin
			R_St_Data		<= I_FTk;
		end
	end

	//	 Forward Tokens
	assign O_St_Req			= CRAM_FSM_St_O_Req;
	assign O_St_FTk.v		= CRAM_FSM_St_O_Req;
	assign O_St_FTk.a		= Rls;
	assign O_St_FTk.r		= Rls;
	assign O_St_FTk.c		= R_St_Data.c;
	`ifdef EXTEND
	assign O_St_FTk.i		= R_St_Data.i;
	`endif
	assign O_St_FTk.d		= R_St_Data.d;

	//	 Back-Prop Tokens
	assign O_BTk.n			= Nack;
	assign O_BTk.t			= Trm;
	assign O_BTk.v			= I_St_BTk.v | Cond_Valid;
	assign O_BTk.c			= I_St_BTk.c | Cond_St;

	assign O_Busy			= EnAddressCalc;

endmodule
