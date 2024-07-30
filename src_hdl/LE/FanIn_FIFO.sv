///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Router Control
//	Module Name:	FanIn_FIFO
//	Function:
//					FanIn Link Element Controller
//					Control storing in buffer and sending message
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanIn_FIFO
	import	pkg_en::*;
	import	pkg_link::*;
#(
	parameter int WIDTH_DATA			= 32,
	parameter int En					= 1
)(
	input							clock,
	input							reset,
	input	FTk_t					I_FTk,				//Forward Tokens
	output	BTk_t					O_BTk,				//Back-Prop Tokens
	output	FTk_t					O_FTk,				//Forward Tokens
	input	BTk_t					I_BTk,				//Back-Prop Tokens
	output	logic					O_Req,				//Request to get path
	output	logic					O_Trm,				//Termination
	input							I_Rls,				//Flag: Release
	input							I_Grt,				//Flag: Grant
	input	[WIDTH_DATA-1:0]		I_Next,				//Next-ID
	output	logic					O_WeId,				//Capture ID
	output	[WIDTH_DATA-1:0]		O_NextID_t,			//Next-ID True
	output	[WIDTH_DATA-1:0]		O_NextID_f,			//Next-ID False
	input	bit2_t					I_InC,				//Condition-Code Path
	output	logic					O_Cond,				//Condition-Code
	input							I_DirtyBit			//Flag: Already Used
);

	fsm_link_in					R_FSM;


	//// Logic Connect												////
	logic						acq_message;
	logic						rls_message;
	logic						acq_flagmsg;
	logic						rls_flagmsg;

	logic						Acq;
	logic						Rls_Mssg;
	logic						Rls_Path;

	logic						Match_MyID;
	logic						Match_MyID_Waited;
	logic						Check_MyID;

	logic						Re;
	logic						Stop;


	logic						Force_Term;
	logic						we_id;

	logic						Cond_Valid;
	logic						Cond_LinkIn;

	logic						Transit;
	logic						W_Acq;
	FTk_t						W_FTk;

	logic						is_Wait;

	logic						is_iD_INIT_IN;
	logic						is_rEAD_MY_ID_IN;
	logic						is_rEAD_T_ID_IN;
	logic						is_rEAD_F_ID_IN;
	logic						is_oUT_FIFO2_IN;
	logic						is_oUT_FIFO1_IN;
	logic						is_oUT_FIFO0_IN;


	//// Capture Signal												////
	logic						R_Matched;
	logic						R_Acq;
	logic						R_Rls;

	logic						R_Nack;

	FTk_t						FIFO_0_O_FTk;
	FTk_t						FIFO_1_O_FTk;
	FTk_t						FIFO_2_O_FTk;
	BTk_t						FIFO_2_O_BTk;


	//// State Decode												////
	assign is_iD_INIT_IN	= R_FSM == iD_INIT_IN;
	assign is_rEAD_MY_ID_IN	= R_FSM == rEAD_MY_ID_IN;
	assign is_rEAD_T_ID_IN	= R_FSM == rEAD_T_ID_IN;
	assign is_rEAD_F_ID_IN	= R_FSM == rEAD_F_ID_IN;
	assign is_oUT_FIFO2_IN	= R_FSM == oUT_FIFO2_IN;
	assign is_oUT_FIFO1_IN	= R_FSM == oUT_FIFO1_IN;
	assign is_oUT_FIFO0_IN	= R_FSM == oUT_FIFO0_IN;


	//// State Transit Validation									////
	assign Transit			= I_FTk.v;


	//// Check ID Match												////
	//	 Check Event
	assign Check_MyID		= ( is_iD_INIT_IN | I_Rls | ( FIFO_0_O_FTk.a & FIFO_0_O_FTk.r ) ) & W_Acq;

	//	 Common Match-Check
	assign Match_MyID		= Check_MyID & ( ~I_DirtyBit | (( I_FTk.d == I_Next ) & I_FTk.v ) | (( FIFO_0_O_FTk.d == I_Next ) & I_Rls ) );

	//	 Match-Check for Overlapping
	assign Match_MyID_Waited= is_Wait & ( FIFO_0_O_FTk.d == I_Next );


	//// Terimnation												////
	assign Force_Term		= W_Acq & ~R_Matched & is_rEAD_T_ID_IN;


	//// Write Enable for NextIDs									////
	assign we_id			= ( is_rEAD_F_ID_IN & ~R_Nack ) & I_Grt;
	assign O_WeId			= we_id;


	//// Condition Token Handling									////
	assign O_Cond			= Cond_Valid & Cond_LinkIn;


	//// Buffer Body												////
	assign Stop				= ( Acq & is_iD_INIT_IN ) | is_rEAD_MY_ID_IN | is_rEAD_T_ID_IN;
	assign Re				= Stop | ( I_Grt & ( R_FSM >= rEAD_F_ID_IN) );

	assign W_FTk			= ( R_Rls & ~Acq ) ? '0 : I_FTk;

	//// Token Detection											////
	assign Acq				= acq_message | acq_flagmsg;
	assign W_Acq			= Acq | R_Acq;

	assign Rls_Mssg			= rls_flagmsg;
	assign Rls_Path			= rls_message;


	//// Wait State													////
	assign is_Wait			= ( R_Acq | R_Matched ) & ~I_Grt & ( R_FSM >= rEAD_T_ID_IN );


	//// Output														////
	assign O_Req			= Match_MyID | R_Matched;

	//	 Message-Release
	assign O_Trm			= FIFO_0_O_FTk.v & FIFO_0_O_FTk.a & FIFO_0_O_FTk.r & Re;

	assign O_NextID_t	 	= FIFO_1_O_FTk.d;
	assign O_NextID_f	 	= FIFO_2_O_FTk.d;

	if ( En == 1 ) begin: g_retimed	//Case of Retimed
		assign O_FTk	= ( Re ) ?	FIFO_0_O_FTk : '0;

		assign O_BTk.n	= FIFO_2_O_BTk.n | I_BTk.n | is_Wait;
		assign O_BTk.t	= FIFO_2_O_BTk.t;
		assign O_BTk.c	= FIFO_2_O_BTk.c;
		assign O_BTk.v	= FIFO_2_O_BTk.v;
	end
	else begin: g_no_retimed		//Case of Non-Retimed
		assign O_FTk	= ( is_oUT_FIFO0_IN ) ?	I_FTk : FIFO_0_O_FTk;

		assign O_BTk.n	= ( is_oUT_FIFO0_IN ) ?	I_BTk.n : FIFO_2_O_BTk.n;
		assign O_BTk.t	= ( is_oUT_FIFO0_IN ) ?	I_BTk.t : FIFO_2_O_BTk.t | Force_Term;
		assign O_BTk.v	= ( is_oUT_FIFO0_IN ) ?	I_BTk.v : FIFO_2_O_BTk.v;
		assign O_BTk.c	= ( is_oUT_FIFO0_IN ) ?	I_BTk.c : FIFO_2_O_BTk.c;
	end


	//// Capture Nack Token											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Nack		<= 1'b0;
		end
		else begin
			R_Nack		<= I_BTk.n;
		end
	end


	//// Capture Acq Token											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Acq			<= 1'b0;
		end
		else if ( I_Grt | Rls_Mssg | Rls_Path ) begin
			R_Acq			<= 1'b0;
		end
		else if ( Acq ) begin
			R_Acq			<= 1'b1;
		end
	end


	//// Capture Release Token										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rls	<= 1'b0;
		end
		else if ( R_FSM	== iD_INIT_IN ) begin
			R_Rls	<= 1'b0;
		end
		else if ( I_FTk.v & I_FTk.a & I_FTk.r ) begin
			R_Rls	<= 1'b1;
		end
	end


	LECondUnit LECondUnit (
		.clock(				clock						),
		.reset(				reset						),
		.I_Clr(				W_Acq						),
		.I_InC(				I_InC						),
		.O_Valid(			Cond_Valid					),
		.O_Cond(			Cond_LinkIn					)
	);

	FanIn_Buff #(
		.DEPTH_FIFO(		DEPTH_L_FIFO				)
	) FanIn_Buff
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				W_FTk						),
		.O_BTk(				FIFO_2_O_BTk				),
		.O_FTk0(			FIFO_0_O_FTk				),
		.O_FTk1(			FIFO_1_O_FTk				),
		.O_FTk2(			FIFO_2_O_FTk				),
		.I_BTk(				I_BTk						),
		.I_En(				Re							),
		.I_Stop(			Stop						),
		.O_Empty(										),
		.O_Full(										)
	);

	TokenDec TokenDec (
		.I_FTk(				I_FTk						),
		.O_acq_message(		acq_message					),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(		acq_flagmsg					),
		.O_rls_flagmsg(		rls_flagmsg					)
	);


	//// FIFO Control												////
	always_ff @( posedge clock ) begin: ff_fsm_fifo_in
		if ( reset ) begin
			R_FSM		<= iD_INIT_IN;
			R_Matched	<= 1'b0;
		end
		else case ( R_FSM )
			iD_INIT_IN: begin
				if ( Acq ) begin
					R_FSM		<= rEAD_MY_ID_IN;
					R_Matched	<= Match_MyID;
				end
				else begin
					R_FSM		<= iD_INIT_IN;
					R_Matched	<= 1'b0;
				end
			end
			rEAD_MY_ID_IN: begin
				if ( Rls_Path ) begin
					R_FSM		<= iD_INIT_IN;
					R_Matched	<= R_Matched;
				end
				else if ( ~I_BTk.n ) begin
					R_FSM		<= rEAD_T_ID_IN;
					R_Matched	<= R_Matched;
				end
			end
			rEAD_T_ID_IN: begin
				if ( R_Matched ) begin
					R_FSM	<= rEAD_F_ID_IN;
				end
				else if ( Rls_Path ) begin
					R_FSM		<= iD_INIT_IN;
					R_Matched	<= 1'b0;
				end

				else if ( ~I_BTk.n ) begin
					R_FSM		<= rEAD_F_ID_IN;
					R_Matched	<= R_Matched;
				end
			end
			rEAD_F_ID_IN: begin
				if ( ~I_BTk.n & I_Grt ) begin
					R_FSM		<= oUT_FIFO2_IN;
					R_Matched	<= R_Matched;
				end
				else if ( I_Rls ) begin
					R_FSM		<= oUT_FIFO2_IN;
					R_Matched	<= Match_MyID;
				end
				else begin
					R_FSM		<= rEAD_F_ID_IN;
					R_Matched	<= R_Matched | Match_MyID_Waited;
				end
			end
			oUT_FIFO2_IN: begin
				if ( ~I_BTk.n & I_Grt ) begin
					R_FSM		<= oUT_FIFO1_IN;
					R_Matched	<= R_Matched;
				end
			end
			oUT_FIFO1_IN: begin
				if ( ~I_BTk.n & I_Grt ) begin
					R_FSM		<= oUT_FIFO0_IN;
					R_Matched	<= R_Matched;
				end
			end
			oUT_FIFO0_IN: begin
				if ( W_Acq ) begin
					R_FSM		<= rEAD_MY_ID_IN;
					R_Matched	<= Match_MyID;
				end
				else if ( ~I_BTk.n & FIFO_0_O_FTk.a & FIFO_0_O_FTk.r ) begin
					R_FSM		<= iD_INIT_IN;
					R_Matched	<= 1'b0;
				end
			end
			default: begin
				R_FSM		<= iD_INIT_IN;
				R_Matched	<= 1'b0;
			end
		endcase
	end

endmodule
