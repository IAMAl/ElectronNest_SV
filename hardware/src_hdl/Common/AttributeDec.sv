///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Attribute Word Decoder
//		Module Name:	AttributeDec
//		Function:
//						Decode Attribute Word, and Generate Signals
//						Attribute word is attached before Message Block.
//						The word has information of the block, block type, block length, etc.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module AttributeDec
	import	pkg_en::POSIT_ATTRIB_PULL;
    import  pkg_en::POSIT_ATTRIB_MODE_MSB;
    import  pkg_en::POSIT_ATTRIB_MODE_LSB;
    import  pkg_en::POSIT_ATTRIB_SHARED;
    import  pkg_en::POSIT_ATTRIB_NONZERO;
    import  pkg_en::POSIT_ATTRIB_DENSE;
    import  pkg_en::POSIT_ATTRIB_MY_ATTRIB_BLOCK;
    import  pkg_en::POSIT_ATTRIB_TERM_BLOCK;
	import	pkg_en::POSIT_ATTRIB_INPUT_COND;
	import	pkg_en::WIDTH_DATA;
	import	pkg_en::WIDTH_LENGTH;
(
	input	[WIDTH_DATA-1:0]		I_Data,				//Input Data
	output	logic					is_Pull,			//Flag: Pull Request
	output	logic					is_DataWord,		//Flag: Attribute Block is Data
	output	logic					is_RConfigData,		//Flag: Attribute Block is R-Config
	output	logic					is_PConfigData,		//Flag: Attribute Block is P-Config
	output	logic					is_RoutingData,		//Flag: Attribute Block is Routing Data
	output	logic					is_Shared,			//Flag: There is a Shared Data
	output	logic					is_NonZero,			//Flag: Sharing is forn Non-Zero
	output	logic					is_Dense,			//Flag: Dense-Compression
	output	logic					is_MyAttribute,		//Flag: This Attribute Block is Mine
	output	logic					is_Term_Block,		//Flag: This Attribute Bloci is Terminal
	output	logic					is_In_Cond,			//Flag: Input Condition Code
	output	[WIDTH_LENGTH-1:0]		O_Length			//Attribute Block Length
);


	//// Pull&Push													////
	//	 Pull: Pulling Block of Data from Memory and
	//		Appending the Block to End of the pulling Message
	assign is_Pull			= I_Data[POSIT_ATTRIB_PULL];

	//	Push: Pusing Block of Data from Message and
	//		Storing the Block in Memory
	//assign is_Push			= I_Data[POSIT_ATTRIB_PUSH];


	//// Attribution Decode											////
	//	 Attribution of Follower Block
	assign is_DataWord		= I_Data[POSIT_ATTRIB_MODE_MSB:POSIT_ATTRIB_MODE_LSB] == 2'h0;
	assign is_PConfigData	= I_Data[POSIT_ATTRIB_MODE_MSB:POSIT_ATTRIB_MODE_LSB] == 2'h1;
	assign is_RConfigData	= I_Data[POSIT_ATTRIB_MODE_MSB:POSIT_ATTRIB_MODE_LSB] == 2'h2;
	assign is_RoutingData	= I_Data[POSIT_ATTRIB_MODE_MSB:POSIT_ATTRIB_MODE_LSB] == 2'h3;


	//// Block Attribution Flags									////
	//	 Having Shared Data Word after the Attribute Word
	assign is_Shared		= I_Data[POSIT_ATTRIB_SHARED];

	//	 Sharing is for Non-Zero Value
	assign is_NonZero		= I_Data[POSIT_ATTRIB_NONZERO];

	//	 Sharing (Compression) is Dense-Oriented
	//		NOTE:This Flag will be removed
	assign is_Dense			= I_Data[POSIT_ATTRIB_DENSE];

	//	 This Block is Mine
	//		used for Memory Access
	assign is_MyAttribute	= I_Data[POSIT_ATTRIB_MY_ATTRIB_BLOCK];

	//	 This Block is Terminal
	//		used for Sequence on Loading
	assign is_Term_Block	= I_Data[POSIT_ATTRIB_TERM_BLOCK];

	//	 Input Cond Token
	//		used for feeding cond into FanIn Link from FanOutLing
	assign is_In_Cond		= I_Data[POSIT_ATTRIB_INPUT_COND];


	//// Block Length												////
	assign O_Length			= I_Data[WIDTH_LENGTH+7:8];

endmodule