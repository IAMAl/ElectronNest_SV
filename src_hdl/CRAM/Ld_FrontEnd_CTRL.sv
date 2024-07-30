///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load Controller (Front-End)
//		Module Name:	Ld_FrontEnd_CTRL
//		Function:
//						Control Loading-Service as Front-End
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Ld_CTRL_FrontEnd
	import	pkg_mem::*;
(
	input							clock,
	input							reset,
	input							I_Boot,				//Kick-Start (NOT Pulse)
	input							I_Valid,		    //Valid Token from Request-Path
	input							I_Stall,			//Stall Signal
	input							is_Acq,				//Flag: Acquirement Token
	input							is_Rls,				//Flag: Release Token
	input							is_Shared,			//Flag: Shared Data Word is held
	input							is_PullReq,			//Flag: Pull Request
	input							is_MyAttrib,		//Flag: Attribute Word is Mine
	input							is_RConfigData,		//Flag: Attribution Block is RE-Config
	input							is_Term_Load,	    //Flag: Loading is Ended
	input							is_Term_BTk,		//Flag: Termination by I_BTk.t
	input							is_Ack_BackEnd,		//Flag: Ack from BackEnd
	input							is_IndirectMode,	//Flag: Indirect Access Mode
	input							is_Matched,			//Flag: Index-Match used for Index-Compress
	input							is_End_Rename,		//Flag: End of Indirect-Access Sequence
	output	logic					O_StoreIDs,			//Store IDs
	output	logic					O_Set_Up,			//Avoid Unnecessary Output
	output	logic					O_Send_MyID,		//Send My-ID
	output	logic					O_Send_ID_T,		//Send True-ID
	output	logic					O_Send_ID_F,		//Send False-ID
	output	logic					O_Stall_In,			//State in Tail-Load
    output  logic					O_Set_AttribWord,	//Set Attribute Word
	output	logic					O_Set_RConfig,		//Set R-Config Data
	output	logic					O_Set_Length,		//Set Access-Length
	output	logic					O_Set_Stride,		//Set Atride Factor
	output	logic					O_Set_Base,			//Set Base Address
	output	logic					O_Bypass,			//Bypassing
	output	logic					O_Start_Load,		//Flag: First Loading
	output	logic					O_Start_Rename,		//Start of Indirect-Access Sequence
	output	logic					O_End_StoreIDs,		//Endf of Storing IDs
	output	logic					O_Busy,				//Flag: State in Busy
	output	logic [1:0]				O_Counter			//Number to Control Storing IDs
);


	//// Connecting Logic											////
	logic							is_FrontEnd_Init;
	logic							is_FrontEnd_Attrib;
	logic							is_FrontEnd_RCfg;
	logic							is_FrontEnd_Length;
	logic							is_FrontEnd_Stride;
	logic							is_FrontEnd_Base;
	logic							is_FrontEnd_MyID;
	logic							is_FrontEnd_ID_T;
	logic							is_FrontEnd_ID_F;
	logic							is_FrontEnd_Bypass;
	logic							is_FrontEnd_Load;
	logic							is_FrontEnd_IAccess;
	logic							is_FrontEnd_IEnd;

	logic							End_StoreIDs;
	logic							End_Set_Rconfig;
	logic							End_Count;


	//// Capturing Logic											////
	fsm_ldfe						FSM_Ld_FrontEnd;
	logic	[1:0]					R_Counter;
	logic							R_is_Shared;
	logic							R_is_PullReq;
	logic							R_is_Bypass;


	assign is_FrontEnd_Init		= ( FSM_Ld_FrontEnd == lD_FRONTEND_INIT );
	assign is_FrontEnd_Attrib	= ( FSM_Ld_FrontEnd == lD_FRONTEND_ATTRIB );
	assign is_FrontEnd_RCfg		= ( FSM_Ld_FrontEnd == lD_FRONTEND_RCFG );
	assign is_FrontEnd_Length	= ( FSM_Ld_FrontEnd == lD_FRONTEND_LENGTH );
	assign is_FrontEnd_Stride	= ( FSM_Ld_FrontEnd == lD_FRONTEND_STRIDE );
	assign is_FrontEnd_Base		= ( FSM_Ld_FrontEnd == lD_FRONTEND_BASE );
	assign is_FrontEnd_MyID		= ( FSM_Ld_FrontEnd == lD_FRONTEND_MyID );
	assign is_FrontEnd_ID_T		= ( FSM_Ld_FrontEnd == lD_FRONTEND_ID_T );
	assign is_FrontEnd_ID_F		= ( FSM_Ld_FrontEnd == lD_FRONTEND_ID_F );
	assign is_FrontEnd_Bypass	= ( FSM_Ld_FrontEnd == lD_FRONTEND_BYPASS );
	assign is_FrontEnd_Load		= ( FSM_Ld_FrontEnd == lD_FRONTEND_LOAD );
	assign is_FrontEnd_IAccess	= ( FSM_Ld_FrontEnd == lD_FRONTEND_IACCESS );
	assign is_FrontEnd_IEnd		= ( FSM_Ld_FrontEnd == lD_FRONTEND_IEND );

	// Set-up Phase Flag
	assign O_Set_Up			= ( FSM_Ld_FrontEnd < lD_FRONTEND_MyID ) | ( FSM_Ld_FrontEnd > lD_FRONTEND_ID_F );

	//	 Storing IDs
	assign O_StoreIDs		= (is_FrontEnd_Init & is_Acq ) | ( FSM_Ld_FrontEnd == lD_FRONTEND_ID );
	assign O_Counter		= R_Counter;

	//	 Set R-Config Data Block
	assign O_Set_AttribWord	= is_FrontEnd_Attrib & I_Valid & ~is_IndirectMode;
	assign O_Set_RConfig	= is_FrontEnd_RCfg & I_Valid;
	assign O_Set_Length		= is_FrontEnd_Length & I_Valid;
	assign O_Set_Stride		= is_FrontEnd_Stride & I_Valid;
	assign O_Set_Base		= is_FrontEnd_Base & I_Valid;

	//	 Send IDs
	assign O_Send_MyID		= is_FrontEnd_MyID;
	assign O_Send_ID_T		= is_FrontEnd_ID_T;
	assign O_Send_ID_F		= is_FrontEnd_ID_F;

	//	 Froce Bypassing
	assign O_Bypass			= is_FrontEnd_MyID |
								is_FrontEnd_ID_T |
								is_FrontEnd_ID_F |
								is_FrontEnd_Bypass |
								( is_FrontEnd_Load & is_IndirectMode ) |
								is_FrontEnd_IAccess |
								R_is_Bypass;

	//	 End of Loading IDs
	assign O_End_StoreIDs	= End_StoreIDs;

	//	 Start Loading
	assign O_Start_Load		= is_FrontEnd_Load | ( is_FrontEnd_Base & is_Rls );

	//	 Froce Stall for Input Data
	assign O_Stall_In		= ( ( FSM_Ld_FrontEnd == lD_FRONTEND_BASE ) & R_is_PullReq ) |
								is_FrontEnd_MyID |
								is_FrontEnd_ID_T |
								is_FrontEnd_ID_F |
								( is_FrontEnd_Load & is_IndirectMode ) |
								is_FrontEnd_IAccess;

	//	 State in Busy
	assign O_Busy			= ( FSM_Ld_FrontEnd != lD_FRONTEND_INIT );


	//// Extension													////
	//	 Start Renaming
	assign O_Start_Rename	= is_FrontEnd_Bypass;

	assign End_StoreIDs		= ( R_Counter == 2 ) & ( FSM_Ld_FrontEnd == lD_FRONTEND_ID ) & I_Valid;
	assign End_Set_Rconfig	= ( R_Counter == 3 ) & is_FrontEnd_Stride & I_Valid;
	assign End_Count		= End_StoreIDs | End_Set_Rconfig;

	//
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Bypass		<= 1'b0;
		end
		else if ( is_Rls ) begin
			R_is_Bypass		<= 1'b0;
		end
		else if ( is_FrontEnd_Bypass ) begin
			R_is_Bypass		<= 1'b1;
		end
	end

	//	 Capture Pull-Request
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_PullReq	<= 1'b0;
		end
		else if ( is_FrontEnd_Init ) begin
			R_is_PullReq	<= 1'b0;
		end
		else if ( is_MyAttrib & is_PullReq & is_FrontEnd_Attrib ) begin
			R_is_PullReq	<= 1'b1;
		end
	end

	//	 Counting for Storing IDs
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Counter		<= '0;
		end
		else if ( End_Count ) begin
			R_Counter		<= '0;
		end
		else if ( ( R_Counter > 0 ) & I_Valid ) begin
			R_Counter		<= R_Counter + 1'b1;
		end
		else if ( (( is_FrontEnd_Init & is_Acq ) | (is_FrontEnd_Attrib & is_MyAttrib & is_RConfigData )) & I_Valid ) begin
			R_Counter		<= 1;
		end
	end

	//	 Extension: Capture is_Shared Flag
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Shared		<= 1'b0;
		end
		else if ( is_FrontEnd_Init ) begin
			R_is_Shared		<= 1'b0;
		end
		else if ( is_MyAttrib & is_Shared & is_FrontEnd_Attrib ) begin
			R_is_Shared 	<= 1'b1;
		end
	end

	//	 FSM for Controlling
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
		end
		else case ( FSM_Ld_FrontEnd )
		lD_FRONTEND_INIT: begin
			if ( is_Acq ) begin
				//Start Sequence
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
			end
		end
		lD_FRONTEND_ID: begin
			if ( End_StoreIDs ) begin
				//Start Receive Attribute Word
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ATTRIB;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID;
			end
		end
		lD_FRONTEND_ATTRIB: begin
			if ( I_Valid & is_MyAttrib & is_RConfigData ) begin
				//Start Setting R-Config
				FSM_Ld_FrontEnd	<= lD_FRONTEND_RCFG;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ATTRIB;
			end
		end
		lD_FRONTEND_RCFG: begin
			if ( I_Valid ) begin
				//Start Setting Length
				FSM_Ld_FrontEnd	<= lD_FRONTEND_LENGTH;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_RCFG;
			end
		end
		lD_FRONTEND_LENGTH: begin
			if ( I_Valid ) begin
				//Start Setting Stride
				FSM_Ld_FrontEnd	<= lD_FRONTEND_STRIDE;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_LENGTH;
			end
		end
		lD_FRONTEND_STRIDE: begin
			if ( I_Valid ) begin
				//Start Setting Base
				FSM_Ld_FrontEnd	<= lD_FRONTEND_BASE;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_STRIDE;
			end
		end
		lD_FRONTEND_BASE: begin
			if ( R_is_PullReq & is_Rls ) begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
			end
			else if ( R_is_PullReq & I_Valid ) begin
				//Start Bypassing
				FSM_Ld_FrontEnd	<= lD_FRONTEND_MyID;
			end
			else if ( ~R_is_PullReq ) begin
				//Trigger Loading
				FSM_Ld_FrontEnd	<= lD_FRONTEND_LOAD;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_BASE;
			end
		end
		lD_FRONTEND_MyID: begin
			if ( ~I_Stall ) begin
				//Next: Storing True-ID
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID_T;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_MyID;
			end
		end
		lD_FRONTEND_ID_T: begin
			if ( ~I_Stall ) begin
				//Next: Storing False-ID
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID_F;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID_T;
			end
		end
		lD_FRONTEND_ID_F: begin
			if ( is_IndirectMode ) begin
				//End of Loading, doing for Indirect-Access
				FSM_Ld_FrontEnd	<= lD_FRONTEND_LOAD;
			end
			else if ( ~I_Stall ) begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_BYPASS;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_ID_F;
			end
		end
		lD_FRONTEND_BYPASS: begin
			if ( I_Valid & is_Rls & ~I_Stall ) begin
				//Trigger Loading
				FSM_Ld_FrontEnd	<= lD_FRONTEND_LOAD;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_BYPASS;
			end
		end
		lD_FRONTEND_LOAD: begin
			if ( is_IndirectMode ) begin
				//End of Loading, doing for Indirect-Access
				FSM_Ld_FrontEnd	<= lD_FRONTEND_IACCESS;
			end
			else begin
				//Next Sequence (Common)
				FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
			end
		end
		lD_FRONTEND_IACCESS: begin
			if ( is_IndirectMode & is_Ack_BackEnd & ~is_Matched ) begin
				//Start Rename Sequence
				FSM_Ld_FrontEnd	<= lD_FRONTEND_IEND;
			end
			else if ( is_IndirectMode & is_Ack_BackEnd & is_Matched ) begin
				//Wait for Ack from BackEnd
				FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
			end
			else begin
				//Wait for Loading Next Message
				FSM_Ld_FrontEnd	<= lD_FRONTEND_IACCESS;
			end
		end
		lD_FRONTEND_IEND: begin
			if ( ( is_Term_Load | is_End_Rename ) & ~I_Stall ) begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
			end
			else begin
				FSM_Ld_FrontEnd	<= lD_FRONTEND_IEND;
			end
		end
		default:
			FSM_Ld_FrontEnd	<= lD_FRONTEND_INIT;
		endcase
	end

endmodule