///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Most Frequently Appeared (MFA) Value Detector
//	Module Name:	MFA
//	Function:
//					Base Unit for MFA Detection
//					This unit is used for extension; Index-Compression.
//					The extension find most frequently appeared value.
//					The value is removed from the data block,
//						and treated as a shared data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MFA
	import	pkg_en::*;
#(
    parameter int NUM_ENTRY			= 4,
	parameter int LOG_NUM_ENTRY		= $clog2(NUM_ENTRY)
)(
	input							clock,
	input							reset,
	input							I_Rd_MFA,			//Flag: Read MFA Values
	input							I_Valid,			//Input Valid Token
    input	[WIDTH_DATA-1:0]		I_Data,				//Input Data
	input							I_FValid,			//Compare Valid Token
    input	[WIDTH_DATA-1:0]		I_FData,			//Compare Data
	output	logic					O_Valid,			//Output Valid Token
	output	[WIDTH_DATA-1:0]		O_Data,				//MFA Data
	output	[LOG_NUM_ENTRY:0]		O_CountVal,			//MFA Number
	output	logic					O_Done				//Flag: Output is Valid
);


	localparam int LOG_NUM		= $clog2(NUM_ENTRY);


	//// FIFOs														////
    logic						FIFOv	[NUM_ENTRY-1:0];
    logic [WIDTH_DATA-1:0]		FIFO 	[NUM_ENTRY-1:0];
	logic [NUM_ENTRY-1:0]		ChkVld;


	//// Select Data for Reading-out								////
	logic [LOG_NUM-1:0]			Sel_Grt;
	logic [LOG_NUM-1:0]			R_Sel_Grt;
	logic						R_is_GThan;


	//// MFA-State Information										////
	logic [WIDTH_DATA-1:0]		R_Data;
    logic [LOG_NUM:0]			R_CountVal;
    logic [LOG_NUM:0]			R_Count;


	//// Update COndition for MFA-State Information					////
    logic                       is_GThan;


	//// Count Enable Flag											////
	logic						is_SameVal;


	//// Pop-Count													////
    logic [NUM_ENTRY-1:0]		is_Matched;
    logic [LOG_NUM:0]			CountVal;


	//// Count MFA													////
	logic						CountUp;
	logic						CarryOut;


	//// FIFO Status												////
	logic						is_Full;
	logic						is_Empty;

	//// Capture Signal												////
	logic						R_Rd_MFA;


	//// Capture State in Full										////
	logic						R_Fulled;


	//// Cehck Valid												////
	//	 Unpack to Pack Conversion
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			ChkVld			<= '0;
		end
		else begin
			for ( int i = 0; i < NUM_ENTRY; ++i ) begin
				ChkVld[ i ]	<= FIFOv[ i ];
			end
		end
	end

	//	 Check FIFO is state in Full
	assign is_Full			= &ChkVld;

	//	 Check FIFO is Empty
	assign is_Empty			= &(~ChkVld[NUM_ENTRY-1:1]);


	//// Update Condition for MFA-Data and its Valid				////
    assign is_GThan			= ( CountVal > R_CountVal );


	//// Capture Full State											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Fulled		<= 1'b0;
		end
		else if ( R_Rd_MFA | is_Empty ) begin
			R_Fulled		<= 1'b0;
		end
		else if ( is_Full ) begin
			R_Fulled		<= 1'b1;
		end
	end


	//// Count-up after FIFO is Full								////
	assign CountUp			= I_Valid & is_Full & ~is_GThan & is_SameVal;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			CarryOut		<= 1'b0;
		end
		else begin
			CarryOut		<= ( I_Valid & ( R_CountVal == (NUM_ENTRY-1) ) ) |
								( CountUp & ( R_Count == (NUM_ENTRY-1) ) );
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Count			<= '0;
		end
		else if ( is_Empty ) begin
			R_Count			<= '0;
		end
		else if ( is_Full & ~R_Fulled ) begin
			R_Count			<= R_CountVal + 1'b1;
		end
		else if ( CarryOut ) begin
			R_Count			<= '0;
		end
		else if ( CountUp & ( R_Count < NUM_ENTRY )) begin
			R_Count			<= R_Count + 1'b1;
		end
	end


	//// Count Enable												////
	//	 Same Value between MFA ( in progress) and input
	//	 then count-up
	assign is_SameVal		= I_Data == R_Data;


	//// Select Data in FIFO at Reading-out							////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rd_MFA	<= 1'b0;
		end
		else begin
			R_Rd_MFA	<= I_Rd_MFA;
		end
	end


	//// Output														////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Sel_Grt	<= '0;
		end
		else begin
			R_Sel_Grt	<= Sel_Grt;
		end
	end

	assign O_Valid			= ( R_Rd_MFA ) ?	FIFOv[ R_Sel_Grt ]	:
												CarryOut;
    assign O_Data			= ( R_Rd_MFA ) ?	FIFO[ R_Sel_Grt ]	:
												R_Data;
	assign O_CountVal		= ( R_Fulled ) ?	R_Count + ( R_Rd_MFA & (|ChkVld) ) :
												R_CountVal + ( R_Rd_MFA & (|ChkVld) );
    assign O_Done			= R_is_GThan;


	//// Check Matched Entry in FIFO								////
	//	 used for counting the number of matched entry in FIFO
    for ( genvar i = 0; i < NUM_ENTRY; ++i ) begin: g_check_match
        assign is_Matched[ i ]	= FIFOv[ i ] & (( I_Rd_MFA & ( FIFO[ i ] == R_Data ) ) | ( I_Valid &  ~I_Rd_MFA & ( FIFO[ i ] == I_Data )));
    end


	//// FIFOs														////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i = NUM_ENTRY-1; i >= 0; --i ) begin
				FIFOv[ i ]	<= '0;
			end
		end
		else if ( I_FValid | CarryOut ) begin
			if ( CarryOut ) begin
				for ( int i = NUM_ENTRY-1; i >= 0; --i ) begin
					FIFOv[ i ]	<= 1'b0;
				end
			end
			else if ( I_FValid ) begin
				for ( int i = NUM_ENTRY-1; i > 0; --i ) begin
					FIFOv[ i ]	<= FIFOv[ i - 1 ];
				end
			end
			FIFOv[0]	<= I_FValid;
		end
	end


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i = NUM_ENTRY-1; i >= 0; --i ) begin
				FIFO[ i ]	<= '0;
			end
		end
		else if ( I_FValid ) begin
			for ( int i = NUM_ENTRY-1; i > 0; --i ) begin
				FIFO[ i ]	<= FIFO[ i - 1 ];
			end
			FIFO[0]		<= I_FData;
		end
	end


	//// MFA-Information											////
	//	 Validate when Current Counter is greater than Record
	always_ff @( posedge clock ) begin: ff_valid
		if ( reset ) begin
			R_is_GThan	<= 1'b0;
		end
		else if ( R_Rd_MFA ) begin
			R_is_GThan	<= 1'b0;
		end
		else if ( I_Valid & is_GThan ) begin
			R_is_GThan	<= 1'b1;
		end
	end

	//	 Capture MFA Value
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Data		<= '0;
		end
		else if ( R_Rd_MFA ) begin
			R_Data		<= '0;
		end
		else if ( I_Valid & is_GThan ) begin
			R_Data		<= I_Data;
		end
	end

	//	 Capture Pop-Count Value
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_CountVal	<= '0;
		end
		//ToDo
		else if ( R_Rd_MFA | CarryOut ) begin
			R_CountVal	<= '0;
		end
		else if ( I_Valid & is_GThan ) begin
			R_CountVal	<= CountVal;
		end
	end


	//// Pop-Counter												////
	AdderTree #(
		.WIDTH(				1							),
		.NUM_MOD(			NUM_ENTRY					),
		.LEVEL(				LOG_NUM						)
	) PopCount
	(
		.I_Data(			is_Matched					),
		.O_Val(				CountVal					)
	);


	////  Selector for Reading-out									////
	PriorityEnc #(
		.NUM_ENTRY(			NUM_ENTRY					)
	) MFA_PriorityEnc
	(
		.I_Req(				is_Matched					),
		.O_Grt(				Sel_Grt						),
		.O_Vld(											)
	);

endmodule
