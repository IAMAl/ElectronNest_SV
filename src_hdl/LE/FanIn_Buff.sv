///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Buffer for Link-Element
//		Module Name:	FanIn_Buff
//		Function:
//						Buffer for Storing Header Words
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanIn_Buff
	import	pkg_en::*;
#(
	parameter int DEPTH_FIFO		= 4
)(
	input							clock,
	input							reset,
	input	FTk_t					I_FTk,				//Data
	output	BTk_t					O_BTk,				//Back-Prop Token
	output	FTk_t					O_FTk0,				//Data
	output	FTk_t					O_FTk1,				//Data
	output	FTk_t					O_FTk2,				//Data
	input	BTk_t					I_BTk,				//Back-Prop Token
	input							I_En,				//Enable to Buffer
	input							I_Stop,				//Buffer Data
	output	logic					O_Full,				//Flag: Full in Buffer
	output	logic					O_Empty				//Flag: Empty in Buffer
);

	logic [$clog2(DEPTH_L_FIFO):0]	R_FSM;


	//// Logic Connect												////
	logic						We	[DEPTH_FIFO:0];
	logic						Clr	[DEPTH_FIFO:0];
	logic						Stop;
	logic						Stay;
	logic						Up;
	logic						Down;
	logic						Empty;
	logic						Full;

	logic						ChkPulseN;
	logic						ChkPulse;


	//// Capture Signal												////
	logic						R_Full;
	FTk_l_t						R_FIFO;
	FTk_d1_t					OutFIFO;

	FTk_t						PATH_FTk0;
	FTk_t						PATH_FTk1;
	FTk_t						PATH_FTk2;

	BTk_t						R_BTk;
	BTk_t						R_NackD2;


	//// Buffer Control												////
	//
	assign Up				= I_En & I_FTk.v & ( ChkPulse | I_BTk.n | R_BTk.n ) & ~R_Full;

	//	 Buffering by Nack token or Some Request (I_Stop)
	assign Stop				= I_Stop | Up;

	//	 Consume Buffer
	assign Down				= I_En & ~I_FTk.v & ( ~( I_BTk.n | R_BTk.n ) & ~Empty );

	//	 Keep Current Buffer Depth
	assign Stay				= I_BTk.n | R_BTk.n | ( I_Stop & ~I_FTk.v );


	//// Output														////
	//	 Forward Tokens
	assign OutFIFO[0]		= I_FTk;
	for ( genvar i = 1; i <= DEPTH_FIFO; ++i ) begin
		assign OutFIFO[ i ]	= R_FIFO[ i - 1 ];
	end
	assign PATH_FTk0		= OutFIFO[ R_FSM ];
	assign PATH_FTk1		= ( R_FSM > '0 ) ?  OutFIFO[ R_FSM - 2'b01 ] : '0;
	assign PATH_FTk2		= ( R_FSM >  1 ) ?  OutFIFO[ R_FSM - 2'b10 ] : '0;
	assign O_FTk0			= ( I_Stop | ChkPulse | (( ~I_FTk.v & Empty ) | I_BTk.n | R_BTk.n ) & ~ChkPulse ) ? '0 : PATH_FTk0;
	assign O_FTk1			= ( I_Stop | ChkPulse | (( ~I_FTk.v & Empty ) | I_BTk.n | R_BTk.n ) & ~ChkPulse ) ? '0 : PATH_FTk1;
	assign O_FTk2			= ( I_Stop | ChkPulse | (( ~I_FTk.v & Empty ) | I_BTk.n | R_BTk.n ) & ~ChkPulse ) ? '0 : PATH_FTk2;

	//	 Backward Tokens
	assign O_BTk.n			= R_Full | Full;
	assign O_BTk.t			= R_BTk.t;
	assign O_BTk.v			= R_BTk.v;
	assign O_BTk.c			= R_BTk.c;


	//// Buffer Status Flags										////
	assign Empty			= ( R_FSM == '0 );
	assign O_Empty			= Empty;

	assign Full				= ( R_FSM >= ( DEPTH_FIFO-1 ));
	assign O_Full			= Full;


	//// Nack Token													////
	//	 Pulse-Nack Detection
	assign ChkPulseN		= ~I_BTk.n & R_BTk.n & ~R_NackD2;
	assign ChkPulse			= ChkPulseN;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_BTk			<= '0;
			R_NackD2		<= 1'b0;
		end
		else begin
			R_BTk			<= I_BTk;
			R_NackD2		<= R_BTk.n;
		end
	end


	//// Buffer Full State Detection								////
	//	 Continues Output by DEPTH_FIFO/4 after Full-state
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Full			<= 1'b0;
		end
		else if ( ~I_En | ( R_FSM < 5 )) begin
			R_Full			<= 1'b0;
		end
		else if ( Full ) begin
			R_Full			<= 1'b1;
		end
	end


	//// Depth Control												////
	always_ff @( posedge clock ) begin: ff_depth
		if ( reset ) begin
			R_FSM			<= '0;
		end
		else if ( Stop & ( R_FSM < DEPTH_FIFO )) begin
			R_FSM	 		<= R_FSM + 1'b1;
		end
		else if ( Stay ) begin
			R_FSM			<= R_FSM;
		end
		else if ( Down ) begin
			if ( R_FSM > 0 ) begin
				R_FSM	 	<= R_FSM - 1'b1;
			end
			else begin
				R_FSM	 	<= '0;
			end
		end
		else if ( I_FTk.v ) begin
			R_FSM			<= R_FSM;
		end
		else if ( I_BTk.t ) begin
			R_FSM			<= '0;
		end
	end


	//// Storing/Clearing Buffer Control							////
	always_comb begin : c_buff_ctrl
		for ( int i = 0; i <= DEPTH_FIFO; ++i ) begin
			We[ i ]			= ( Stop & I_FTk.v & ( R_FSM <= DEPTH_FIFO ) & ( i <= R_FSM ) & I_En ) |
								(( ~Stop & I_FTk.v & ( ~Down | Stay ) & ( i < R_FSM )) & I_En & ~R_Full );
			Clr[ i ]		= ( Down & ~Stay & ( R_FSM > '0 ) & ( '0 < R_FSM ) & ( i < R_FSM ) & ( i == ( R_FSM - 1 )) & ~I_Stop );
		end
	end


	//// Buffer Body												////
	always_ff @( posedge clock ) begin: ff_fifo
		if ( reset ) begin
			for ( int i=0; i<DEPTH_FIFO; ++i ) begin
				R_FIFO[ i ]	<= '0;
			end
		end
		else begin
			if ( Clr[0] ) begin
				R_FIFO[0]	<= 0;
			end
			else if ( We[0] ) begin
				R_FIFO[0]	<= I_FTk;
			end
			else begin
				R_FIFO[0]	<= R_FIFO[0];
			end

			for ( int entry_no = 1; entry_no < DEPTH_FIFO; ++ entry_no ) begin
				if ( Clr[ entry_no ] ) begin
					R_FIFO[ entry_no ]	<= 0;
				end
				else if ( We[ entry_no ] ) begin
					R_FIFO[ entry_no ]	<= R_FIFO[ entry_no - 1 ];
				end
				else begin
					R_FIFO[ entry_no ] <= R_FIFO[ entry_no ];
				end
			end
		end
	end

endmodule