///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Condition Signal Control on Link Element
//	Module Name:	LECondUnit
//	Function:
//					Capture CONditino Signal
//					Avoid Multiple Capturings
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module LECondUnit
	import	pkg_en::*;
(
	input							clock,
	input							reset,
	input           	        	I_Clr,				//Clear Condition
	input	bit2_t					I_InC,				//Recieve Token
	output	logic					O_Valid,    		//Valid Token
	output	logic					O_Cond      		//Condition Code
);


	//// Logic Connect												////
	logic						Valid;


	//// Capture Signal												////
	logic						R_Cond;
	logic						R_Lock;

	assign Valid			= I_InC[0];
	assign O_Valid			= R_Lock;
	assign O_Cond			= R_Cond;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cond			<= 1'b0;
			R_Lock			<= 1'b0;
		end
		else if ( I_Clr ) begin
			R_Cond			<= 1'b0;
			R_Lock			<= 1'b0;
		end
		else if ( Valid & ~R_Lock ) begin
			R_Cond			<= I_InC[1];
			R_Lock			<= 1'b1;
		end
	end

endmodule