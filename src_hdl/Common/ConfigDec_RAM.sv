///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Configuration Data Decoder
//		Module Name:	ConfigDec_RAM
//		Function:
//						Decode Configuration Data used for Load/Store
//						The configuration data defines the loading/storing commands.
//						Data is used mainly for address generation unit.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module ConfigDec_RAM
	import	pkg_en::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int WIDTH_LENGTH		= 8
)(
	input	FTk_t					I_FTk,				//Data
	output	logic					O_Share,			//Flag: Share
	output	logic					O_Decrement,		//Flag: Decrement
	output	[1:0]					O_Mode,				//Access Mode
	output	logic					O_Indirect,			//Flag: Indirect Access
	output 	[WIDTH_LENGTH-1:0]		O_Length,			//Attribute Block Length
	output 	[WIDTH_LENGTH-1:0]		O_Stride,			//Stride Factor
	output 	[WIDTH_LENGTH-1:0]		O_Base				//Base Address
);


	//// Access Mode												////
	//	 00:  8-bit Access
	//	 01: 16-bit Access
	//	 10: 32-bit Access
	//	 11: Reserved
	assign O_Mode			= I_FTk.d[POSIT_MEM_CONFIG_MODE_MSB	:POSIT_MEM_CONFIG_MODE_LSB];


	//// Do Sharing (Compression) Effort on MFA						////
	assign O_Share			= I_FTk.d[WIDTH_DATA-1];


	//// Decrement by Stride Amount									////
	assign O_Decrement		= I_FTk.d[WIDTH_DATA-2];


	//// Indirect Access											////
	assign O_Indirect		= I_FTk.d[POSIT_MEM_CONFIG_INDIRECT];


	//// Access Length												////
	assign O_Length			= I_FTk.d[POSIT_MEM_CONFIG_LENGTH_MSB	:POSIT_MEM_CONFIG_LENGTH_LSB];


	//// Stride Amount												////
	assign O_Stride			= I_FTk.d[POSIT_MEM_CONFIG_STRIDE_MSB	:POSIT_MEM_CONFIG_STRIDE_LSB];


	//// Base (Offset) Address										////
	assign O_Base			= I_FTk.d[POSIT_MEM_CONFIG_BASE_MSB	:POSIT_MEM_CONFIG_BASE_LSB];

endmodule
