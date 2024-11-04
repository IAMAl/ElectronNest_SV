///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Tournament Unit
//		Module Name:	TournamentL
//		Function:
//						Select One Entry having Largest Value
//						Generates a Valid Sigal of a Winner
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module TournamentL
	import pkg_bram_if::*;
(
	input	[WIDTH_UNITS:0]			I_Entry	[NUM_UNITS-1:0],		//Tournament Entries
	output 	[WIDTH_UNITS:0]			O_Entry,						//Winning Entry
	output	nbit_t					O_Valid							//Flag: Validation
);


	localparam int	REMAINDER_LV	= (NUM_UNITS)/4;					//5
	localparam int	WASTE_INDEX_LV	= NUM_UNITS%4;						//0

	localparam int	REMAINDER_LV0	= (NUM_UNITS+3)/4;					//5
	localparam int	WASTE_INDEX_LV0	= REMAINDER_LV0%4;					//1
	localparam int	TEST_LV0		= (REMAINDER_LV0+3)/4;				//2

	localparam int	REMAINDER_LV1	= (NUM_UNITS+15)/16;				//2
	localparam int	WASTE_INDEX_LV1	= REMAINDER_LV1%4;					//2
	localparam int	TEST_LV1		= (REMAINDER_LV1+3)/4;				//1

	localparam int	REMAINDER_LV2	= (NUM_UNITS+63)/64;				//1
	localparam int	WASTE_INDEX_LV2	= REMAINDER_LV2%4;					//1
	localparam int	TEST_LV2		= (REMAINDER_LV2+3)/4;				//1


	//// Logic Connect												////
	logic [WIDTH_UNITS:0]		Entry 	[REMAINDER_LV0*4-1:0];

	//	 Level-0
	logic [WIDTH_UNITS:0]		W_Entry_Lv0	[REMAINDER_LV1*4-1:0];
	logic 						Valid_Lv0	[REMAINDER_LV0*4-1:0];
	logic [REMAINDER_LV0-1:0]	W_Valid_Lv0;

	//	 Level-1
	logic [WIDTH_UNITS:0]		W_Entry_Lv1	[REMAINDER_LV2*4-1:0];
	logic 						Valid_Lv1	[REMAINDER_LV1*4-1:0];
	logic [REMAINDER_LV1-1:0]	W_Valid_Lv1;

	//	 Level-2
	logic [WIDTH_UNITS:0]		W_Entry_Lv2;
	logic 						Valid_Lv2	[REMAINDER_LV2*4-1:0];
	logic [REMAINDER_LV2-1:0]	W_Valid_Lv2;


	//// Allocate Parts of a Input to Every Entry					////
	for ( genvar i=0; i<NUM_UNITS; ++i ) begin : g_i_entry
		assign Entry[ i ]	= I_Entry[ i ];
	end


	//// Level-0 Tournament											////
	always_comb begin
		if ( WASTE_INDEX_LV != 0 ) begin
			for ( int i=WASTE_INDEX_LV; i<4; ++i ) begin
				Entry[4*(REMAINDER_LV0-1)+i]	= '0;
			end
		end
	end

	for ( genvar i=0; i<REMAINDER_LV0*4; i=i+4 ) begin : g_tournament_lv0
		TournamentL4 Tournament_Lv0 (
			.I_Entry0(		Entry[i+0]					),
			.I_Entry1(		Entry[i+1]					),
			.I_Entry2(		Entry[i+2]					),
			.I_Entry3(		Entry[i+3]					),
			.O_Entry(		W_Entry_Lv0[i/4]			),
			.O_Valid(		W_Valid_Lv0[i/4]			),
			.O_Valid0(		Valid_Lv0[i+0]				),
			.O_Valid1(		Valid_Lv0[i+1]				),
			.O_Valid2(		Valid_Lv0[i+2]				),
			.O_Valid3(		Valid_Lv0[i+3]				)
		);
	end


	//// Level-1 Tournament											////
	always_comb begin
		for ( int i=WASTE_INDEX_LV0; i<4; ++i ) begin
			W_Entry_Lv0[4*(REMAINDER_LV1-1)+i]	= '0;
		end
	end

	for ( genvar i=0; i<REMAINDER_LV1*4; i=i+4 ) begin : g_tournament_lv1
		TournamentL4 Tournament_Lv1 (
			.I_Entry0(		W_Entry_Lv0[i+0]			),
			.I_Entry1(		W_Entry_Lv0[i+1]			),
			.I_Entry2(		W_Entry_Lv0[i+2]			),
			.I_Entry3(		W_Entry_Lv0[i+3]			),
			.O_Entry(		W_Entry_Lv1[i/4]			),
			.O_Valid(		W_Valid_Lv1[i/4]			),
			.O_Valid0(		Valid_Lv1[i+0]				),
			.O_Valid1(		Valid_Lv1[i+1]				),
			.O_Valid2(		Valid_Lv1[i+2]				),
			.O_Valid3(		Valid_Lv1[i+3]				)
		);
	end


	//// Level-2 Tournament											////
	always_comb begin
		for ( int i=WASTE_INDEX_LV1; i<4; ++i ) begin
			W_Entry_Lv1[4*(REMAINDER_LV2-1)+i]	= '0;
		end
	end

	TournamentL4 Tournament_Lv2 (
		.I_Entry0(			W_Entry_Lv1[0]				),
		.I_Entry1(			W_Entry_Lv1[1]				),
		.I_Entry2(			W_Entry_Lv1[2]				),
		.I_Entry3(			W_Entry_Lv1[3]				),
		.O_Entry(			W_Entry_Lv2					),
		.O_Valid(			W_Valid_Lv2					),
		.O_Valid0(			Valid_Lv2[0]				),
		.O_Valid1(			Valid_Lv2[1]				),
		.O_Valid2(			Valid_Lv2[2]				),
		.O_Valid3(			Valid_Lv2[3]				)
	);


	//// Valid Signal Generation for Winner							////
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			O_Valid[i]	= Valid_Lv0[i] & Valid_Lv1[i/4] & Valid_Lv2[i/16];
		end
	end


	//// Winner Entry having Minimum Value							////
	assign O_Entry			= W_Entry_Lv2;

endmodule