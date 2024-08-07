///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Address Generation Unit
//		Module Name:	AddrGenUnit_St
//		Function:
//						Generate Series of Addresses
//						Before starting, the unit is set by configuration data.
//						The data are after attribute word of the config block.
//						Address is continuously generated by affine equation;
//							Addr = Addr +/1 Stride
//							Initial Addr is set by Base Address,
//							Repeat time is define by Access Length
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module AddrGenUnit_St
#(
	parameter int WIDTH_ADDR		= 8,
	parameter int WIDTH_LENGTH		= 8
)(
	input							clock,
	input							reset,
	input							I_Cond,				//Flag: Condition
	input							I_Set_Length,		//Setting Access Length
	input							I_Set_Stride,		//Setting Stride Factor
	input							I_Set_Base,			//Setting Base Address
	input							I_En_AddrGen,		//Enable to Calc
	input							I_Decrement,		//Flag: Decriment for Address
	input	[WIDTH_LENGTH:0]		I_Length,			//Access Length
	input	[WIDTH_ADDR-1:0]		I_Stride,			//Stride Factor
	input	[WIDTH_ADDR-1:0]		I_Base,				//Base Address
	output	[WIDTH_ADDR-1:0]		O_Address,			//Address
	output							O_Term				//Flag: End of Calc
);


	//// Logic Connect												////
	logic						EnUpdate;				//Enable Update
	logic [WIDTH_ADDR/2:0]		Stride;					//Stride Factor


	//// Capture Signal												////
	logic [WIDTH_LENGTH:0]		R_AccCount;		        //Access Counter
	logic [WIDTH_ADDR:0]		R_Stride;       		//Stride Factor
	logic [WIDTH_ADDR-1:0]		R_Address;      		//Address


	//// Initialize Sequence										////
	//	 1 Set Lnegth	(WIDTH_LENGTH+1-bit)
	//	 2 Set Stride	(WIDTH_ADDR-bit)
	//	 3 Set Base		(WIDTH_ADDR-bit)


	//// Context-Switch Timing										////
	//	 Read -witch is same or later timing of Write-Switch


	//// Enable Address Calc										////
	//	 I_R_Context_Switch can be high when it is note yet terminated
	//	 Updating address is used after the switch
	//	 This is happen in External RAM
	assign EnUpdate			= I_En_AddrGen & ( R_AccCount != '0 );


	//// Select Stride Factor or Branch Distance					////
	//	 Most-Significant Half Word:	Branch Taken
	//	 Least-Significant Half Word:	Branch NOT Taken
	assign Stride			= ( I_Cond & I_Set_Stride ) ?		I_Stride[WIDTH_ADDR-1:WIDTH_ADDR/2] :
								( ~I_Cond & I_Set_Stride ) ?	'0 :
																'0;


	//// Memory Address												////
	assign O_Address		= R_Address;


	//// Termination												////
	assign O_Term			= ( R_AccCount == 1 ) & I_En_AddrGen;


	//// Access Counter												////
	//	 Count the number of accesses
	//	 Generates O_Term flag when reachees zero
	always_ff @( posedge clock ) begin: ff_acccount
		if ( reset ) begin
			R_AccCount	<= '0;
		end
		else if ( I_Set_Length ) begin
			R_AccCount	<= I_Length + 1'b1;
		end
		else if ( EnUpdate ) begin
			// Count by End
			R_AccCount	<= R_AccCount - 1'b1;
		end
	end


	//// Capture Stride Factor										////
	//	 Set "Value + 1, ex. "0" -> 1 this avoids a "while-loop"
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stride	<= '0;
		end
		else if ( I_Set_Stride ) begin
			R_Stride	<= I_Stride[WIDTH_ADDR/2-1:0] + 1'b1;
		end
	end


	//// Access Address												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Address	<= '0;
		end
		else if ( I_Set_Base ) begin
			// Set Base Address
			R_Address	<= I_Base;
		end
		else if ( EnUpdate & I_Decrement ) begin
			// Decriment by Stride
			R_Address	<= R_Address - R_Stride;
		end
		else if ( EnUpdate & ~I_Decrement ) begin
			// Increment by Stride
			R_Address	<= R_Address + R_Stride;
		end
	end

endmodule
