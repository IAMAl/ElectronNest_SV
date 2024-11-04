///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load Server Unit (Front-End)
//		Module Name:	Ld_FrontEnd
//		Function:
//						Serves Loading Data and Sends Data.
//						Top Module of Front-End Part in Load Unit
//						The unit recives load-request from I_FTk.
//						Parsing R-Config Data, extension option, etc, and
//						sends these to Back-End through buffers.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Ld_FrontEnd
	import pkg_en::*;
	import pkg_extend_index::*;
#(
	parameter int WIDTH_ADDR		= 8,
	parameter int WIDTH_LENGTH		= 8,
	parameter int ExtdConfig		= 0
)(
	input							clock,
	input							reset,
	input							I_Boot,				//Kick-Start (NOT Pulse)
	input	FTk_t					I_FTk,		        //Message from Request-Path
	output	BTk_t					O_BTk,		        //Token to Request-Path
	input	FTk_t					I_Ld_FTk,			//Loaded Data from BackEnd
	input							I_Stall,			//Stall-Request
	input							is_Term_Load,	    //Flag: Loading is Ended
    input                           is_Ack_BackEnd,		//Ack from BackEnd
    input                           is_Matched,			//Flag Matched used for Indirect-Access
	input							is_Term_BTk,		//Flag: Termination by I_BTk.t
	input							is_End_Rename,		//Flag: End of Rename
	input							is_Busy_BackEnd,	//Flag: Busy at BackEnd
	input							is_Full_Buff,		//Flag: Full in Buffwer
	input							I_Shared,			//Flag: Block has Shared Data
	input	[WIDTH_LENGTH+1:0]		I_Actual_Length,	//Actual Block-Length
	output	logic					O_SendID,			//Flag: Send IDs
	output	[WIDTH_DATA-1:0]		O_MyID,				//Send My-ID to BackEnd
	output	[WIDTH_DATA-1:0]		O_ID_T,				//Send My-ID to BackEnd
	output	[WIDTH_DATA-1:0]		O_ID_F,				//Send My-ID to BackEnd
	output	[3:0]					O_MetaData,			//Send Meta Data to BackEnd
	output	FTk_t					O_FTk,				//Send Data to BackEnd
	output	[WIDTH_DATA-1:0]		O_AttribWord,		//Send Attrib Word to BackEnd
	output	[WIDTH_DATA-1:0]		O_RConfig,			//Send R-Condfig Data to BackEnd
	output	[WIDTH_LENGTH-1:0]		O_Length,			//Send Access-Length to BackEnd
	output	[WIDTH_ADDR-1:0]		O_Stride,			//Send Stride Factor to BackEnd
	output	[WIDTH_ADDR-1:0]		O_Base,				//Send Base Address to BackEnd
	output	logic					O_Bypass,			//Send Bypassing Data to BackEnd
	output	FTk_t					O_Bypass_FTk,		//Forword Tokens for Bypassing
	input	BTk_t					I_Bypass_BTk,		//Backword Tokens for Bypassing
	output	logic					O_Req_BackEnd		//Send Request to BackEnd
);

	localparam int NUM_MAX_REQ		= 4;
	localparam int WIDTH_NUM_REQ	= $clog2(NUM_MAX_REQ);

	logic REConfig;
	assign REConfig				= ~ExtdConfig;


	//// Connecting Logic											////
	logic							acq_message;
	logic							acq_flagmsg;
	logic							rls_message;
	logic							rls_flagmsg;
	logic							is_Acq;
	logic							is_Rls;

	//	 Set R-Config Data Block
	logic							Set_AttribWord;
	logic							Set_RConfig;
	logic							Set_Length;
	logic							Set_Stride;
	logic							Set_Base;

	logic	[1:0]					AccessMode;
	logic							is_Descrement;

	//	 Attribute Word Decode
	logic							is_PullReq;
	logic							is_Shared;
	logic							is_MyAttrib;
	logic							is_IndirectMode;
	logic							is_Term_Block;
	logic							is_DataWord;
	logic							is_RConfigData;


	logic							StoreIDs;
	logic							End_StoreIDs;

	logic							Bypass;
	logic							Start_Load;
	logic							Start_Rename;

	FTk_t							ConfigDec_FTk;

	logic							Send_MyID;
	logic							Send_ID_T;
	logic							Send_ID_F;
	logic	[1:0]					Counter;
	logic							Stall_In;

	FTk_t							W_FTk;
	BTk_t							W_BTk;

	logic							Set_Up;

	logic							Busy;


	//// Capturing Logic											////
	FTk_t							R_FTk;
	BTk_t							R_BTk;

	FTk_t							R_MyID;
	FTk_t							R_ID_T;
	FTk_t							R_ID_F;
	logic	[WIDTH_DATA-1:0]		R_RConfig;
	logic	[WIDTH_LENGTH+1:0]		R_Length;
	logic	[WIDTH_ADDR-1:0]		R_Stride;
	logic	[WIDTH_ADDR-1:0]		R_Base;

	logic	[WIDTH_DATA-1:0]		R_AttributeWord;

	logic	[3:0]					R_MetaData;

	logic							R_End_StoreIDs;

	logic							R_Req_BackEnd;

	logic							R_is_Busy_BackEnd;

	logic							R_Stop;


	assign W_BTk.n			= I_Bypass_BTk.n | R_Stop;;
	assign W_BTk.t			= I_Bypass_BTk.t;
	assign W_BTk.v			= I_Bypass_BTk.v;
	assign W_BTk.c			= I_Bypass_BTk.c;

	assign O_BTk.n			= ( ( R_BTk.n | I_Bypass_BTk.n ) & Bypass ) | R_Stop | is_Full_Buff;
	assign O_BTk.t			= R_BTk.t;
	assign O_BTk.v			= R_BTk.v;
	assign O_BTk.c			= R_BTk.c;

	assign O_AttribWord		= R_AttributeWord;
	assign O_RConfig		= R_RConfig;
	assign O_Length			= R_Length;
	assign O_Stride			= R_Stride;
	assign O_Base			= R_Base;

	assign O_Bypass			= Bypass;
	always_comb begin
	/*assign */O_Bypass_FTk		= R_FTk;
	end
	assign O_MyID			= R_MyID.d;
	assign O_ID_T			= R_ID_T.d;
	assign O_ID_F			= R_ID_F.d;
	assign O_MetaData		= R_MetaData;
	assign O_FTk			= ( Set_Up ) ?		'0 :
								( Send_MyID ) ?	R_MyID :
								( Send_ID_T ) ?	R_ID_T :
								( Send_ID_F ) ?	R_ID_F :
												W_FTk;


	assign O_SendID			= Send_MyID | Send_ID_T | Send_ID_F;

	assign W_FTk.v			= R_FTk.v;
	assign W_FTk.a			= R_FTk.a & ( is_IndirectMode | ~Bypass );
	assign W_FTk.c			= R_FTk.c;
	assign W_FTk.r			= R_FTk.r & ( is_IndirectMode | ~Bypass );
	assign W_FTk.d			= R_FTk.d;
	assign W_FTk.i			= R_FTk.i;

	assign O_Req_BackEnd	= R_Req_BackEnd;

	assign ConfigDec_FTk.v	= 1'b0;
	assign ConfigDec_FTk.a	= 1'b0;
	assign ConfigDec_FTk.r	= 1'b0;
	assign ConfigDec_FTk.c	= 1'b0;
	assign ConfigDec_FTk.d	= R_RConfig;
	assign ConfigDec_FTk.v	= '0;

	assign is_Acq			= acq_message | acq_flagmsg;
	assign is_Rls			= rls_message | rls_flagmsg;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stop			<= 1'b0;
		end
		else if ( ~is_Busy_BackEnd ) begin
			R_Stop			<= 1'b0;
		end
		else if ( is_Busy_BackEnd & is_Acq ) begin
			R_Stop			<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Req_BackEnd	<= 1'b0;
		end
		else begin
			R_Req_BackEnd	<= Start_Load;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_MyID			<= '0;
		end
		else if ( R_FTk.v & is_Acq & ~Busy ) begin
			R_MyID			<= R_FTk;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_ID_T			<= '0;
		end
		else if ( Busy & StoreIDs & ( Counter == 1 ) ) begin
			R_ID_T			<= R_FTk;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_ID_F			<= '0;
		end
		else if ( Busy & StoreIDs & ( Counter == 2 ) ) begin
			R_ID_F			<= R_FTk;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_StoreIDs		<= 1'b0;
		end
		else if ( R_Req_BackEnd ) begin
			R_End_StoreIDs		<= 1'b0;
		end
		else if ( End_StoreIDs ) begin
			R_End_StoreIDs		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_AttributeWord	<= '0;
		end
		else if ( Set_AttribWord & R_FTk.v ) begin
			R_AttributeWord	<= R_FTk.d;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RConfig		<= '0;
		end
		else if ( Set_RConfig & R_FTk.v ) begin
			R_RConfig		<= R_FTk.d;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Length		<= '0;
		end
		else if ( Set_Length & R_FTk.v ) begin
			R_Length		<= ( I_Shared & ~R_RConfig[WIDTH_DATA-1] ) ? I_Actual_Length : R_FTk.d;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stride		<= '0;
		end
		else if ( Set_Stride & R_FTk.v ) begin
			R_Stride		<= R_FTk.d[WIDTH_ADDR-1:0];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Base			<= '0;
		end
		else if ( Set_Base & R_FTk.v ) begin
			R_Base			<= R_FTk.d[WIDTH_ADDR-1:0];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_MetaData		<= '0;
		end
		else if ( Start_Load & ~I_Stall ) begin
			R_MetaData		<= { Start_Load, R_End_StoreIDs, is_Shared, is_DataWord | REConfig };
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Busy_BackEnd	<= 1'b0;
		end
		else begin
			R_is_Busy_BackEnd	<= is_Busy_BackEnd;
		end
	end


	TokenDec TokenDec_LdFrontEnd (
		.I_FTk(				R_FTk						),
		.O_acq_message(		acq_message					),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(		acq_flagmsg					),
		.O_rls_flagmsg(		rls_flagmsg					)
	);

	AttributeDec AttribDec_LdFrontEnd
	(
		.I_Data(			R_FTk.d						),
		.is_Pull(			is_PullReq					),
		.is_DataWord(		is_DataWord					),
		.is_RConfigData(	is_RConfigData				),
		.is_PConfigData(								),
		.is_RoutingData(								),
		.is_Shared(			is_Shared					),
		.is_NonZero(									),
		.is_Dense(										),
		.is_MyAttribute(	is_MyAttrib					),
		.is_Term_Block(		is_Term_Block				),
		.is_In_Cond(									),
		.O_Length(										)
	);

	ConfigDec_RAM #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) ConfigDec_RAM
	(
		.I_FTk(				ConfigDec_FTk				),
		.O_Share(										),
		.O_Decrement(		is_Descrement				),
		.O_Mode(			AccessMode					),
		.O_Indirect(		is_IndirectMode				),
		.O_Length(										),
		.O_Stride(										),
		.O_Base(										)
	);

    Ld_CTRL_FrontEnd Ld_CTRL_FrontEnd (
        .clock(				clock						),
        .reset(				reset						),
        .I_Boot(			I_Boot						),
        .I_Valid(			R_FTk.v						),
        .I_Stall(			I_Stall						),
        .is_Acq(			is_Acq						),
        .is_Rls(			is_Rls						),
        .is_Shared(			is_Shared					),
        .is_PullReq(		is_PullReq					),
        .is_MyAttrib(		is_MyAttrib | REConfig		),
        .is_RConfigData(	is_RConfigData				),
        .is_Term_Load(		is_Term_Load				),
        .is_Term_BTk(		is_Term_BTk					),
        .is_Matched(		is_Matched					),
        .is_IndirectMode(	is_IndirectMode				),
        .is_End_Rename(		is_End_Rename				),
        .is_Ack_BackEnd(	is_Ack_BackEnd				),
		.O_Set_Up(			Set_Up						),
        .O_StoreIDs(		StoreIDs					),
        .O_Set_AttribWord(	Set_AttribWord				),
		.O_Set_RConfig(		Set_RConfig					),
		.O_Set_Length(		Set_Length					),
		.O_Set_Stride(		Set_Stride					),
		.O_Set_Base(		Set_Base					),
        .O_Bypass(			Bypass						),
		.O_Start_Load(		Start_Load					),
        .O_Start_Rename(	Start_Rename				),
		.O_End_StoreIDs(	End_StoreIDs				),
		.O_Send_MyID(		Send_MyID					),
		.O_Send_ID_T(		Send_ID_T					),
		.O_Send_ID_F(		Send_ID_F					),
		.O_Counter(			Counter						),
		.O_Stall_In(		Stall_In					),
        .O_Busy(			Busy						)
    );

	DReg OutPutData (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_FTk						),
		.O_BTk(				R_BTk						),
		.O_FTk(				R_FTk						),
		.I_BTk(				W_BTk						)
	);

endmodule
