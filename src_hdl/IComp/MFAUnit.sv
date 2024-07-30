///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Most Frequently Appeared Value Detection Unit
//	Module Name:	MFAUnit
//	Function:
//					Top Module of MFA Unit
//					This unit is used for extension; Index-Compression.
//					The extension find most frequently appeared value.
//					The value is removed from the data block,
//						and treated as a shared data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MFAUnit
	import	pkg_en::*;
#(
	parameter int LENGTH			= 256
)(
	input							clock,
	input							reset,
	input							I_Rd_MFA,			//Flag: Read MFA Values
	input							I_En,				//Enable to Run
	input							I_Valid,			//Valid Token
	input							I_Rls,				//Realese Token
	input	[WIDTH_DATA-1:0]		I_Data,				//Data
	output	logic					O_Valid,			//Output Valid Token
	output	[WIDTH_DATA-1:0]		O_SharedData,		//MFA Data
	output	[$clog2(LENGTH)+1:0]	O_CountVal			//MFA Number
);


	localparam int MAX_LEVEL	= $clog2($clog2(LENGTH));
	localparam int WIDTH_LEVEL	= $clog2(MAX_LEVEL);
	localparam int WIDTH_SUM	= $clog2(LENGTH)+2;
	localparam int WIDTH_TREE	= (MAX_LEVEL+1)*WIDTH_SUM;
	localparam int INIT_LENGTH	= LENGTH/(2**3);
	localparam int WIDTH_INIT	= $clog2(INIT_LENGTH);
	localparam int WIDTH_COUNT	= WIDTH_SUM+WIDTH_LEVEL;


	//// Input Data													////
	logic						Valid;
	logic	[WIDTH_DATA-1:0]	Data;


	//// Chaining Modules											////
	//	 Input
	logic						IValid	[MAX_LEVEL:0];
	logic	[WIDTH_DATA-1:0]	IData	[MAX_LEVEL:0];

	//	 Output
	logic						OValid	[MAX_LEVEL:0];
	logic	[WIDTH_DATA-1:0]	OData	[MAX_LEVEL:0];


	//// MFA Output													////
	logic	[MAX_LEVEL:0]		Done;

	logic	[WIDTH_INIT:0]		CountVal[MAX_LEVEL:0];
	logic	[WIDTH_COUNT-1:0]	MFA_CountVal;
	logic	[WIDTH_TREE-1:0]	MFA_ValSum;


	//// Select one MFA Module										////
	logic	[WIDTH_LEVEL-1:0]	Sel_Mod;


	//// Check Number of Inputs										////
	logic						is_Over_Count;


	//// Capture MFA Results										////
	logic						R_Valid;
	logic	[WIDTH_DATA-1:0]	R_SharedData;
	logic	[WIDTH_SUM-1:0]		R_MFA_CountVal;

	logic	[WIDTH_SUM:0]		R_Check_Count;

	logic						R_Rd_MFA;
	logic						R_Rd_MFA_D1;
	logic						R_Rd_MFA_D2;


	//// FIFO input Data and Valid									////
	assign Valid			= I_En & I_Valid;
	assign Data				= I_Data;


	//// MFA Data													////
	assign O_Valid			= R_Valid;
	assign O_SharedData		= R_SharedData;
	assign O_CountVal		= R_MFA_CountVal;

	assign is_Over_Count	= R_Check_Count >= (LENGTH-1);

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Check_Count	<= '0;
		end
		else if ( R_Rd_MFA_D1 ) begin
			R_Check_Count	<= '0;
		end
		else if ( Valid & ( I_Data == 0 ) ) begin
			R_Check_Count	<= R_Check_Count + 1'b1;
		end
	end

	always_ff @(  posedge clock ) begin
		if ( reset ) begin
			R_Valid			<= 1'b0;
			R_SharedData	<= '0;
		end
		else if ( I_Rls ) begin
			R_Valid			<= 1'b0;
			R_SharedData	<= '0;
		end
		else if ( R_Rd_MFA_D1 ) begin
			R_Valid			<= Done[ Sel_Mod ];
			R_SharedData	<= OData[ Sel_Mod ];
		end
	end

	always_ff @(  posedge clock ) begin
		if ( reset ) begin
			R_MFA_CountVal	<= '0;
		end
		else if ( I_Rls ) begin
			R_MFA_CountVal	<= '0;
		end
		else if ( R_Rd_MFA_D1 ) begin
			R_MFA_CountVal	<= MFA_CountVal[WIDTH_SUM-1:0];
		end
	end

	//	 Retime Reading
	always_ff @(  posedge clock ) begin
		if ( reset ) begin
			R_Rd_MFA		<= 1'b0;
			R_Rd_MFA_D1		<= 1'b0;
			R_Rd_MFA_D2		<= 1'b0;
		end
		else begin
			R_Rd_MFA		<= I_Rd_MFA;
			R_Rd_MFA_D1		<= R_Rd_MFA;
			R_Rd_MFA_D2		<= R_Rd_MFA_D1;
		end
	end


	//// Chain MFA modules											////
	assign IValid[0]	= Valid;
	assign IData[0]		= Data;
	for ( genvar mod = 1; mod < MAX_LEVEL+1; ++mod ) begin: g_chain_mfa
		assign IValid[ mod ]	= ( mod != 0 ) ?	OValid[ mod - 1 ] :
													OValid[ mod - 1 ] & ~is_Over_Count;
		assign IData[ mod ]		= OData[ mod - 1 ];
	end


	//// Assessment of The Number of Sharing						////
	for ( genvar mod = 0; mod < MAX_LEVEL+1; ++mod ) begin: g_assess
		if ( mod == 0 ) begin
			assign MFA_ValSum[WIDTH_SUM-1:0]						= '0 |    CountVal[ mod ][WIDTH_INIT-mod-1:0];
		end
		else begin
			assign MFA_ValSum[WIDTH_SUM*(mod+1)-1:WIDTH_SUM*mod] 	= '0 | (( CountVal[ mod ][WIDTH_INIT-mod-1:0] + CountVal[ mod-1 ][WIDTH_INIT-mod+1] ) << ( WIDTH_INIT - mod + 1 ) );
		end
	end


	//// Select One MFA Module										////
	PriorityEnc #(
		.NUM_ENTRY(			MAX_LEVEL+1					)
	) PriorityEnc (
		.I_Req(				Done						),
		.O_Grt(				Sel_Mod						),
		.O_Vld(											)
	);


	//// MFAs														////
	for ( genvar mod = 0; mod < MAX_LEVEL+1; ++mod ) begin :mfa
		if ( mod == 0 ) begin
			MFA #(
				.NUM_ENTRY( INIT_LENGTH/(2**mod)		)
			) MFA
			(
				.clock(		clock						),
				.reset(		reset						),
				.I_Rd_MFA(	R_Rd_MFA					),
				.I_Valid(	Valid						),
				.I_Data(	Data						),
				.I_FValid(	IValid[ mod ]				),
				.I_FData(	IData[ mod ]				),
				.O_Valid(	OValid[ mod ]				),
				.O_Data(	OData[ mod ]				),
				.O_CountVal(CountVal[ mod ][WIDTH_INIT-mod:0]	),
				.O_Done(	Done[ mod ]					)
			);
		end
		else begin
			MFA #(
				.NUM_ENTRY( INIT_LENGTH/(2**mod)		)
			) MFA
			(
				.clock(		clock						),
				.reset(		reset						),
				.I_Rd_MFA(	R_Rd_MFA					),
				.I_Valid(	IValid[ mod ]				),
				.I_Data(	IData[ mod ]				),
				.I_FValid(	IValid[ mod ]				),
				.I_FData(	IData[ mod ]				),
				.O_Valid(	OValid[ mod ]				),
				.O_Data(	OData[ mod ]				),
				.O_CountVal(CountVal[ mod ][WIDTH_INIT-mod:0]	),
				.O_Done(	Done[ mod ]					)
			);
		end
	end


	//// Calculate Approximate MFA Count							////
	AdderTree #(
		.WIDTH(				WIDTH_SUM					),
		.NUM_MOD(			MAX_LEVEL+1					),
		.LEVEL(				WIDTH_LEVEL					)
	) MFAVal
	(
		.I_Data(			MFA_ValSum					),
		.O_Val(				MFA_CountVal				)
	);

endmodule
