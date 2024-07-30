///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Output Buffer
//	Module Name:	OutBuffer
//	Function:
//					used for Index Compression
//					Buffer for Reordering Inputs
//					Multi-stage pipeline with skipping must buffer in-coming data.
//					Because the order of the coming is out-of-order.
//					The function is equivalent to reorder buffer used in processors.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module OutBuff
	import pkg_en::*;
	import pkg_extend_index::*;
#(
	parameter int SIZE_OUT_BUFF		= 5,
	parameter int PIPE_DEPTH		= 5,
	parameter int LOG_SIZE_BUFF		= $clog2(SIZE_OUT_BUFF)
)(
	input							clock,
	input							reset,
	input							I_Active,			//Activate Module
	input							I_Fired,			//Flag: Fired to Exec Unit
	input	FTk_t					I_FTk,				//Data from Exec Unit
	output	FTk_t					O_FTk,				//Forward Tokens
	input	FTk_t					I_TSFTk,			//Thru/Skip Value
	input							I_TS,				//Flag: Thru/Skip
	input	BTk_t					I_BTk,				//Backward Tokens
	output	BTk_t					O_BTk				//Backward Tokens
);


	//// Tokens														////
	//	 Valid
	//	 Data coming from ALU pipeline
	logic						ValidC;

	//	 Data coming from SkipIF
	logic						ValidR;

	//	 Nack
	logic						Nack;


	//// Buffer														////
	// Buffer-Validation Flag Register
	logic	[SIZE_OUT_BUFF-1:0]	Valid;

	// Buffer-Pointers
	logic	[LOG_SIZE_BUFF-1:0]	PtrHead;
	logic	[LOG_SIZE_BUFF-1:0]	PtrTail;

	// Buffer-Bodies
	FTk_t						OutBuff [SIZE_OUT_BUFF-1:0];

	//	 Termination
	logic						Term;

	//	 Buffer-Clear Signal
	logic						Clr;

	//	 Buffer Status Flag
	logic						OutBuff_Full;
	logic						OutBuff_Empty;
	logic						OutBuff_Ready;


	logic						We_C;
	logic						We_R;

	//	 Update Tag (Write-Enable)
	logic						TagUpdate;

	//	 Read-Enable
	logic						Re;

	//	 Release Tolken on Output of Buffer
	logic						is_Rls;

	//	 Send Shared Data
	logic						SendSData;

	//	 Send Data
	logic						SendData;

	//	 Firing at First Stage on Execution Stage
	logic						Fired;


	//// TS-Buffer													////
	logic						TS_We;
	logic						Seek;
	logic						Hit;
	FTk_t						TSFTk;


	//// Output-Enable												////
	logic						EnOut;


	//// Capture Signal												////
	logic						R_Rls;
	logic						Ready;
	logic						ReadyD1;

	//	Retimed Tokens
	BTk_t						BTk0;

	//	 Capture Hit Signal to Output retimed Data wortd
	logic						R_Hit;

	//	 Capture Output Data Word from TS-Buffer for the Hit
	FTk_t						R_TSFTk;


	//// Detection of End of Work									////
	//	 Detection of Fireing of Release Token
	assign is_Rls			= ~Nack & I_FTk.r;

	//	 Detection for Termination on Output
	assign Term				= EnOut & OutBuff[ PtrTail ].r;


	//// Validation													////
	//	 Validation from Skip Unit
	assign ValidR			= I_TS;

	//	 Validation from Execution Last Stage
	assign ValidC			= I_FTk.v | is_Rls;


	//// Set State in Release										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rls		<= 1'b0;
		end
		else if ( O_FTk.r ) begin
			R_Rls		<= 1'b0;
		end
		else if ( is_Rls ) begin
			R_Rls		<= 1'b1;
		end
	end


	//// Fired ast Execution First Stage							////
	assign Fired		= I_Fired;


	//// Ready Flag													////
	//	 used for Sending Shared Data Word
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Ready		<= 1'b0;
			ReadyD1		<= 1'b0;
		end
		else if ( is_Rls & ~Nack ) begin
			Ready		<= 1'b0;
			ReadyD1		<= 1'b0;
		end
		else if ( ValidC ) begin
			Ready		<= 1'b1;
			ReadyD1		<= Ready;
		end
		else begin
			Ready		<= Ready;
			ReadyD1		<= Ready;
		end
	end

	assign SendSData	= Ready & ~ReadyD1;
	assign SendData		= Ready &  ReadyD1;


	//// Backward Tokens											////
	//		NOT-Retimed Nack Token
	assign Nack			= BTk0.n;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			BTk0		<= '0;
		end
		else begin
			BTk0		<= I_BTk;
		end
	end


	//// Output														////
	//	 Enable to Output from Output Buffer
	assign EnOut		= Valid[ PtrTail ] & ~Nack & I_Active;

	//	 Forward Tokens
	assign O_FTk  	= ( R_Hit )	?	R_TSFTk :
						( EnOut ) ? OutBuff[ PtrTail ] :
									'0;

	//	 Backward Tokens
	assign O_BTk		= Nack;


	//// Re-order Buffer											////
	//	 Write-Enable
	assign We_C			= ValidC;
	assign We_R			= ~ValidC & ValidR;

	//	 Valid Flag Register
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Valid		<= '0;
		end
		else if ( Clr ) begin
			Valid		<= '0;
		end
		else begin
			//	Clear Valid when Buffer Output
			if ( EnOut & ~R_Hit ) begin
				Valid[ PtrTail ]	<= 1'b0;
			end

			//	Set Valid when Comming from ALU Output
			if ( We_C | We_R ) begin
				Valid[ PtrHead ]	<= 1'b1;
			end
		end
	end

	//	 Buffer Body
	//		2-port Write, 1-port Read
	//		Store Exec Result Data and or Thru Data
	always_ff @( posedge clock ) begin
		//	Capture Input Comming from ALU Output
		if ( We_C ) begin
			OutBuff[ PtrHead ]	<= I_FTk;
		end
		else if ( We_R ) begin
			OutBuff[ PtrHead ]	<= I_TSFTk;
		end
	end


	//// Buffer Control												////
	//	 Clear Pointers after Output Data Word having Release Token
	assign Clr			= Term;

	//		Write Pointer
	assign TagUpdate	= Fired | I_TS | ( ~Fired & ValidC );

	//		Read Pointer
	assign Re			= EnOut & ~R_Hit;

	OutBuffCTRL #(
		.SIZE_OUT_BUFF(		SIZE_OUT_BUFF				)
	) OutBuffCTRL
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			I_Active					),
		.I_Clr(				Clr							),
		.I_Nack(			Nack						),
		.I_Re(				Re							),
		.I_We(				TagUpdate					),
		.O_PtrHead( 		PtrHead						),
		.O_PtrTail(			PtrTail						),
		.O_Full(			OutBuff_Full				),
		.O_Empty(			OutBuff_Empty				),
		.O_Ready(			OutBuff_Ready				)
	);


	//// TS Buffer													////
	//	 Capture Buffer-Hit to Output
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Hit		<= 1'b0;
		end
		else begin
			R_Hit		<= Hit;
		end
	end

	//	 Caputure TS-Buffer Output (Retiming)
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_TSFTk		<= '0;
		end if ( Hit ) begin
			R_TSFTk		<= TSFTk;
		end
	end

	//	 Write Enable for TS Buffer
	assign TS_We		= ( ( ValidC & ValidR ) | I_BTk.n ) & I_TS;

	//	 Seek in TS-Buffer
	assign Seek			= ( EnOut & SendData ) | SendSData;

	TagCAM #(
		.LENGTH(			SIZE_OUT_BUFF				),
		.TYPE_FTK(			FTk_t						)
	) TSBuff
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				TS_We						),
		.I_PtrHead(			PtrHead						),
		.I_Seek(			Seek						),
		.I_Tag(				PtrTail						),
		.I_FTk(				I_TSFTk						),
		.O_FTk(				TSFTk						),
		.O_Hit(				Hit							),
		.O_Num(											)
	);

endmodule
