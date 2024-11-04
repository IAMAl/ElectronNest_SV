///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Skip Initializer
//	Module Name:	SkipInit
//	Function:
//					Control for Initializin Skip Unit
//					Order to Capture Shared Data Word if available
//					This unit is a submodule in SkipUnit.
//					Initialize the sequence.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module SkipInit
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input 							is_Valid,			//Valid Token
	input							is_AuxData,			//Flag: Aux Data Word Block
	input							is_Rls,				//Release Token
	input							is_Shared,			//Flag: is_Shared in Attrib Word
	input							is_NonZero,			//Flag: is_Zero in Attrib Word
	input							is_Sent,			//Flag: is_Sent
	output							O_Ready,			//Flag: Ready to Calc
	output							O_Store,			//Flag: Store Init Data Reg
	output							O_Zero,				//Flag: is_Zero
	output							O_Shared,			//Flag: Do Sharing
	output							O_Send_SZero,		//Flag: Send Shared Zero
	output							O_Send_SNZero,		//Flag: Send Shared Not Zero
	output							O_Run_NoShared		//Flag: Run in case of No-Shared
);

	fsm_skip_init				FSM_Init;


	//// Logic Cennect												////
	logic						is_AuxDataBlock;

	logic						Send_SZero;
	logic						Send_SNZero;


	//// Capture Signal												////
	logic						R_is_Valid;
	logic						R_KickSkip;
	logic						R_KickNotSkip;
	logic						R_KickNZRO;
	logic						Ready;

	logic						R_Send_SZero;
	logic						R_Send_SNZero;


	//// Capture Valid Token										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Valid	<= 1'b0;
		end
		else begin
			R_is_Valid	<= is_Valid;
		end
	end


	//// Capture Kick Condition (to Avoid Combinetorial-Loop)		////
	//	 Kicking Start for No Skipping (No Shared Data)
	assign O_Run_NoShared	= R_KickNotSkip;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_KickNotSkip	<= 1'b0;
		end
		else if ( is_Rls | is_Sent ) begin
			R_KickNotSkip	<= 1'b0;
		end
		else if ( ( FSM_Init == SKIP_IINIT ) & ~( R_KickSkip | R_KickNZRO ) & ~is_Shared & is_AuxData & is_Valid  ) begin
			R_KickNotSkip	<= 1'b1;
		end
	end

	//	 Kicking Start for Zero-Skip
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_KickSkip	<= 1'b0;
		end
		else if ( is_Rls | is_Sent ) begin
			R_KickSkip	<= 1'b0;
		end
		else if ( ( FSM_Init == SKIP_IINIT ) & ~is_NonZero & is_Shared & is_AuxData & is_Valid ) begin
			R_KickSkip	<= 1'b1;
		end
	end

	//	 Kicking Start for Non-Zero Skip
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_KickNZRO	<= 1'b0;
		end
		else if ( is_Rls | is_Sent ) begin
			R_KickNZRO	<= 1'b0;
		end
		else if ( ( FSM_Init == SKIP_IINIT ) & is_NonZero & is_Shared & is_AuxData & is_Valid ) begin
			R_KickNZRO	<= 1'b1;
		end
	end


	//// Flag: Ready												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Ready		<= 1'b0;
		end
		else if ( is_Rls ) begin
			Ready		<= 1'b0;
		end
		else if ( ~is_Shared & is_AuxData & is_Valid ) begin
			Ready		<= 1'b1;
		end
	end


	//// Flag: Ready to Execute										////
	assign O_Ready			= (( FSM_Init == SKIP_IINIT ) & ( R_KickSkip | R_KickNZRO ) ) |
								( FSM_Init == SKIP_NZRO )	|
								( FSM_Init == SKIP_ZERO )	|
								( FSM_Init == SKIP_RUN ) |
								R_KickNotSkip;


	//// Shared Data Register Control								////
	//	 Data Block Detection
	assign is_AuxDataBlock	= ( FSM_Init == SKIP_IINIT ) & is_AuxData & R_is_Valid;

	//	 Store in Shared Data Register
	logic Store;
	logic R_Stored;

	assign Store			= ~R_Stored & ( R_KickNZRO | R_KickSkip ) & is_Valid;

	assign O_Store			= Store;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stored	<= 1'b0;
		end
		else if ( is_Rls ) begin
			R_Stored	<= 1'b0;
		end
		else if ( Store ) begin
			R_Stored	<= 1'b1;
		end
	end

	assign O_Shared			= ( FSM_Init == SKIP_RUN );


	//// Flag: Data Block has Zeros if is_Share is asserted			////
	assign O_Zero			= ( FSM_Init == SKIP_ZERO ) | R_KickSkip;


	//// Send Shared Data Word										////
	assign Send_SZero		= R_Stored & R_KickSkip & (( FSM_Init == SKIP_ZERO ) | ( FSM_Init == SKIP_RUN ));
	assign Send_SNZero		= R_Stored & R_KickNZRO & (( FSM_Init == SKIP_NZRO ) | ( FSM_Init == SKIP_RUN ));

	assign O_Send_SZero		= Send_SZero;
	assign O_Send_SNZero	= Send_SNZero;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Send_SZero	<= 1'b0;
		end
		else if ( is_Rls ) begin
			R_Send_SZero	<= 1'b0;
		end
		else if ( Send_SZero ) begin
			R_Send_SZero	<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Send_SNZero	<= 1'b0;
		end
		else if ( is_Rls ) begin
			R_Send_SNZero	<= 1'b0;
		end
		else if ( Send_SNZero ) begin
			R_Send_SNZero	<= 1'b1;
		end
	end


	//// Initialize Control FSM										////
	always_ff @( posedge clock ) begin: ff_fsm_skip
		if ( reset ) begin
			FSM_Init	<= SKIP_IINIT;
		end
		else case ( FSM_Init )
			SKIP_IINIT: begin
				if ( R_KickSkip ) begin
					// Compressing for Zeros
					FSM_Init	<= SKIP_ZERO;
				end
				else if ( R_KickNZRO ) begin
					// Compressing for Non-Zeros
					FSM_Init	<= SKIP_NZRO;
				end
				else begin
					// NOP
					FSM_Init	<= SKIP_IINIT;
				end
			end
			SKIP_NZRO: begin
				if ( is_Rls ) begin
					FSM_Init	<= SKIP_IINIT;
				end
				else if ( is_Valid ) begin
					FSM_Init	<= SKIP_RUN;
				end
			end
			SKIP_ZERO: begin
				if ( is_Rls ) begin
					FSM_Init	<= SKIP_IINIT;
				end
				else if ( R_is_Valid ) begin
					FSM_Init	<= SKIP_RUN;
				end
			end
			SKIP_RUN: begin
				if ( is_Rls ) begin
					FSM_Init	<= SKIP_IINIT;
				end
			end
			default: begin
				FSM_Init	<= SKIP_IINIT;
			end
		endcase
	end

endmodule
