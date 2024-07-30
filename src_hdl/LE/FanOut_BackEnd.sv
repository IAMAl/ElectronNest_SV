///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Router Control
//	Module Name:	FanOut_BackEnd
//	Function:
//					FanOut Link Element Controller (BackRnd)
//					Control sending message
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanOut_BackEnd
	import	pkg_en::*;
	import	pkg_link::*;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input	FTk_t					I_FTk,				//Forward Tokens
	output	BTk_t					O_BTk,				//Back-Prop Tokens
	output	FTk_t					O_FTk,				//Forward Tokens
	input	BTk_t					I_BTk,				//Back-prop Tokens
	input							I_Req,				//Req from FrontEnd
	output	logic					O_Ack,				//Ack to FrontEnd
	input							I_Unit_Length,		//Flag: Unit-Length Block
	input							I_Full_Buff,		//Flag: Full in Buff
	output	logic					O_Re_BUFF_ID,		//Read-Enable for ID Buff
	output	logic					O_We_BUFF,			//Write-Enable for Buff
	output	logic					O_Re_BUFF,			//Read-Enable for Buff
	input	[WIDTH_DATA-1:0]		I_PATH0,			//Path-0
	input	[WIDTH_DATA-1:0]		I_PATH1,			//Path-1
	output	[WIDTH_DATA-1:0]		O_PATH,				//Grant
	output	logic					O_is_Busy,			//Flag: State i Busy
	output	bit2_t					O_InC				//Condition-Code Path
);


	//// Connect Logic												////
	logic						is_Init;
	logic						is_LoadIDs;
	logic						is_Send;

	logic						rls_message;
	logic						rls_flagmsg;
	logic						is_Rls;

	logic						Out_Valid;
	logic						End_SendIDs;

	logic						W_Ack;
	logic						End_Send;


	//// Capture Signal												////
	fsm_link_out_backend		R_FSM;

	logic						R_is_Rls;

	logic	[1:0]				R_Cnt;

	logic						R_No;

	logic						R_Full;

	logic						R_Nack;


	assign O_InC			= 0;

	assign is_Init			= ( R_FSM == lINKBACKEND_INIT );
	assign is_LoadIDs		= ( R_FSM == lINKBACKEND_SEND_ID );
	assign is_Send			= ( R_FSM == lINKBACKEND_RUN );

	assign W_Ack			= is_Init & I_Req;
	assign is_Rls			= rls_flagmsg | rls_message;

	assign Out_Valid		= I_FTk.v;
	assign End_SendIDs		= ( R_Cnt == 2 ) & I_FTk.v;

	assign End_Send			= is_Rls & ~R_Nack;

	assign O_Re_BUFF_ID		= is_LoadIDs & ~R_Nack;

	assign O_We_BUFF		= ( I_Req | is_LoadIDs | is_Send ) & ~( R_is_Rls | is_Rls ) & ~R_Full;
	assign O_Re_BUFF		= is_Send & ~R_Nack;

	assign O_Ack			= W_Ack;

	assign O_FTk			= ( is_LoadIDs ) ?	I_FTk :
								( is_Send ) ?	I_FTk :
												'0;

	assign O_BTk			= ( is_LoadIDs ) ?	I_BTk :
								( is_Send ) ?	I_BTk :
												'0;

	assign O_PATH			= ( R_No == 1'b0 ) ?	I_PATH0 :
													I_PATH1;

	assign O_is_Busy		= ( R_FSM != 2'h0 ) & ~End_Send;


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Rls		<= 1'b0;
		end
		else if ( R_FSM == 2'h0 ) begin
			R_is_Rls		<= 1'b0;
		end
		else if ( is_Rls & ~I_Req ) begin
			R_is_Rls		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Nack			<= 1'b0;
		end
		else begin
			R_Nack			<= I_BTk.n;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Full			<= 1'b0;
		end
		else begin
			R_Full			<= I_Full_Buff;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cnt			<= '0;
		end
		else if ( End_SendIDs ) begin
			R_Cnt			<= '0;
		end
		else if ( Out_Valid & is_LoadIDs ) begin
			R_Cnt			<= R_Cnt + 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_No			<= 1'b0;
		end
		else if ( End_Send ) begin
			R_No			<= ~R_No;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FSM			<= lINKBACKEND_INIT;
		end
		else case ( R_FSM )
			lINKBACKEND_INIT: begin
				if ( I_Req ) begin
					R_FSM			<= lINKBACKEND_SEND_ID;
				end
				else begin
					R_FSM			<= lINKBACKEND_INIT;
				end
			end
			lINKBACKEND_SEND_ID: begin
				if ( End_SendIDs ) begin
					R_FSM			<= lINKBACKEND_RUN;
				end
				else begin
					R_FSM			<= lINKBACKEND_SEND_ID;
				end
			end
			lINKBACKEND_RUN: begin
				if ( End_Send ) begin
					R_FSM			<= lINKBACKEND_INIT;
				end
				else begin
					R_FSM			<= lINKBACKEND_RUN;
				end
			end
			default: begin
				R_FSM			<= lINKBACKEND_INIT;
			end
		endcase
	end

	TokenDec TokenDec (
		.I_FTk(				I_FTk						),
		.O_acq_message(									),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(									),
		.O_rls_flagmsg(		rls_flagmsg					)
	);

endmodule