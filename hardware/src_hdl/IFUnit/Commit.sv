///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Global Commit Unit
//	Module Name:	Commit
//	Function:
//					Commit Unit to Complete Instructions
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Commit
	import pkg_bram_if::*;
(
	input							clock,
	input							reset,
	input							I_Req,				//Request from Port-Map
	input	PortPSrcID_t			I_SrcPort,			//Source Port-ID from Port-Map
	input	[NUM_UNITS-1:0]			I_Commit,			//Release (Commit) Signals from Port-Map
	output	logic					O_Req,				//Commit-Request to Rename Unit
	output	[NUM_UNITS-1:0]			O_Ack,				//Ack to Port-Map unit (Clearing Map-Table)
	output	[NUM_UNITS-1:0]			O_Commit,			//Commit Signal to Rename Unit
	output	logic					O_Full,				//Flag: Full
	output	logic					O_Empty,			//Flag: Empty
	output	logic					O_Ready,			//Flag: Ready
	output	logic					O_Busy				//Flag: Busy
);


	//// Logic Connect												////
	logic	[WIDTH_PID-1:0]		PSrcID;
	logic	[NUM_UNITS-1:0]		T_Commit;
	logic						We;
	logic						Re;

	logic	[WIDTH_UNITS-1:0]	PtrHead;
	logic	[WIDTH_UNITS-1:0]	PtrTail;
	logic						Clr;
	logic						Stop;

	logic	[WIDTH_PID-1:0]		CommitPSrcID;

	logic						Full;
	logic						Empty;
	logic						Ready;

	logic	[WIDTH_PID-1:0]		CommitNo;


	//// Capturing Signal											////
	//	 Commit State Buffer (Reorder Buffer)
	commit_t					Buff [NUM_UNITS-1:0];

	//	 Commit Signal
	logic	[NUM_UNITS-1:0]		R_Commit;

	//	 Acknowlodge to PortMap Unit
	logic	[NUM_UNITS-1:0]		R_Ack;

	//	 Request to Rename Unit
	logic						R_Req;


	//// State Register												////
	logic						R_Full;
	logic						R_Empty;
	logic						R_Ready;


	//// Status														////
	assign O_Busy			= ~R_Empty;
	assign O_Ready			= R_Ready;
	assign O_Empty			= R_Empty;
	assign O_Full			= R_Full;

	assign O_Ack			= R_Ack;

	assign CommitPSrcID		= Buff[ PtrTail ].PSrcID;

	//	 Write-Enable
	assign We				= I_Req;

	//	 Read-Enable
	assign Re				= Buff[ PtrTail ].Valid & Buff[ PtrTail ].Commit;

	//	 Buffer Control
	assign Clr				= 1'b0;
	assign Stop				= 1'b0;


	//// Send Acknowledge to Port-Map unit							////
	assign O_Commit			= R_Commit;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Commit			<= '0;
		end
		else begin
			for ( int i=0; i<NUM_UNITS; ++ i ) begin
				R_Commit[ i ] <= T_Commit[ i ];
			end
		end
	end


	//// Commit-Request Realeasing to Rename Unit					////
	//	 Validation
	assign O_Req			= R_Req;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Req			<= 1'b0;
		end
		else begin
			R_Req			<= Re;
		end
	end

	//	 Acknowledge
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Ack		<= '0;
		end
		else begin
			if ( |I_Commit ) begin
				for ( int j = 0; j<NUM_UNITS; ++j ) begin
					if ( Buff[ j ].Valid & ( CommitNo == Buff[ j ].PSrcID ) ) begin
						R_Ack[ CommitNo ]	<= 1'b1;
					end
					else if ( j != CommitNo ) begin
						R_Ack[ j ] 		<= 1'b0;
					end
				end
			end
			else begin
				R_Ack		<= '0;
			end
		end
	end


	//// Buffer Body												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<NUM_UNITS; ++i ) begin
				Buff[ i ]	<= '0;
			end
		end
		else begin
			if ( |I_Commit ) begin
				for ( int i=0; i<NUM_UNITS; ++i ) begin
					if ( Buff[ i ].Valid & ( Buff[ i ].PSrcID == CommitNo ) ) begin
						Buff[ i ].Commit	<= 1'b1;
					end
				end
			end

			if ( I_Req ) begin
				Buff[ PtrHead ].Valid	<= 1'b1;
				Buff[ PtrHead ].PSrcID	<= I_SrcPort;
			end

			if ( Re ) begin
				Buff[ PtrTail ].Valid	<= 1'b0;
				Buff[ PtrTail ].Commit	<= 1'b0;
			end
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Full			<= 1'b0;
			R_Empty			<= 1'b0;
			R_Ready			<= 1'b0;
		end
		else begin
			R_Full			<= Full;
			R_Empty			<= Empty;
			R_Ready			<= Ready;
		end
	end

	Encoder #(
		.NUM_ENTRY(			NUM_UNITS					)
	) CommitEnc
	(
		.I_Data(			I_Commit					),
		.O_Enc(				CommitNo					)
	);

	//	 Decode Commit Request
	//		Generate One-Hot Code
	Decoder #(
		.NUM_ENTRY(			NUM_UNITS					),
		.LOG_NUM_ENTRY(		WIDTH_PID					)
	) DecodeCommit
	(
		.I_Val(				CommitPSrcID				),
		.O_Grt(				T_Commit					)
	);

	OutBuffCTRL #(
		.SIZE_OUT_BUFF(		NUM_UNITS					),
		.LOG_SIZE_BUFF(		WIDTH_UNITS					)
	) BuffCTRL
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			I_Req | Re					),
		.I_Clr(				Clr							),
		.I_Nack(			Stop						),
		.I_We(				We							),
		.I_Re(				Re							),
		.O_PtrHead(			PtrHead						),
		.O_PtrTail(			PtrTail						),
		.O_Full(			Full						),
		.O_Empty(			Empty						),
		.O_Ready(			Ready						)
	);

endmodule