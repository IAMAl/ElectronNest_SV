///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	R-Configuration Data Storage
//		Module Name:	RConfig
//		Function:
//						Store R-COnfiguratin Data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RConfigData #(
	parameter int WIDTH_DATA		= 32
)(
	input							clock,
	input							reset,
	input							I_We,							//Write Enable
	input 							I_Clr,                          //Clear Storage
	input	[WIDTH_DATA-1:0]		I_Data,							//R-Configuration Data
	output	[WIDTH_DATA-1:0]		O_RConfig,						//Configuration Command
	output	[WIDTH_DATA-1:0]		O_Length,						//Access-Length
	output	[WIDTH_DATA-1:0]		O_Stride,						//Stride Amount
	output	[WIDTH_DATA-1:0]		O_Base,							//Base Address
	output	logic					O_End_RConfig					//Flag: End of Storing
);


	//// Capturing Logic											////
	logic	[2:0]				R_Cnt;
	logic	[WIDTH_DATA-1:0]	R_Data	[3:0];


	assign O_RConfig		= R_Data[0];
	assign O_Length			= R_Data[1];
	assign O_Stride			= R_Data[2];
	assign O_Base			= R_Data[3];
	assign O_End_RConfig	= R_Cnt == 3'h4;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cnt		<= '0;
		end
		else if ( I_Clr | ( R_Cnt == 3'h4 )) begin
			R_Cnt		<= '0;
		end
		else if ( I_We ) begin
			R_Cnt		<= R_Cnt + 1'b1;
		end
	end

	always_ff @( posedge clock or posedge reset ) begin
		if ( reset ) begin
			for ( int i=0; i<4; ++i ) begin
				R_Data[ i ]		<= '0;
			end
		end
		else if ( I_We ) begin
			R_Data[ R_Cnt ]	<= I_Data;
		end
	end

endmodule