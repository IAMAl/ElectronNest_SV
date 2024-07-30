///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//		Module Name:	Counter
//		Function:
//						Count by One at Enable-High
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Counter
#(
	parameter int WIDTH_COUNT		= 8
)(
	input							clock,
	input							reset,
	input							I_En,							//Count-Enable
	input							I_Clr,							//Clear Counter
	output	[WIDTH_COUNT-1:0]		O_Val							//Count-Value
);


	logic [WIDTH_COUNT-1:0] 	R_Count;


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Count			<= '0;
		end
		else if ( I_Clr ) begin
			R_Count 		<= '0;
		end
		else if ( I_En ) begin
			R_Count 		<= R_Count + 1'b1;
		end
	end

	assign O_Val		= R_Count;

endmodule
