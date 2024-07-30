///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Global Buffer Unit
//	Module Name:	BRAM
//	Function:
//					Global Buffer on out side of Compute Tile
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module BRAM
    import pkg_en::FTk_t;
    import pkg_en::BTk_t;
    import pkg_en::WIDTH_DATA;
	import pkg_bram_if::*;
(
	input								clock,
	input								reset,
	input	FTk_t						I_Data,				//Store Data from IFLogic/BRAM
	output	BTk_t						O_CTRL,				//Control for Store
	output	FTk_t						O_Data,				//Load Data to IFLogic/BRAM
	input	BTk_t						I_CTRL,				//Control for Load
	input								I_SelDst,			//Flag: Config for Destination
	input								I_Ld,				//Flag: Set Load Config
	input								I_St,				//Flag: Set Store Config
	input								I_Done,				//Flag: Port is mapped
	input	FTk_t						I_RCFG,				//Configuration Data
	output								O_Busy				//Flag: Busy
);


	//// Buffer RAM													////
	//	 Width: WIDTH_DATA
	//	 Depth: 2**ADDR Words
	logic	[WIDTH_DATA-1:0]	BRAM [2**WIDTH_BRAM_ADDR-1:0];

	//	 Address
	logic	[WIDTH_BRAM_ADDR-1:0]	Address;

	//		Configuration Data
	logic	[WIDTH_BRAM_LENGTH-1:0]	Length;
	logic	[WIDTH_BRAM_STRIDE-1:0]	Stride;
	logic	[WIDTH_BRAM_BASE-1:0]	Base;

	//	 Enable to Run
	logic						En;

	//	 Flag: Termination
	logic						Term;

	//	 Stop Storing
	logic						StStop;

	//	 Terminate Storing
	logic						StTerm;

	//	 Stop Loading
	logic						LdStop;

	//	 Terminate Loading
	logic						LdTerm;

	//	 Tokens
	logic						acq_message;
	logic						rls_message;
	logic						acq_flagmsg;
	logic						rls_flagmsg;

	logic						is_Acq;
	logic						is_Rls;

	//	 State in Finite State Machine
	logic						is_FSM_Init;
	logic						is_FSM_ID_T;
	logic						is_FSM_ID_F;
	logic						is_FSM_ATTR;
	logic						is_FSM_BCFG;
	logic						is_FSM_ST_ATTR;
	logic						is_FSM_ST;
	logic						is_FSM_LD_MYID;
	logic						is_FSM_LD_ID_T;
	logic						is_FSM_LD_ID_F;
	logic						is_FSM_RCFG_ATTR;
	logic						is_FSM_RCFG_DATA;
	logic						is_FSM_LENGTH;
	logic						is_FSM_STRIDE;
	logic						is_FSM_BASE;
	logic						is_FSM_LD;

	//	 Enable Load/Store
	logic						En_LdSt;
	logic						LdEn;

	//	 Capture Configuration Data
	logic						Set_Config;

	logic						Skip_In;
	logic						Skip_Out;
	logic						Skip_Data;


	//// Capture Signal												////
	FTk_t						MyID;
	FTk_t						ID_T;
	FTk_t						ID_F;

	//	 Access State Register
	logic						R_Store;
	logic						R_Load;
	logic						R_Term;
	logic						R_TermD1;

	//	 Control Finite State Machine
	fsm_bram					R_FSM;

	//	 Access Length
	//	 Load Data Register
	FTk_t						Ld_Data;

	//	 Index Register
	logic	[7:0]				R_Index;

	//		Capture Store Data Word
	FTk_t						Wt_Data;

	//		Capture Load Data Word
	FTk_t						Rd_pkg_Data;
	logic	[WIDTH_DATA-1:0]	Rd_Data;

	//	 Store/Load Enable
	logic                 		R_StEn;
	logic	[1:0]          		R_LdEn;

	logic	[WIDTH_DATA-1:0]	R_Length;

	//	 Set Flag for Configuration
	logic						R_Set_Config;

	//	 Skip Send First Data Word
	logic						R_Skip_Data;

	//	Terminal Flag
	logic						TermSt;
	logic						TermLd;

	logic						R_Nack;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Nack			<= 1'b0;
		end
		else begin
			R_Nack			<= I_CTRL.n;
		end
	end


	// Enable to Run
	assign En				= O_Busy & ~( LdStop | Term | R_Term | StStop );

	// Store-Termination
	assign StTerm			= R_Term & I_St;

	// Stop Storing
	assign StStop			= 1'b0;

	// Load-Termination
	assign LdTerm			= Term & ~R_Term;

	// Stop Loading
	assign LdStop			= R_Nack | R_TermD1;

	// Backward Tokens
	assign O_CTRL.n			= 1'b0;
	assign O_CTRL.t			= R_Term & I_St;
	assign O_CTRL.v			= 1'b0;
	assign O_CTRL.c			= 1'b0;

	// Access Configuration
	assign Set_Config		= I_Done & I_RCFG.v & ( I_Ld | I_St ) & ~R_Term & ~R_Set_Config;
	assign Skip_Data		= ( Set_Config ) ? 0 | I_RCFG.d[WIDTH_DATA-1]					: '0;
	assign Length			= ( Set_Config ) ? 0 | I_RCFG.d[WIDTH_DATA-2: WIDTH_DATA-14]	: '0;
	assign Stride			= ( Set_Config ) ? 0 | I_RCFG.d[WIDTH_DATA-15:WIDTH_DATA-18]	: '0;
	assign Base				= ( Set_Config ) ? 0 | I_RCFG.d[WIDTH_DATA-19:0] 				: '0;


	//// State in Finite State Machine								////
	assign is_FSM_Init		= ( R_FSM == BRAM_Init ) & is_Acq;
	assign is_FSM_ID_T		= ( R_FSM == BRAM_ID_T );
	assign is_FSM_ID_F		= ( R_FSM == BRAM_ID_F );
	assign is_FSM_ATTR		= ( R_FSM == BRAM_ATTR );
	assign is_FSM_BCFG		= ( R_FSM == BRAM_BCFG );
	assign is_FSM_ST_ATTR	= ( R_FSM == BRAM_ST_ATTR );
	assign is_FSM_ST		= ( R_FSM == BRAM_ST );
	assign is_FSM_LD_MYID	= ( R_FSM == BRAM_LD_MYID );
	assign is_FSM_LD_ID_T	= ( R_FSM == BRAM_LD_ID_T );
	assign is_FSM_LD_ID_F	= ( R_FSM == BRAM_LD_ID_F );
	assign is_FSM_RCFG_ATTR	= ( R_FSM == BRAM_RCFG_ATTR );
	assign is_FSM_RCFG_DATA	= ( R_FSM == BRAM_RCFG_DATA );
	assign is_FSM_LENGTH	= ( R_FSM == BRAM_LENGTH );
	assign is_FSM_STRIDE	= ( R_FSM == BRAM_STRIDE );
	assign is_FSM_BASE		= ( R_FSM == BRAM_BASE );
	assign is_FSM_LD		= ( R_FSM == BRAM_LD );


	//// Skip First Data Word										////
	//	 First Data Word is Atttribute Word
	assign Skip_In			= is_FSM_ATTR & R_Skip_Data;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Skip_Data		<= 1'b0;
		end
		else if ( Skip_In | Skip_Out ) begin
			R_Skip_Data		<= 1'b0;
		end
		else if ( Set_Config ) begin
			R_Skip_Data		<= Skip_Data;
		end
	end


	//// Capture IDs												////
	//	 My-ID
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			MyID			<= '0;
		end
		else if ( is_FSM_Init ) begin
			MyID			<= I_Data;
		end
	end

	//	 True-ID
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			ID_T			<= '0;
		end
		else if ( is_FSM_ID_T & I_Data.v ) begin
			ID_T			<= I_Data;
		end
	end

	//	 False-ID
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			ID_F			<= '0;
		end
		else if ( is_FSM_ID_F & I_Data.v ) begin
			ID_F			<= I_Data;
		end
	end


	//// Capture Access Length										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Length		<= '0;

		end
		else if ( Set_Config ) begin
			R_Length		<= Length;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Set_Config	<= 1'b0;
		end
		else if ( Term ) begin
			R_Set_Config	<= 1'b0;
		end
		else if ( Set_Config ) begin
			R_Set_Config	<= 1'b1;
		end
	end


	//// Control Finite State Machine								////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FSM			<= BRAM_Init;
		end
		else case ( R_FSM )
			BRAM_Init: begin
				if ( is_Acq ) begin
					R_FSM			<= BRAM_ID_T;
				end
				else if ( I_Ld & R_Set_Config & ~R_Term ) begin
					R_FSM			<= BRAM_LD_MYID;
				end
				else begin
					R_FSM			<= BRAM_Init;
				end
			end
			BRAM_ID_T: begin
				if ( I_Data.v ) begin
					R_FSM			<= BRAM_ID_F;
				end
			end
			BRAM_ID_F: begin
				if ( I_Data.v ) begin
					R_FSM			<= BRAM_ATTR;
				end
			end
			BRAM_ATTR: begin
				if ( is_Rls ) begin
					R_FSM			<= BRAM_Init;
				end
				else  if ( I_Data.v ) begin
					R_FSM			<= BRAM_BCFG;
				end
			end
			BRAM_BCFG: begin
				if ( is_Rls ) begin
					R_FSM			<= BRAM_Init;
				end
				else if ( I_St ) begin
					R_FSM			<= BRAM_ST_ATTR;
				end
				else begin
					R_FSM			<= BRAM_Init;
				end
			end
			BRAM_ST_ATTR: begin
				if ( is_Rls ) begin
					R_FSM			<= BRAM_Init;
				end
				else begin
					R_FSM			<= BRAM_ST;
				end
			end
			BRAM_ST: begin
				if ( is_Rls ) begin
					R_FSM			<= BRAM_Init;
				end
			end
			BRAM_LD_MYID: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_LD_ID_T;
				end
			end
			BRAM_LD_ID_T: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_LD_ID_F;
				end
			end
			BRAM_LD_ID_F: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_RCFG_ATTR;
				end
			end
			BRAM_RCFG_ATTR: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_RCFG_DATA;
				end
			end
			BRAM_RCFG_DATA: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_LENGTH;
				end
			end
			BRAM_LENGTH: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_STRIDE;
				end
			end
			BRAM_STRIDE: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_BASE;
				end
			end
			BRAM_BASE: begin
				if ( ~R_Nack ) begin
					R_FSM			<= BRAM_LD;
				end
			end
			BRAM_LD: begin
				if ( LdTerm ) begin
					R_FSM			<= BRAM_Init;
				end
			end
			default: begin
					R_FSM			<= BRAM_Init;
			end
		endcase
	end


	//// Sequence Type (Busy State)									////
	//	 Store
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Store			<= 1'b0;
		end
		else if ( Term | ( R_FSM == BRAM_Init ) ) begin
			R_Store			<= 1'b0;
		end
		else if ( I_St & is_FSM_ATTR ) begin
			R_Store			<= 1'b1;
		end
	end

	//	 Load
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Load			<= 1'b0;
		end
		else if ( Term | ( R_FSM == BRAM_Init ) ) begin
			R_Load			<= 1'b0;
		end
		else if ( I_Ld & ( R_FSM > BRAM_ST ) ) begin
			R_Load			<= 1'b1;
		end
	end


	//// BRAM Status												////
	assign O_Busy			= R_Store | R_Load;


	//// Capture Termination										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Term			<= 1'b0;
		end
		else if ( Term & ( I_Ld | I_St ) ) begin
			R_Term			<= 1'b1;
		end
		else if ( ~I_Done | ( R_FSM == BRAM_Init ) ) begin
			R_Term			<= 1'b0;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_TermD1		<= 1'b0;
		end
		else begin
			R_TermD1		<= R_Term;
		end
	end


	//// Buffer RAM													////
	//	 Capture Writing Data
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Wt_Data			<= '0;
		end
		else if ( BRAM_Init == R_FSM ) begin
			Wt_Data			<= '0;
		end
		else if ( I_Data.v & ~R_Skip_Data ) begin
			Wt_Data			<= I_Data;
		end
	end

	//	 Store Enable (Request)
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_StEn			<= 1'b0;
		end
		else begin
			R_StEn			<= I_St & ( R_FSM > BRAM_ATTR ) & ( R_FSM <= BRAM_ST ) & I_Data.v;
		end
	end

	//	 Store
	assign TermSt			= is_Rls;
	always_ff @( posedge clock ) begin
		if ( R_StEn ) begin
			BRAM[ Address ]	<= Wt_Data.d;
		end
	end

	//	 Load
	assign TermLd			= R_Load & ( Term | I_CTRL.t );

	// Capture Load Enable(Request)
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_LdEn			<= '0;
		end
		else if ( TermLd ) begin
			R_LdEn[0]		<= 1'b0;
			R_LdEn[1]		<= R_LdEn[1];
		end
		else begin
			R_LdEn[0]		<= R_Load & ~LdStop;
			R_LdEn[1]		<= R_LdEn[0];
		end
	end

	assign Rd_pkg_Data.v	= 1'b0;
	assign Rd_pkg_Data.a	= 1'b0;
	assign Rd_pkg_Data.c	= 1'b0;
	assign Rd_pkg_Data.r	= 1'b0;
	assign Rd_pkg_Data.d	= Rd_Data;
	assign Rd_pkg_Data.i	= '0;
	assign Ld_Data			= ( is_FSM_LD_MYID ) ?		MyID :
								( is_FSM_LD_ID_T ) ?	ID_T :
								( is_FSM_LD_ID_F ) ?	ID_F :
														Rd_pkg_Data;

	assign O_Data.v			= is_FSM_LD_MYID | is_FSM_LD_ID_T | is_FSM_LD_ID_F | ( ( R_FSM > BRAM_LD_ID_F ) & R_LdEn[0] & ~Skip_Out );
	assign O_Data.a			= is_FSM_LD_MYID | LdTerm;
	assign O_Data.r			= ( R_Load & ~LdStop & I_Ld ) ? LdTerm		: '0;
	assign O_Data.c			= ( R_Load & ~LdStop & I_Ld ) ? '0			: '0;
	assign O_Data.i			= ( R_Load & ~LdStop & I_Ld ) ? R_Index		: '0;
	assign O_Data.d			= ( R_Load & ~LdStop & I_Ld ) ? Ld_Data.d	: '0;

	always_ff @( posedge clock, posedge reset ) begin
		if ( reset ) begin
			Rd_Data			<= '0;
		end
		else if ( R_LdEn[0] & ~LdStop ) begin
			Rd_Data			<= BRAM[ Address ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Skip_Out		<= 1'b0;
		end
		else begin
			Skip_Out		<= R_Skip_Data & is_FSM_LD_ID_F;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Index			<= '0;
		end
		else if ( R_Term ) begin
			R_Index			<= '0;
		end
		else if ( R_LdEn[1] & ( R_FSM == 4'hf ) ) begin
			R_Index			<= R_Index + 1'b1;
		end
	end


	//// Check Tokens												////
	assign is_Acq			= acq_message | acq_flagmsg;
	TokenDec TokenDecAcq (
		.I_FTk(				I_Data						),
		.O_acq_message(		acq_message					),
		.O_rls_message(									),
		.O_acq_flagmsg(		acq_flagmsg					),
		.O_rls_flagmsg(									)
	);

	assign is_Rls			= rls_message | rls_flagmsg;
	TokenDec TokenDecRls (
		.I_FTk(				Wt_Data						),
		.O_acq_message(									),
		.O_rls_message(		rls_message					),
		.O_acq_flagmsg(									),
		.O_rls_flagmsg(		rls_flagmsg					)
	);


	//// Address Generation Unit									////
	assign LdEn				= R_StEn | ( R_LdEn[0] & ~LdStop & ( Skip_Out | ~R_Skip_Data ));
	assign En_LdSt			= R_StEn | LdEn;
	BRAM_AGU #(
		.WIDTH_ADDR(		WIDTH_BRAM_ADDR				),
		.WIDTH_LENGTH(		WIDTH_BRAM_LENGTH			),
		.WIDTH_STRIDE(		WIDTH_BRAM_STRIDE			),
		.WIDTH_BASE(		WIDTH_BRAM_BASE				)
	) BRAM_AGU
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_En(				En_LdSt						),
		.I_Set(				Set_Config					),
		.I_Length(			Length						),
		.I_Stride(			Stride						),
		.I_Base(			Base						),
		.O_Addr(			Address						),
		.O_Term(			Term						)
	);

endmodule