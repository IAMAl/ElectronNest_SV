///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Store-Sequence Controller for CRAM
//		Module Name:	CRAM_St_CTRL
//		Function:
//						Control for Storing
//						Current storing does not support "Push"
//						Generates and Transfer Signals;
//						- Store Request
//						- Stall (Nack)
//						- Data
//						- Handshake Tokens
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module CRAM_St_CTRL
	import pkg_mem::*;
#(
	parameter int WIDTH_LENGTH		= 8,
	parameter int NumWordsLength	= 1,
	parameter int NumWordsStride	= 1,
	parameter int NumWordsBase		= 1
)(
	input							clock,
	input							reset,
	input							I_Valid,			//Valid Token
	input							I_Nack,				//Nack Token
	input							is_Acq,				//Acquirement Token
	input							is_Rls,				//Release Token
	input							is_RConfigData,		//Flag: Attribute Block is RE Config
	input							is_AuxData,			//Flag: Attribute Block is Aux-Data
	input							is_AccessEnd,		//Flag: End of Access
	output	logic					O_Set_ConfigData,	//Set Configuration Data
	output	logic					O_We_Length,		//Write-Enable for Access Length
	output	logic					O_We_Stride,		//Write-Enable	for Stride Factor
	output	logic					O_We_Base,			//Write-Enable for Base Address
	output	logic					O_Req,				//Store Request
	output	logic					O_Acq,				//Store First Word
	output	logic					O_Rls,				//Store Last Word
	output	logic					O_Trm,				//Termination
	output	[1:0]					O_IDNo,				//Storeing ID No.
	output	logic					O_StoreIDs			//Store IDs
);


	//// Finite-State Machines										////
	fsm_stcore					FSM_StCore;
	fsm_storeids				FSM_StStoreIDs;
	fsm_config_st				FSM_Set_StConfig;


	//// Logic Connect												////
	logic						Str_Set_StConfig;		//Command: Setting R-Config Data
	logic						End_Set_StConfig;		//Flag: End of Setting R-Config Data

	logic						End_StoreIDs;			//Flag: End of String IDs


	//// Capture Signal												////
	logic						R_Req;
	logic						R_Acq;
	logic						R_NumWords;


	//// Storing IDs												////
	//	 End of Storing IDs
	assign End_StoreIDs		= ( FSM_StCore == iNIT_CTRL_ST ) & ( FSM_StStoreIDs == sT_F_ID );

	//	 Store IDs
	assign O_StoreIDs		= (  ( FSM_StStoreIDs == iNIT_ST_ID ) & is_Acq ) |
								(( FSM_StStoreIDs == sT_T_ID )    & I_Valid ) |
								(( FSM_StStoreIDs == sT_F_ID )    & I_Valid );

	//	 No for Storing
	assign O_IDNo			= FSM_StStoreIDs;


	//// Setting Configuration Data									////
	//	 Start of Setting


	assign Str_Set_StConfig	= ( FSM_StCore == gET_CONFIG_ST );

	//	 End of Setting
	assign End_Set_StConfig	= ( FSM_StCore == gET_CONFIG_ST ) & ( FSM_Set_StConfig == sET_STRIDE_ST );


	//// Control Signals											////
	assign O_Set_ConfigData	= I_Valid & Str_Set_StConfig & ( FSM_Set_StConfig == iNIT_CONFIG_ST );
	assign O_We_Length		= I_Valid & ( R_NumWords == NumWordsLength ) & ( FSM_Set_StConfig == sET_CONFIG_ST );
	assign O_We_Stride		= I_Valid & ( R_NumWords == NumWordsStride ) & ( FSM_Set_StConfig == sET_LENGTH_ST );
	assign O_We_Base		= I_Valid & ( R_NumWords == NumWordsBase )   & ( FSM_Set_StConfig == sET_STRIDE_ST );


	//// Tokens														////
	assign O_Req			= R_Req;
	assign O_Acq			= R_Acq;
	assign O_Rls			= is_Rls & ( FSM_StCore != iNIT_CTRL_ST );
	assign O_Trm			= is_AccessEnd | ( is_Rls & ( FSM_StCore == aCTIVE_ST ) );


	//// Storing IDs												////
	always_ff @( posedge clock ) begin: ff_fsm_st_id
		if ( reset ) begin
			FSM_StStoreIDs	<= iNIT_ST_ID;
		end
		else case ( FSM_StStoreIDs )
			iNIT_ST_ID: begin
				if ( is_Acq ) begin
					FSM_StStoreIDs	<= sT_T_ID;
				end
				else begin
					FSM_StStoreIDs	<= iNIT_ST_ID;
				end
			end
			sT_T_ID: begin
				if ( I_Valid ) begin
					FSM_StStoreIDs	<= sT_F_ID;
				end
			end
			sT_F_ID: begin
				if ( I_Valid ) begin
					FSM_StStoreIDs	<= iNIT_ST_ID;
				end
			end
			default: begin
				FSM_StStoreIDs	<= iNIT_ST_ID;
			end
		endcase
	end


	//// Setting Configuration Data									////
	always_ff @( posedge clock ) begin: ff_fsm_set_config
		if ( reset ) begin
			R_NumWords			<= '0;
			FSM_Set_StConfig	<= iNIT_CONFIG_ST;
		end
		else case ( FSM_Set_StConfig )
			iNIT_CONFIG_ST: begin
				if ( I_Valid & Str_Set_StConfig ) begin
					R_NumWords			<= 1;
					FSM_Set_StConfig	<= sET_CONFIG_ST;
				end
				else begin
					R_NumWords			<= '0;
					FSM_Set_StConfig	<= iNIT_CONFIG_ST;
				end
			end
			sET_CONFIG_ST: begin
				if ( I_Valid & ( R_NumWords == NumWordsLength )) begin
					R_NumWords			<= 1;
					FSM_Set_StConfig	<= sET_LENGTH_ST;
				end
				else begin
					if ( R_NumWords < NumWordsLength ) begin
						R_NumWords		<= R_NumWords + I_Valid;
					end
					FSM_Set_StConfig	<= sET_CONFIG_ST;
				end
			end
			sET_LENGTH_ST: begin
				if ( I_Valid & ( R_NumWords == NumWordsStride )) begin
					R_NumWords			<= 1;
					FSM_Set_StConfig	<= sET_STRIDE_ST;
				end
				else begin
					if ( R_NumWords < NumWordsStride ) begin
						R_NumWords		<= R_NumWords + I_Valid;
					end
					FSM_Set_StConfig	<= sET_LENGTH_ST;
				end
			end
			sET_STRIDE_ST: begin
				if ( I_Valid & ( R_NumWords == NumWordsBase )) begin
					R_NumWords			<= '0;
					FSM_Set_StConfig	<= iNIT_CONFIG_ST;
				end
				else begin
					if ( R_NumWords < NumWordsBase ) begin
						R_NumWords		<= R_NumWords + I_Valid;
					end
					FSM_Set_StConfig	<= sET_STRIDE_ST;

				end
			end
			default: begin
				R_NumWords			<= '0;
				FSM_Set_StConfig	<= iNIT_CONFIG_ST;
			end
		endcase
	end


	//// Main Control FSM											////
	always_ff @( posedge clock ) begin : ff_fsm_st
		if ( reset ) begin
			R_Req		<= 1'b0;
			R_Acq		<= 1'b0;
			FSM_StCore	<= iNIT_CTRL_ST;
		end
		else case ( FSM_StCore )
			iNIT_CTRL_ST: begin
				if ( End_StoreIDs ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= gET_ATTRIB_ST;
				end
				else begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= iNIT_CTRL_ST;
				end
			end
			gET_ATTRIB_ST: begin
				if ( I_Valid & is_RConfigData ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= gET_CONFIG_ST;
				end
			end
			gET_CONFIG_ST: begin
				if ( End_Set_StConfig ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= gET_ATTRIB2_ST;
				end
			end
			gET_ATTRIB2_ST: begin
				if ( I_Valid & ~I_Nack & is_AuxData ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= aCTIVE_ST;
				end
				else if ( ~I_Valid & ~I_Nack ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= rEADY_ST;
				end
			end
			rEADY_ST: begin
				if ( I_Valid ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= aCTIVE_ST;
				end
			end
			aCTIVE_ST: begin
				if ( is_Rls ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= iNIT_CTRL_ST;
				end
				else if ( is_AccessEnd ) begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= iNIT_CTRL_ST;
				end
				else if ( I_Nack ) begin
					R_Req		<= 1'b0;
					R_Acq		<= R_Acq;
					FSM_StCore	<= aCTIVE_ST;
				end
				else if ( I_Valid ) begin
					R_Req		<= 1'b1;
					R_Acq		<= 1'b0;
					FSM_StCore	<= aCTIVE_ST;
				end
				else begin
					R_Req		<= 1'b0;
					R_Acq		<= 1'b0;
					FSM_StCore	<= aCTIVE_ST;
				end
			end
			default: begin
				R_Req		<= 1'b0;
				R_Acq		<= 1'b0;
				FSM_StCore	<= iNIT_CTRL_ST;
			end
		endcase
	end

endmodule
