///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Interface Controller
//	Module Name:	IFCTRL
//	Function:
//					Receives request to connect among external-memory, global buffer, and iflogic.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IFCTRL
	import pkg_en::WIDTH_DATA;
	import pkg_en::FTk_t;
	import pkg_bram_if::*;
(
	input						clock,
	input						reset,
	input	FTk_t				I_FTk,								//From FanIn Tree
	output	FTk_t				O_FTk,								//To Reanme Unit
	output	FTk_t				O_RCFG,								//To BRAM (Configuration Data)
	input						I_Stall,							//Stall
	input						I_Done,								//Flag: Done
	output	logic				O_Req,								//Request to Rename Unit
	output	logic				O_Busy,								//Flag: State in Busy
	input						I_St_Done,							//Flag: Store at Externam Memory is Done
	input						I_Rls								//Flag: Release
);

	//	 Tokens
	logic						acq_message;
	logic						acq_flagmsg;
	logic						rls_message;
	logic						rls_flagmsg;

	logic						is_Acq;
	logic						is_Rls;

	//	 Attribute Detection
	logic						is_RConfigData;
	logic						is_RoutingData;


	//// Caputure Signal											////
	//	 Control Finite State Machine
	fsm_ifctrl					FSM_Req;

	//	 Instrucction
	FTk_t						Instruction;

	//	 Configuration Data for BRAM
	FTk_t						Configuration;

	//	 State
	logic						R_Run;

	//	 Req
	logic						R_Req;

	//	 Lock-Flag
	logic						R_Lock;



	//// Output														////
	assign O_FTk			= Instruction;
	assign O_RCFG			= Configuration;
	assign O_Req			= R_Req;
	assign O_Busy			= IFCTRL_INIT != FSM_Req;

	//	 Tokens
	assign is_Acq			= acq_message | acq_flagmsg;
	assign is_Rls			= rls_message | rls_flagmsg;


	//// State in Run												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Run			<= 1'b0;
		end
		else begin
			R_Run			<= IFCTRL_RUN == FSM_Req;
		end
	end


	//// Request to Rename Unit										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Req			<= 1'b0;
		end
		else begin
			R_Req			<= ~R_Run & (( is_Rls & ( IFCTRL_ROUTE == FSM_Req ) ) | ( IFCTRL_RUN == FSM_Req ));
		end
	end


	//// Capture Routing Data										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Instruction		<= '0;
		end
		else if (( IFCTRL_ROUTE == FSM_Req ) & I_FTk.v ) begin
			Instruction		<= I_FTk;
		end
		else if ( I_Rls & ~I_Stall ) begin
			Instruction		<= '0;
		end
		else if ( I_St_Done & ~I_Stall ) begin
			Instruction		<= '0;
		end
	end


	//// Capture Configuration Data									////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Configuration	<= '0;
		end
		else if ( ( IFCTRL_RCFG == FSM_Req ) & I_FTk.v & ~I_Stall ) begin
			Configuration	<= I_FTk;
		end
	end


	//// Request Control FSM										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			FSM_Req	<= IFCTRL_INIT;
		end
		else case ( FSM_Req )
			IFCTRL_INIT: begin
				if ( is_Acq ) begin
					FSM_Req		<= IFCTRL_ID_T;
				end
				else begin
					FSM_Req		<= IFCTRL_INIT;
				end
			end
			IFCTRL_ID_T: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else if ( I_FTk.v ) begin
					FSM_Req		<= IFCTRL_ID_F;
				end
			end
			IFCTRL_ID_F: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else if ( I_FTk.v ) begin
					FSM_Req		<= IFCTRL_ATTRIB;
				end
			end
			IFCTRL_ATTRIB: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else if ( I_FTk.v & ~I_Stall & is_RoutingData ) begin
					FSM_Req		<= IFCTRL_ROUTE;
				end
				else if ( I_FTk.v & ~I_Stall & is_RConfigData ) begin
					FSM_Req		<= IFCTRL_RCFG;
				end
			end
			IFCTRL_ROUTE: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_RUN;
				end
				else if ( I_FTk.v & ~I_Stall ) begin
					FSM_Req		<= IFCTRL_RATRIB;
				end
			end
			IFCTRL_RATRIB: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else if ( I_FTk.v & ~I_Stall ) begin
					FSM_Req		<= IFCTRL_RCFG;
				end
			end
			IFCTRL_RCFG: begin
				if ( is_Rls ) begin
					FSM_Req		<= IFCTRL_RUN;
				end
			end
			IFCTRL_RUN: begin
				if ( I_Done ) begin
					FSM_Req		<= IFCTRL_INIT;
				end
				else begin
					FSM_Req		<= IFCTRL_RUN;
				end
			end
			default begin
				FSM_Req		<= IFCTRL_INIT;
			end
		endcase
	end

	TokenDec TokenDec (
		.I_FTk(				I_FTk						),
		.O_acq_message(		acq_message					),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(		acq_flagmsg					),
		.O_rls_flagmsg(		rls_flagmsg					)
	);

	AttributeDec AttribDec (
		.I_Data(			I_FTk.d						),
		.is_Pull(										),
		.is_DataWord(									),
		.is_RConfigData(	is_RConfigData				),
		.is_PConfigData(								),
		.is_RoutingData(	is_RoutingData				),
		.is_Shared(										),
		.is_NonZero(									),
		.is_Dense(										),
		.is_MyAttribute(								),
		.is_Term_Block(									),
		.is_In_Cond(									),
		.O_Length(										)
	);

endmodule