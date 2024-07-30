///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Decoder
//		Module Name:	Decoder
//		Function:
//						Decode and Output One-Hot Code
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Decoder
#(
	parameter int NUM_ENTRY			= 8,
	parameter int LOG_NUM_ENTRY		= 3
)(
	input	[LOG_NUM_ENTRY-1:0]		I_Val,                          //Decode-Source
	output	[NUM_ENTRY-1:0]			O_Grt                           //Decoded Signals
);


	for ( genvar index = 0; index < NUM_ENTRY; ++index ) begin
		assign O_Grt[ index ]	= ( index == I_Val );
	end

endmodule
