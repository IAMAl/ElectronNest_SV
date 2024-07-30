///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Priority Encoder
//		Module Name:	PriorityEnc
//		Function:
//						Encoder with Priority
//						First Input has Higher Priority
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module PriorityEnc
#(
	parameter int NUM_ENTRY			= 20
)(
	input	[NUM_ENTRY-1:0]			I_Req,							//Request
	output	[$clog2(NUM_ENTRY)-1:0]	O_Grt,							//Grant Number
	output						 	O_Vld							//Validation
);

	logic	[$clog2(NUM_ENTRY)-1:0]	Grt;
	logic	[NUM_ENTRY-1:0]			Select;

	assign Select[0]		= I_Req[0];
	for ( genvar index = 1; index < NUM_ENTRY; ++index ) begin
		assign Select[ index ]	= ~Select[ index - 1] & I_Req[ index ];
	end

	assign O_Grt			= Grt;
	assign O_Vld			= ( I_Req != '0 );


	//// Output Grant												////
	//	 valid is one-hot encoded but we use encoder for
	//	 safely generating a number
	Encoder #(
		.NUM_ENTRY(			NUM_ENTRY					)
	) Arbit_Enc
	(
		.I_Data(			Select						),
		.O_Enc(				Grt							)
	);

endmodule
