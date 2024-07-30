///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Adder-Tree
//		Module Name:	AdderTree
//		Function:
//						Reduction by Addition
//						AdderTree object (logic) is (LEVEL+1) x NUM_MOD rectanglar primitives.
//						A half of the primitives, triangle region is used and others are zero-assign.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module AdderTree
#(
	parameter int WIDTH     		= 1,
	parameter int NUM_MOD   		= 32,
	parameter int LEVEL     		= 5
)(
	input   		[WIDTH*NUM_MOD-1:0]			I_Data,				//Adder-Tree Sources
	output  logic	[WIDTH+$clog2(NUM_MOD)-1:0]	O_Val				//Reduction Result
);

	logic[WIDTH+$clog2(NUM_MOD)-1:0]	AdderTree	[LEVEL:0][NUM_MOD-1:0];
	logic[WIDTH+$clog2(NUM_MOD)-1:0]	Data		[NUM_MOD-1:0];


	//// Assign Data to Input Port on Adder-Tree
	//	 0 is used for input-width mismatch
	for ( genvar i = 0; i < NUM_MOD; ++i ) begin: g_data
		assign Data[ i ]	= '0 | I_Data[WIDTH*(i+1)-1:WIDTH*i];
	end


	//// Output
	assign O_Val	= AdderTree[0][0];


	//// Tree-Body
	always_comb begin: c_addertree
		for ( int l = LEVEL; l >= 0; --l ) begin
			if ( l == LEVEL ) begin
				//// First-Level
				for ( int mod = 0; mod < NUM_MOD; ++mod ) begin
					AdderTree[ l ][ mod ]	= Data[ mod ];
				end
			end
			else begin
				for ( int mod = 0; mod < NUM_MOD; ++mod ) begin
					if ( mod < (2**l) ) begin
						if ( mod >= (NUM_MOD/2) ) begin
							AdderTree[ l ][ mod ]	= AdderTree[ l+1 ][ mod ];
						end
						else begin
							AdderTree[ l ][ mod ]	= AdderTree[ l+1 ][ mod*2 ] + AdderTree[ l+1 ][ mod*2+1 ];
						end
					end
					else begin
						AdderTree[ l ][ mod ]	= '0;
					end
				end
			end
		end
	end

endmodule