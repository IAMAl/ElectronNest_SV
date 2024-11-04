///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Content Addressbale Memory (CAM) for TAG
//		Module Name:	TagCAM
//		Function:
//						Assosiative Memory used in Output Buffer.
//						Both of output from ALU pipeline and Skipped value came at a time.
//						Thus, additional buffer is necessary, this buffer works for it.
//						The unit stores tags (header pointer) and CAM works for the finding.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module TagCAM
	import	pkg_en::*;
#(
	parameter int LENGTH			= 4,
	parameter type TYPE_FTK			= FTk_t
)(
	input							clock,
	input							reset,
	input							I_We,				//Write-Enable
	input	[$clog2(LENGTH)-1:0]	I_PtrHead,			//Writing Value
	input							I_Seek,				//Seek-Enable
	input	[$clog2(LENGTH)-1:0]	I_Tag,				//Seeking Data
	input	TYPE_FTK				I_FTk,				//Buffering Data Word
	output	TYPE_FTK				O_FTk,				//Output Buffered Data Word
	output							O_Hit,				//Flag: Hit Detection
	output	[$clog2(LENGTH)-1:0]	O_Num				//Status: Number of Remained Entries
);


	//// Buffer														////
	TYPE_FTK						RAM [LENGTH-1:0];

	logic	[LENGTH-1:0]			Valid;				//Validation
	logic	[$clog2(LENGTH)-1:0]	Sel;				//Read-Out Select


	assign O_FTk				= RAM[ Sel ];
	assign O_Num				= Sel;


	//// Buffer Body												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<LENGTH; ++i ) begin
				RAM[ i ]		<= '0;
			end
		end
		else if ( I_We ) begin
			RAM[ I_PtrHead ]	<= I_FTk;
		end
	end


	//// Decode Number (Entry-Index) for Hit						////
	Encoder #(
		.NUM_ENTRY(			LENGTH						)
	) Enc
	(
		.I_Data(			Valid						),
		.O_Enc(				Sel							)
	);


	//// CAM Body													////
	CAM #(
		.LENGTH(			LENGTH						),
		.WIDTH_DATA(		$clog2(LENGTH)				)
	) CAM
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				I_We						),
		.I_Addr(			I_PtrHead					),
		.I_Seek(			I_Seek						),
		.I_Data(			I_PtrHead					),
		.I_CData(			I_Tag						),
		.I_Sel(				Sel							),
		.O_Hit(				O_Hit						),
		.O_Data(										),
		.O_Valid(			Valid						)
	);

endmodule