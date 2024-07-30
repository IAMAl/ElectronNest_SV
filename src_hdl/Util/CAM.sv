///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Content Addressbale Memory (CAM)
//		Module Name:	CAM
//		Function:
//						Content Addressbale Memory
//						Data can be stored in anywhere addressed by I_Addr.
//						I_CData can be seeked in the Memd memory, returns O_Hit==1 when find the content.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module CAM
#(
	parameter int LENGTH			= 16,
	parameter int WIDTH_DATA    	= 32
)(
	input							clock,
	input							reset,
	input							I_We,				//Write-Enable
	input	[$clog2(LENGTH)-1:0]	I_Addr,				//Write-Address
	input	[WIDTH_DATA-1:0]		I_Data,				//Store Data
	input							I_Seek,				//Seek-Enable
	input	[WIDTH_DATA-1:0]		I_CData,			//Seek-Data
	input	[$clog2(LENGTH)-1:0]	I_Sel,				//Clear-Select
	output							O_Hit,				//Flag: Match-Detection
	output	[WIDTH_DATA-1:0]		O_Data,				//Output Data Word
	output	[LENGTH-1:0]			O_Valid				//Set of Flags
);


	//// CAM Storage												////
	//	 Valid Flag
	logic						Memv	[LENGTH-1:0];

	//	 Data Word
	logic	[WIDTH_DATA-1:0]	Memd	[LENGTH-1:0];

	//	 Matched Then Assert with Valid Flag
	logic   [LENGTH-1:0]        FindV;

	//	 Tag-Match Detection
	logic						Hit;

	always_comb begin
		for ( int i = 0; i < LENGTH; ++i ) begin
			if ( i > 0 ) begin
				FindV[ i ]	= I_Seek & Memv[ i ] & ( Memd[ i ]  == I_CData ) & ~FindV[ i - 1 ];
			end
			else begin
				FindV[ 0 ]	= I_Seek & Memv[ i ] & ( Memd[ 0 ]  == I_CData );
			end
		end
	end

	//	 One (ore more) High indicates Matching
	assign Hit			= |FindV;
	assign O_Hit		= Hit;

	//	 Matched Data Word is read out with Select Signal
	//		Select signal clears Valid Flag
	assign O_Data   	= Memd[ I_Sel ];

	//	 Set of Flag fed into Decoder
	assign O_Valid		= FindV;


	//// Valid Flag Register										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<LENGTH; ++i ) begin
				Memv[ i ]	<= 1'b0;
			end
		end
		else if ( I_We ) begin
			Memv[ I_Addr ]	<= 1'b1;
		end
		else begin
			Memv			<= Memv;
		end

		if ( |FindV ) begin
			Memv[ I_Sel ]	<= 1'b0;
		end
	end


	//// Data Word Storage											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<LENGTH; ++i ) begin
				Memd[ i ]	<= '0;
			end
		end
		else if ( I_We ) begin
			Memd[ I_Addr ]	<= I_Data;
		end
	end

endmodule