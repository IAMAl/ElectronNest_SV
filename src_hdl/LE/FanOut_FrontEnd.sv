///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Router Control
//	Module Name:	FanOut_FrontEnd
//	Function:
//					FanOut Link Element Controller (FrontEnd)
//					Control service for sending
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanOut_FrontEnd
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
	output	logic					O_Req,				//Req to BackEnd
	input							I_Ack,				//Ack from BacdkEnd
	input							I_Full_Buff,		//Flag: Full in Buffer
	output	logic					O_We_BUFF_ID,		//Write-Enable for ID Buffer
	output	logic					O_We_BUFF,			//Write-Enable for Buffer
	output	logic					O_Unit_Length,		//Flag: Unit Length for Route
	output	[WIDTH_DATA-1:0]		O_PATH0,			//Path-0 Info
	output	[WIDTH_DATA-1:0]		O_PATH1,			//Path-1 Info
	input							is_Busy,			//Flag: State in Busy at Back-ENd
	output							O_NWe,				//Disable Writing Buffer
	input	bit2_t					I_InC,				//Condition-Code Path
	output	bit2_t					O_InC				//Condition-Code Path
);


	//// Connect Logic												////
	logic						is_Init;
	logic						is_StoreIDs;
	logic						is_AttribWord;
	logic						is_RoutingData;
	logic						is_Wait;

	logic						acq_message;
	logic						rls_message;
	logic						acq_flagmsg;
	logic						rls_flagmsg;

	logic						Valid;
	logic						is_Acq;
	logic						is_Rls;

	logic						End_StoreIDs;
	logic						End_Send;

	FTk_t						W_FTk;
	BTk_t						W_BTk;

	FTk_t						New_AttribWord;

	logic						Set_Path;
	logic						is_Long_Path;
	logic	[8-1:0]				New_Path_Length;

	logic						is_Descrement;

	logic						Busy;


	//// Capture Signal												////
	fsm_link_out_frontend		R_FSM;

	logic						R_Req;
	logic						R_is_Rls;

	logic						R_Full;

	logic	[WIDTH_DATA-1:0]	PATH	[1:0];

	logic	[1:0]				R_Cnt;
	logic	[1:0]				R_Cnt_AW;

	logic						R_No;

	logic						R_Stop;

	logic						R_is_AttribWord;
	logic						R_is_RoutingData;
	logic						R_is_Long_Path;
	logic						R_Check_Length;


	assign Valid			= I_FTk.v;

	assign is_Init			= ( R_FSM == lINKFORNTEND_INIT );
	assign is_StoreIDs		= ( R_FSM == lINKFRONTEND_ST_ID );
	assign is_AttribWord	= ( R_FSM == lINKFRONTEND_SEND_ID );
	assign is_RoutingData	= ( R_FSM == lINKFRONTEND_RUN );
	assign is_Wait			= ( R_FSM == lINKFRONTEND_TERM );

	assign is_Long_Path		= is_AttribWord & Valid & ( I_FTk.d[15:8] != '0 );
	assign New_Path_Length	= I_FTk.d[15:8] - 1'b1;

	assign New_AttribWord.v	= I_FTk.v;
	assign New_AttribWord.a	= I_FTk.a;
	assign New_AttribWord.c	= I_FTk.c;
	assign New_AttribWord.r	= I_FTk.r;
	assign New_AttribWord.d	= { I_FTk.d[WIDTH_DATA-1:16], New_Path_Length, I_FTk.d[8-1:0] };
	assign New_AttribWord.i	= I_FTk.i;

	assign End_StoreIDs		= ( R_Cnt == 2'h2 ) & Valid;

	assign Set_Path			= is_RoutingData & Valid & ~is_Busy;

	assign O_Req			= Set_Path | R_Req;
	assign O_We_BUFF_ID		= ( R_Cnt != '0 );
	assign O_We_BUFF		= R_is_AttribWord | ( R_is_RoutingData & ~I_Ack );

	assign O_Unit_Length	= ~R_is_Long_Path & R_Check_Length;

	assign O_PATH0			= PATH[0];
	assign O_PATH1			= PATH[1];

	assign O_InC			= I_InC;

	assign W_FTk			= ( ( is_Acq | is_StoreIDs ) & ( R_Cnt < 2'h3 ) ) ?	I_FTk :
								( is_AttribWord & is_Long_Path ) ?				New_AttribWord :
								( is_RoutingData & R_is_Long_Path ) ?			I_FTk :
																				'0;

	BTk_t						H_BTk;
	assign H_BTk			= ( ( is_Acq | is_StoreIDs ) & ( R_Cnt < 2'h3 ) ) ? '0 : I_BTk;


	assign is_Acq			= acq_message | acq_flagmsg;
	assign is_Rls			= rls_message | rls_flagmsg;

	assign End_Send			= O_FTk.v & O_FTk.a & O_FTk.r & ~R_Full;

	assign O_NWe			= R_is_Rls;

	assign O_BTk.n			= ( is_Init ) ? I_BTk.n | R_is_AttribWord | R_is_RoutingData : R_Full | R_Stop | R_is_AttribWord | R_is_RoutingData;
	assign O_BTk.t			= ( is_Init ) ? I_BTk.t : W_BTk.t;
	assign O_BTk.v			= ( is_Init ) ? I_BTk.v : W_BTk.v;
	assign O_BTk.c			= ( is_Init ) ? I_BTk.c : W_BTk.c;


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Rls		<= 1'b0;
		end
		else if ( ~is_Busy | ( R_FSM > 3'h2 )) begin
			R_is_Rls		<= 1'b0;
		end
		else if ( is_Rls & is_Busy ) begin
			R_is_Rls		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cnt			<= '0;
		end
		else if ( ( is_StoreIDs | is_AttribWord ) & Valid ) begin
			R_Cnt			<= R_Cnt + 1'b1;
		end
		else if ( is_Init & is_Acq ) begin
			R_Cnt			<= 1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cnt_AW		<= '0;
		end
		else if ( O_Req ) begin
			R_Cnt_AW		<= '0;
		end
		else if ( Valid & ( R_FSM > 1 ) & ( R_FSM < 4 ) ) begin
			R_Cnt_AW		<= R_Cnt_AW + 1'b1;
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
			R_Req			<= 1'b0;
		end
		else if ( I_Ack ) begin
			R_Req			<= 1'b0;
		end
		else if ( Set_Path ) begin
			R_Req			<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_No			<= 1'b0;
		end
		else if ( Set_Path ) begin
			R_No			<= ~R_No;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			PATH[0]			<= '0;
			PATH[1]			<= '0;
		end
		else if ( Set_Path ) begin
			PATH[ R_No ]	<= I_FTk.d;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_AttribWord	<= 1'b0;
		end
		else if ( End_Send ) begin
			R_is_AttribWord	<= 1'b0;
		end
		else if ( is_RoutingData & R_is_Long_Path ) begin
			R_is_AttribWord	<= 1'b0;
		end
		else if ( is_AttribWord & is_Long_Path ) begin
			R_is_AttribWord	<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Check_Length	<= 1'b0;
		end
		else if ( I_FTk.v ) begin
			R_Check_Length	<= is_AttribWord;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_RoutingData<= 1'b0;
		end
		else if ( R_is_RoutingData & R_is_Long_Path ) begin
			R_is_RoutingData	<= 1'b0;
		end
		else if ( R_is_AttribWord & is_RoutingData ) begin
			R_is_RoutingData<= 1'b1;
		end
		else if ( I_Ack & ~R_is_AttribWord ) begin
			R_is_RoutingData<= 1'b0;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Long_Path	<= 1'b0;
		end
		else if ( is_Long_Path ) begin
			R_is_Long_Path	<= 1'b1;
		end
		else if ( R_is_RoutingData ) begin
			R_is_Long_Path	<= 1'b0;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stop			<= 1'b0;
		end
		else if ( I_Ack ) begin
			R_Stop			<= 1'b0;
		end
		else if ( Set_Path ) begin
			R_Stop			<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FSM			<= lINKFORNTEND_INIT;
		end
		else case ( R_FSM )
			lINKFORNTEND_INIT: begin
				if ( is_Acq ) begin
					R_FSM			<= lINKFRONTEND_ST_ID;
				end
				else begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
			end
			lINKFRONTEND_ST_ID: begin
				if ( End_StoreIDs ) begin
					R_FSM			<= lINKFRONTEND_SEND_ID;
				end
				else begin
					R_FSM			<= lINKFRONTEND_ST_ID;
				end
			end
			lINKFRONTEND_SEND_ID: begin
				if ( End_Send ) begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
				else if ( Valid & ~R_Full ) begin
					R_FSM			<= lINKFRONTEND_RUN;
				end
				else begin
					R_FSM			<= lINKFRONTEND_SEND_ID;
				end
			end
			lINKFRONTEND_RUN: begin
				if ( End_Send ) begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
				else if ( I_Ack ) begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
				else if ( Valid & ~R_Full ) begin
					R_FSM			<= lINKFRONTEND_TERM;
				end
				else begin
					R_FSM			<= lINKFRONTEND_RUN;
				end
			end
			lINKFRONTEND_TERM: begin
				if ( End_Send ) begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
				else if ( I_Ack ) begin
					R_FSM			<= lINKFORNTEND_INIT;
				end
				else begin
					R_FSM			<= lINKFRONTEND_TERM;
				end
			end
			default: begin
				R_FSM			<= lINKFORNTEND_INIT;
			end
		endcase
	end

	TokenDec TokenDec
	(
		.I_FTk(				I_FTk						),
		.O_acq_message(		acq_message					),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(		acq_flagmsg					),
		.O_rls_flagmsg(		rls_flagmsg					)
	);

	DReg DReg
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				W_FTk						),
		.I_BTk(				H_BTk						),
		.O_FTk(				O_FTk						),
		.O_BTk(				W_BTk						)
	);

endmodule