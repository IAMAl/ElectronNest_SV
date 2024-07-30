///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load Controller (Back-End)
//		Module Name:	Ld_BackEnd_CTRL
//		Function:
//						Load Back-End Controller.
//						Primary Controller for Loading.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Ld_CTRL_BackEnd
	import pkg_mem::*;
#(
	parameter int EXTERNAL = 1
)(
	input							clock,
	input							reset,
	input							I_Req,				//Start Sequence
	input							I_Valid,		    //Valid Token
	input							I_Stall,			//Stall
	input							I_Bypass,			//Flag: Bypassing before Loading
	input							is_StoredIDs,		//Flag: IDs are Stored at FrontEnd
	input							is_Shared,			//Flag: Shared Data Word is held
	input							is_Data_Block,		//Flag: Data Block
	input							is_Term_Load,	    //Flag: End of Loading
	input							is_End_Load,		//Flag: End of Loading
	input							is_Zero,			//Flag: Shared Data is Zero
	input							is_Event_Load,		//Flag: Loading Event
	input							is_Rls,				//Flag: Release Token is sent
	input							is_IndirectMode,	//Flag: Indirect Access Mode
	input							is_Loaded,			//Flag: Loaded used for Indirect-Access
	input							is_Matched,			//Flag: Match used for Indirect-Access
	input							is_Bypass,			//Flag: Bypassing for Pulling
	input							is_End_Rename,		//Flag: End of Rename
	output	logic					O_LoadIDs,			//Send IDs
	output	logic					O_Start_RouteGen,	//Start Renaming
	output	logic					O_Set_RConfig,		//Set R-Config Data Word
    output  logic					O_Test_First_Load,	//Fource Loading used for Indirect-Access
	output	logic					O_Check_ID,			//Test for Indirect-Access
	output	logic					O_Send_AttribWord,	//Send Atrtribute Word for Data Block
	output	logic					O_Send_Shared,		//Send Shared Data if Shared Data is Non-Zero
	output	logic					O_Load,				//Loading
	output	logic					O_Data_Load,		//Loading Data on second context
	output	logic					O_Set_Acq,			//Set Acq Token to Send
	output	logic					O_Tail_Load,		//Flag: Tail of Loading
	output	logic					O_First_Load,		//Flag: First-Loading
	output	logic					O_Bypass,			//Doing Bypassing
	output	logic					O_Stall,			//Force Stalling for Bypassing
	output	logic					O_Busy				//Flag: State in Busy
);

	logic							Extern;
	assign Extern			= EXTERNAL;

	//	 State in Controller
	logic							is_BackEnd_Init;
	logic							is_BackEnd_ChkID;
	logic							is_BackEnd_Attrib;
	logic							is_BackEnd_Shared;
	logic							is_BackEnd_FirstLoad;
	logic							is_BackEnd_Load;
	logic							is_BackEnd_EndTest;

	//	 FSM for Controlling
	fsm_ldbe						FSM_Ld_BackEnd;

	//	 End of Loading IDs
	logic							End_LoadIDs;
	logic							End_Count;


	//// Capturing Logic											////
	logic							R_Test_First_Load;
	logic	[1:0]					R_Counter;
	logic							R_RunLoad;
	logic							R_is_Bypass;


	//// State in Controll											////
	assign is_BackEnd_Init		= ( FSM_Ld_BackEnd == lD_BACKEND_INIT );
	assign is_BackEnd_ChkID		= ( FSM_Ld_BackEnd == lD_BACKEND_CHK_ID );
	assign is_BackEnd_Attrib	= ( FSM_Ld_BackEnd == lD_BACKEND_ATTRIB );
	assign is_BackEnd_Shared	= ( FSM_Ld_BackEnd == lD_BACKEND_SHARED );
	assign is_BackEnd_Load		= ( FSM_Ld_BackEnd == lD_BACKEND_LOAD );
	assign is_BackEnd_FirstLoad	= ( FSM_Ld_BackEnd == lD_BACKEND_FIRST_LD );
	assign is_BackEnd_EndTest	= ( FSM_Ld_BackEnd == lD_BACKEND_END_TEST );


	//// State in Busy												////
	assign O_Busy			= ( FSM_Ld_BackEnd != lD_BACKEND_INIT );


	//// Load IDs													////
	assign O_LoadIDs		= ( FSM_Ld_BackEnd == lD_BACKEND_ID );


	//// Loading Control											////
	assign O_Test_First_Load= is_BackEnd_Init & I_Req & is_IndirectMode;
	assign O_Set_RConfig	= is_BackEnd_Init & I_Req;
	assign O_Set_Acq		= is_BackEnd_FirstLoad & I_Valid & ~R_RunLoad & ~R_is_Bypass;
	assign O_Send_AttribWord= is_BackEnd_Attrib & ~is_IndirectMode;
	assign O_Load			= ( FSM_Ld_BackEnd > lD_BACKEND_SHARED );
	assign O_First_Load		= is_BackEnd_FirstLoad & ~( is_Event_Load | ( I_Valid & R_is_Bypass ) );
	assign O_Data_Load		= ( is_BackEnd_Load & ~I_Bypass ) | ( is_BackEnd_ChkID & ~R_Test_First_Load );
	assign O_Bypass			= R_is_Bypass & ( FSM_Ld_BackEnd < lD_BACKEND_ATTRIB );
	assign O_Tail_Load		= is_BackEnd_EndTest;


	//// Extensions													////
	assign O_Check_ID		= is_BackEnd_ChkID;
	assign O_Stall			= is_BackEnd_ChkID;
	assign O_Start_RouteGen	= is_BackEnd_ChkID & ~is_Matched & is_Loaded;
	assign O_Send_Shared	= ( FSM_Ld_BackEnd == lD_BACKEND_SHARED );

	assign End_LoadIDs		= ( R_Counter == 2 ) & ( FSM_Ld_BackEnd == lD_BACKEND_ID );
	assign End_Count		= End_LoadIDs;


	//	 Making Pulse Signal
	always_ff @(posedge clock ) begin
		if ( reset ) begin
			R_Test_First_Load		<= 1'b0;
		end
		else begin
			R_Test_First_Load		<= is_BackEnd_ChkID;
		end
	end

	//	 Capture is_Bypass Flag
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Bypass	<= 1'b0;
		end
		else if ( is_Rls | ( is_BackEnd_Load & is_End_Load ) ) begin
			R_is_Bypass	<= 1'b0;
		end
		else if ( is_Bypass ) begin
			R_is_Bypass	<= 1'b1;
		end
	end

	//	 State in Loading After First-Load
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RunLoad	<= 1'b0;
		end
		else if ( FSM_Ld_BackEnd == '0 ) begin
			R_RunLoad	<= 1'b0;
		end
		else if ( is_BackEnd_FirstLoad & I_Valid ) begin
			R_RunLoad	<= 1'b1;
		end
	end

	//	 Counter for Loading IDs
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Counter	<= '0;
		end
		else if ( End_Count ) begin
			R_Counter	<= '0;
		end
		else if ( ( R_Counter > 0 ) & ~I_Stall ) begin
			R_Counter	<= R_Counter + 1'b1;
		end
		else if ( I_Req & is_BackEnd_Init & is_Data_Block & is_StoredIDs ) begin
			R_Counter	<= 1'b1;
		end
	end

	//	 Control FSM
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			FSM_Ld_BackEnd	<= lD_BACKEND_INIT;
		end
		else case ( FSM_Ld_BackEnd )
		lD_BACKEND_INIT: begin
			if ( I_Req & ( Extern | R_is_Bypass | ~is_StoredIDs ) & is_Data_Block ) begin
				//Send Attribute Word
				FSM_Ld_BackEnd	<= lD_BACKEND_ATTRIB;
			end
			else if ( I_Req & is_StoredIDs & ~R_is_Bypass & is_Data_Block ) begin
				//Start Loading IDs
				FSM_Ld_BackEnd	<= lD_BACKEND_ID;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_INIT;
			end
		end
		lD_BACKEND_ID: begin
			if ( End_LoadIDs ) begin
				//Start Receive Attribute Word
				FSM_Ld_BackEnd	<= lD_BACKEND_ATTRIB;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_ID;
			end
		end
		lD_BACKEND_ATTRIB: begin
			if ( ~I_Stall & is_Shared ) begin
				//Send Shared Data Word
				FSM_Ld_BackEnd	<= lD_BACKEND_SHARED;
			end
			else if ( ~I_Stall & ~is_Shared ) begin
				//Start Loading
				FSM_Ld_BackEnd	<= lD_BACKEND_FIRST_LD;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_ATTRIB;
			end
		end
		lD_BACKEND_SHARED: begin
			if ( ~I_Stall ) begin
				//Start Loading
				FSM_Ld_BackEnd	<= lD_BACKEND_FIRST_LD;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_SHARED;
			end
		end
		lD_BACKEND_FIRST_LD: begin
			if ( is_IndirectMode ) begin
				//Start Testimg Base Data for Indirect Access
				FSM_Ld_BackEnd	<= lD_BACKEND_CHK_ID;
			end
			else if ( is_Event_Load | ( I_Valid & R_is_Bypass ) ) begin
				//Begining of Data-Loading
				FSM_Ld_BackEnd	<= lD_BACKEND_LOAD;
			end
			else if ( is_Term_Load ) begin
				//End of Loading
				FSM_Ld_BackEnd	<= lD_BACKEND_END_TEST;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_FIRST_LD;
			end
		end
		lD_BACKEND_LOAD: begin
			if ( is_Rls ) begin
				//End of Data-Loading
				FSM_Ld_BackEnd	<= ( R_is_Bypass ) ? lD_BACKEND_INIT : lD_BACKEND_FIRST_LD;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_LOAD;
			end
		end
		lD_BACKEND_CHK_ID: begin
			if ( is_Loaded & is_Matched ) begin
				//End of Testing
				FSM_Ld_BackEnd	<= lD_BACKEND_LOAD;
			end
			else if ( is_Loaded & ~is_Matched ) begin
				//End of Testing
				FSM_Ld_BackEnd	<= lD_BACKEND_RENAME;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_CHK_ID;
			end
		end
		lD_BACKEND_RENAME: begin
			if ( is_End_Rename & ~I_Stall ) begin
				//End of Rename Sequence
				FSM_Ld_BackEnd	<= lD_BACKEND_INIT;
			end
			else begin
				//End of Testing
				FSM_Ld_BackEnd	<= lD_BACKEND_RENAME;
			end
		end
		lD_BACKEND_END_TEST: begin
			if ( is_Rls ) begin
				//End of Testing
				FSM_Ld_BackEnd	<= lD_BACKEND_INIT;
			end
			else begin
				FSM_Ld_BackEnd	<= lD_BACKEND_END_TEST;
			end
		end
		default:
			FSM_Ld_BackEnd	<= lD_BACKEND_INIT;
		endcase
	end

endmodule