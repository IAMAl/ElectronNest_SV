///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Condition Signal Handler
//		Module Name:	CRAMCondUnit
//		Function:
//						Capture Condition Signal
//						Avoid Multiple Capturings
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module CRAMCondUnit
	import	pkg_en::*;
(
	input							clock,
	input							reset,
	input               	    	I_Clr,				//Clear Condition
	input	BTk_t					I_BTk,				//Recieve Back-Prop Token
	output	logic					O_Valid,    		//Valid Token (Back-Prop)
	output	logic					O_Cond      		//Condition Signal
);


	//// Logic Connect												////
	logic						Valid;					//Valid Token (Backward)


	//// Capture Signal												////
	logic						R_Cond;					//Condition Flag
	logic						R_Lock;					//Avoid to Overwrite the Condition

	assign Valid			= I_BTk.v;

	assign O_Valid			= R_Lock;
	assign O_Cond			= R_Cond;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cond		<= 1'b0;
			R_Lock		<= 1'b0;
		end
		else if ( I_Clr ) begin
			R_Cond		<= 1'b0;
			R_Lock		<= 1'b0;
		end
		else if ( Valid & ~R_Lock ) begin
			R_Cond		<= I_BTk.c;
			R_Lock		<= 1'b1;
		end
	end

endmodule