///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Skip Unit
//	Module Name:	SyncUnit
//	Function:
//					Top Module of Skip Unit
//					used for Index Compression
//					attatched to Datapath
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module SyncUnit
	import	pkg_en::*;
	import	pkg_extend_index::*;
(
	input         					clock,
	input							reset,
	input			 				I_Active,			//Flag: Enable to Run
	input							I_EnSrcA,			//Flag: Enable to Input
	input							I_EnSrcB,			//Flag: Enable to Input
	input	FTk_t					I_FTk_A,			//Source Forward Tokens
	input	FTk_t					I_FTk_B,			//Source Forward Tokens
	input	BTk_t					I_BTk_A,			//Source Backward Tokens
	input	BTk_t					I_BTk_B,			//Source Backward Tokens
	output	FTk_t					O_FTk_A,			//Forward Tokens
	output	FTk_t					O_FTk_B,			//Forward Tokens
	output	BTk_t					O_BTk_A,			//Backward Tokens
	output	BTk_t					O_BTk_B,			//Backward Tokens
	output	FTk_t					O_SFTk_A,			//Shared Data
	output	FTk_t					O_SFTk_B,			//Shared Data
	output	logic					O_Zero_A,			//Flag: Zero-Shared
	output	logic					O_Zero_B,			//Flag: Zero-Shared
	output	logic					O_Shared			//Flag: Shared
);


	logic						is_Shared_A;
	logic						is_Shared_B;
	logic						is_NonZero_A;
	logic						is_NonZero_B;
	logic						is_DataWord_A;
	logic						is_DataWord_B;


	//// Token														////
	//	 Valid
    logic                       Valid_A;
    logic                       Valid_B;

	//	 Nack
    logic                       Nack;
	logic						Nack_A;
	logic						Nack_B;

	//	 Token Decode
	logic						rls_message_A;
	logic						rls_message_B;
	logic						rls_flagmsg_A;
	logic						rls_flagmsg_B;

	//	 Release Token Detection
	logic						is_Rls_A;
	logic						is_Rls_B;

    BTk_t                       BTk_A;
    BTk_t                       BTk_B;

	//	 Ready for Operation
	logic						ReadyOp;

	//	 Sent Data Word
	logic						Send_Data;

	//	 Fired by Release Tokens
	logic						is_Fired_Rls;


	//// Shared Data												////
	logic						ReadyInit_A;
	logic						ReadyInit_B;
	logic						Store_SFTk_A;
	logic						Store_SFTk_B;
	logic						Shared_A;
	logic						Shared_B;

	logic						W_Send_SZero_A;
	logic						W_Send_SZero_B;
	logic						W_Send_SNZero_A;
	logic						W_Send_SNZero_B;

	logic						Send_SZero_A;
	logic						Send_SZero_B;
	logic						Send_SNZero_A;
	logic						Send_SNZero_B;

	logic						Send_Shared_Data;


	//// Index Compression											////
	//	 Evaluation Input
	FTk_t						W_FTk_A;
	FTk_t						W_FTk_B;

	logic						Validation_A;
	logic						Validation_B;

	//	 Index
	logic [WIDTH_INDEX - 1:0]	Index_A;
	logic [WIDTH_INDEX - 1:0]	Index_B;
	logic						IndexMismatch_A;
	logic						IndexMismatch_B;

	//	 Ready to Release
	logic						is_Ready_Rls_A;
	logic						is_Ready_Rls_B;

	//	 Supporting Shared and Non-Shared Sources
	logic						Run_NoShared_A;
	logic						Run_NoShared_B;

	//
	logic						En_Wr_A;
	logic						En_Wr_B;

	logic						En_Rd_A;
	logic						En_Rd_B;

	// Recovery Flag
	logic						Exceed_FTk_A;
	logic						Exceed_FTk_B;

	//	 Send Data Flag
	logic						Send_Data_A;
	logic						Send_Data_B;

	//	 Sending Data Selection
	FTk_t						FTk_A_;
	FTk_t						FTk_B_;
	FTk_t						FTk_A;
	FTk_t						FTk_B;

	//	 Buffer Status
	logic						Full_A;
	logic						Full_B;
	logic						Empty_A;
	logic						Empty_B;
	logic	[1:0]				Num_A;
	logic	[1:0]				Num_B;

	logic						Nack_Capacity_A;
	logic						Nack_Capacity_B;


	//// Capture Signal												////
	//	 Capture Shared Data Word
    FTk_t						R_SFTk_A;
    FTk_t						R_SFTk_B;

	//	 Capture FTk
	FTk_t						R_FTk_A;
	FTk_t						R_FTk_B;

	//	 Ready to Send Shared Data Word
	logic						R_Ready_SFTk_A;
	logic						R_Ready_SFTk_B;

	//	 Ready for Releasing
	logic						Ready_Rls_A;
	logic						Ready_Rls_B;

	//
	logic						Send_Null_A;
	logic						Send_Null_B;

	//	 State in Releasing
	logic						R_Rls_A;
	logic						R_Rls_B;

	//	 Capture to Avoid Combinatorial-Loop
	logic						R_IndexMismatch_A;
	logic						R_IndexMismatch_B;

	//	 Retime Nack
	logic						R_Nack_A;
	logic						R_Nack_B;

	logic						R_Send_Data;


	//// Valid Token												////
    assign Valid_A          = I_FTk_A.v;
    assign Valid_B          = I_FTk_B.v;


    //// Backward Token Matters                                     ////
    always_ff @( posedge clock ) begin
        if ( reset ) begin
            BTk_A			<= '0;
        end
        else begin
            BTk_A			<= I_BTk_A;
        end
    end

    always_ff @( posedge clock ) begin
        if ( reset ) begin
            BTk_B			<= '0;
        end
        else begin
            BTk_B			<= I_BTk_B;
        end
    end

    assign Nack             = BTk_A.n | BTk_B.n;


	//// Operation Control											////
	//	 Skip First Sending (Attribute Data Word)
	assign ReadyOp			= ( I_EnSrcA & ReadyInit_A ) & ( I_EnSrcB & ReadyInit_B ) & I_Active;

	// Send Data Flag
	assign Send_Data_A		= ( ~R_IndexMismatch_A & Send_Data & ~( Run_NoShared_A & Send_Data & ~R_Send_Data ) ) |
								( R_IndexMismatch_B & ( Num_B == 2'h0 ) );

	assign Send_Data_B		= ( ~R_IndexMismatch_B & Send_Data & ~( Run_NoShared_B & Send_Data & ~R_Send_Data ) ) |
								( R_IndexMismatch_A & ( Num_A == 2'h0 ) );

	// Recovery
	assign Exceed_FTk_A		= ( R_IndexMismatch_A & ~Send_Data_A & Send_Data_B & ( Num_A > 2'h1) );

	// Select Output
	assign FTk_A			= ( R_IndexMismatch_A | Retime_A | BTk_A.n ) ? R_FTk_A : FTk_A_;

	// Buffer Control
	assign En_Wr_A			= Valid_A & ~BTk_A.n;
	assign En_Rd_A			= ( Send_Data_A & ~Retime_A ) | Exceed_FTk_A | Ready_Rls_A;
	RingBuff2 #(
		.DEPTH_BUFF(		2							),
		.WIDTH_DEPTH(		1							),
		.TYPE_FWRD(			FTk_t						),
		.OFFSET(			0							)
	) MiniBuff_A
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				En_Wr_A						),
		.I_Re(				En_Rd_A						),
		.I_FTk(				I_FTk_A						),
		.O_FTk(				FTk_A_						),
		.O_Full(			Full_A						),
		.O_Empty(			Empty_A						),
		.O_Num(				Num_A						)
	);

	// Recovery Register
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FTk_A			<= '0;
		end
		else if ( IndexMismatch_A & ~R_IndexMismatch_A & ~BTk_A.n ) begin
			R_FTk_A			<= FTk_A_;
		end
		else if ( I_BTk_A.n | ( IndexMismatch_B & I_FTk_A.v ) ) begin
			R_FTk_A			<= I_FTk_A;
		end
		else if ( R_IndexMismatch_B & Send_Data_A ) begin
			R_FTk_A			<= '0;
		end
	end

	logic					Retime_A;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Retime_A		<= 1'b0;
		end
		else begin
			Retime_A		<= R_IndexMismatch_A & ~Send_Data & ~Empty_A;
		end
	end

	// Recovery
	assign Exceed_FTk_B		= ( R_IndexMismatch_B & ~Send_Data_B & Send_Data_A & ( Num_B > 2'h1 ) );

	// Select Output
	assign FTk_B			= ( R_IndexMismatch_B | Retime_B | BTk_B.n ) ? R_FTk_B : FTk_B_;

	// Buffer Control
	assign En_Wr_B			= Valid_B & ~BTk_B.n;
	assign En_Rd_B			= ( Send_Data_B & ~Retime_B ) | Exceed_FTk_B | Ready_Rls_B;
	RingBuff2 #(
		.DEPTH_BUFF(		2							),
		.WIDTH_DEPTH(		1							),
		.TYPE_FWRD(			FTk_t						),
		.OFFSET(			0							)
	) MiniBuff_B
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				En_Wr_B						),
		.I_Re(				En_Rd_B						),
		.I_FTk(				I_FTk_B						),
		.O_FTk(				FTk_B_						),
		.O_Full(			Full_B						),
		.O_Empty(			Empty_B						),
		.O_Num(				Num_B						)
	);

	// Recovery Register
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FTk_B			<= '0;
		end
		else if ( IndexMismatch_B & ~R_IndexMismatch_B & ~BTk_B.n ) begin
			R_FTk_B			<= FTk_B_;
		end
		else if ( I_BTk_B.n | ( IndexMismatch_A & I_FTk_B.v ) ) begin
			R_FTk_B			<= I_FTk_B;
		end
		else if ( R_IndexMismatch_A & Send_Data_B ) begin
			R_FTk_B			<= '0;
		end
	end

	logic					Retime_B;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Retime_B		<= 1'b0;
		end
		else begin
			Retime_B		<= R_IndexMismatch_B & ~Send_Data & ~Empty_B;
		end
	end

	//// Capture Shared Data
    always_ff @( posedge clock ) begin
        if ( reset ) begin
            R_SFTk_A		<= '0;
        end
		else if ( is_Fired_Rls ) begin
			R_SFTk_A		<= '0;
		end
        else if ( Store_SFTk_A ) begin
            R_SFTk_A		<= I_FTk_A;
        end
    end

    always_ff @( posedge clock ) begin
        if ( reset ) begin
            R_SFTk_B		<= '0;
        end
		else if ( is_Fired_Rls ) begin
			R_SFTk_B		<= '0;
		end
        else if ( Store_SFTk_B ) begin
            R_SFTk_B		<= I_FTk_B;
        end
    end


	//// Forward Tokens												////
	assign Send_Data		= ~Empty_A & ~Empty_B & ~Nack & ReadyOp;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Send_Data		<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			R_Send_Data		<= 1'b0;
		end
		else if ( Send_Data ) begin
			R_Send_Data		<= 1'b1;
		end
	end

	logic					Stop_Send_Init;
	assign Stop_Send_Init	= (  ~R_Send_Data2 & ( Run_NoShared_A & Run_NoShared_B ) ) |
								( R_Send_Data & ~( Run_NoShared_A & Run_NoShared_B ) );

	logic					R_Send_Data2;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Send_Data2	<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			R_Send_Data2	<= 1'b0;
		end
		else if ( R_Send_Data & ( Run_NoShared_A & Run_NoShared_B ) ) begin
			R_Send_Data2	<= 1'b1;
		end
	end

	assign Send_Null_A		= IndexMismatch_A & Run_NoShared_A;
	assign Send_Null_B		= IndexMismatch_B & Run_NoShared_B;

	//		Source-0
    assign O_FTk_A.v        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	FTk_A.v | is_Fired_Rls :
								( Send_Null_A ) ?				1'b1 :
								( Send_SNZero_A ) ?				R_SFTk_A.v :
								( Send_Data_A ) ?				FTk_A.v :
								( R_IndexMismatch_A ) ?			FTk_A.v :
																'0;
	assign O_FTk_A.a        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	FTk_A.a | is_Fired_Rls :
								( Send_Null_A ) ?				1'b0 :
								( Send_SNZero_A ) ?				R_SFTk_A.a :
								( Send_Data_A ) ?				FTk_A.a :
								( R_IndexMismatch_A ) ?			FTk_A.a :
																'0;
	assign O_FTk_A.c        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	FTk_A.c | is_Fired_Rls :
								( Send_Null_A ) ?				1'b0 :
								( Send_SNZero_A ) ?				R_SFTk_A.c :
								( Send_Data_A ) ?				FTk_A.c :
								( R_IndexMismatch_A ) ?			FTk_A.c :
																'0;
	assign O_FTk_A.r        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	FTk_A.r | is_Fired_Rls :
								( Send_Null_A ) ?				1'b0 :
								( Send_SNZero_A ) ?				R_SFTk_A.r :
								( Send_Data_A ) ?				FTk_A.r :
								( R_IndexMismatch_A ) ?			FTk_A.r :
																'0;
    assign O_FTk_A.i        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	Index_B :
								( Send_Null_A ) ?				Index_B :
								( Send_SNZero_A ) ?				Index_B :
								( Send_Data_A ) ?				FTk_A.i :
								( R_IndexMismatch_A ) ?			FTk_A.i :
																'0;
    assign O_FTk_A.d        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_A ) ?	FTk_A.d :
								( Send_Null_A ) ?				'0 :
								( Send_SNZero_A ) ?				R_SFTk_A.d :
								( Send_Data_A ) ?				FTk_A.d :
								( R_IndexMismatch_A ) ?			FTk_A.d :
																'0;

	//		Source-1
	assign O_FTk_B.v        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	FTk_B.v | is_Fired_Rls :
								( Send_Null_B ) ?				1'b1 :
								( Send_SNZero_B ) ?				R_SFTk_B.v :
								( Send_Data_B ) ?				FTk_B.v :
								( R_IndexMismatch_B ) ?			FTk_B.v :
																'0;
	assign O_FTk_B.a        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	FTk_B.a | is_Fired_Rls :
								( Send_Null_B ) ?				1'b0 :
								( Send_SNZero_B ) ?				R_SFTk_B.a :
								( Send_Data_B ) ?				FTk_B.a :
								( R_IndexMismatch_B ) ?			FTk_B.a :
																'0;
	assign O_FTk_B.c        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	FTk_B.c | is_Fired_Rls :
								( Send_Null_B ) ?				1'b0 :
								( Send_SNZero_B ) ?				R_SFTk_B.c :
								( Send_Data_B ) ?				FTk_B.c :
								( R_IndexMismatch_B ) ?			FTk_B.c :
																'0;
	assign O_FTk_B.r        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	FTk_B.r | is_Fired_Rls :
								( Send_Null_B ) ?				1'b0 :
								( Send_SNZero_B ) ?				R_SFTk_B.r :
								( Send_Data_B ) ?				FTk_B.r :
								( R_IndexMismatch_B ) ?			FTk_B.r :
																'0;
	assign O_FTk_B.i        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	Index_A :
								( Send_Null_B ) ?				Index_A :
								( Send_SNZero_B ) ?				Index_A :
								( Send_Data_B ) ?				FTk_B.i :
								( R_IndexMismatch_B ) ?			FTk_B.i :
																'0;
	assign O_FTk_B.d        = ( Stop_Send_Init ) ?				'0 :
								( Ready_Rls_B ) ?	FTk_B.d :
								( Send_Null_B ) ?				'0 :
								( Send_SNZero_B ) ?				R_SFTk_B.d :
								( Send_Data_B ) ?				FTk_B.d :
								( R_IndexMismatch_B ) ?			FTk_B.d :
																'0;


	//// Backward Tokens											////
	assign Nack_Capacity_A	= (( Num_A > 2'h0 ) & ( IndexMismatch_A | ( Valid_A & ~Valid_B )));
	assign Nack_Capacity_B	= (( Num_B > 2'h0 ) & ( IndexMismatch_B | ( Valid_B & ~Valid_A )));

	assign Nack_A			= ( Nack_Capacity_A & ~Nack_Capacity_B ) |
								(( Num_A == 2'h2 ) & ( Num_B < 2'h2 ) & ~Nack_Capacity_B ) |
								//(( R_Nack_A & ~Valid_B ) & ~( R_Nack_B & ~Valid_A )) |
								( R_IndexMismatch_A & ~Send_Data_A & ~Send_Data_B );

	assign Nack_B			= ( Nack_Capacity_B & ~Nack_Capacity_A ) |
								(( Num_B == 2'h2 ) & ( Num_A < 2'h2 ) & ~Nack_Capacity_A ) |
								//(( R_Nack_B & ~Valid_A ) & ~( R_Nack_A & ~Valid_B )) |
								( R_IndexMismatch_B & ~Send_Data_B & ~Send_Data_A );

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Nack_A		<= 1'b0;
		end
		else if ( Nack_A | ( Num_A == 2'h2 ) ) begin
			R_Nack_A		<= 1'b1;
		end
		else if ( Valid_B & ( Num_A == 2'h0 ) ) begin
			R_Nack_A		<= 1'b0;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Nack_B		<= 1'b0;
		end
		else if ( Nack_B | ( Num_B == 2'h2 ) ) begin
			R_Nack_B		<= 1'b1;
		end
		else if ( Valid_A & ( Num_B == 2'h0 ) ) begin
			R_Nack_B		<= 1'b0;
		end
	end

	assign O_BTk_A.n		= I_BTk_A.n | Nack | Nack_A;
	assign O_BTk_A.t		= BTk_A.t;
	assign O_BTk_A.v		= BTk_A.v;
	assign O_BTk_A.c		= BTk_A.c;

	assign O_BTk_B.n		= I_BTk_B.n | Nack | Nack_B;
	assign O_BTk_B.t		= BTk_B.t;
	assign O_BTk_B.v		= BTk_B.v;
	assign O_BTk_B.c		= BTk_B.c;


	//// Captured Shared Data										////
	assign O_SFTk_A			= R_SFTk_A;
	assign O_SFTk_B			= R_SFTk_B;


	//// Attribute Word Decoder										////
	AttributeDec AttributeDecA
	(
		.I_Data(			I_FTk_A.d					),
		.is_Pull(										),
		.is_DataWord(		is_DataWord_A				),
		.is_RConfigData(								),
		.is_PConfigData(								),
		.is_RoutingData(								),
		.is_Shared(			is_Shared_A					),
		.is_NonZero(		is_NonZero_A				),
		.is_Dense(			         					),
		.is_MyAttribute(								),
		.is_Term_Block(									),
		.is_In_Cond(									),
		.O_Length(										)
	);

	AttributeDec AttributeDecB
	(
		.I_Data(			I_FTk_B.d					),
		.is_Pull(										),
		.is_DataWord(		is_DataWord_B				),
		.is_RConfigData(								),
		.is_PConfigData(								),
		.is_RoutingData(								),
		.is_Shared(			is_Shared_B					),
		.is_NonZero(		is_NonZero_B				),
		.is_Dense(			         					),
		.is_MyAttribute(								),
		.is_Term_Block(									),
		.is_In_Cond(									),
		.O_Length(										)
	);


	//// Skip-Initialize Controllers								////
	assign O_Shared			= Shared_A & Shared_B;

	assign Send_Shared_Data	= ( W_Send_SZero_A | W_Send_SNZero_A ) & ( W_Send_SZero_B | W_Send_SNZero_B );


	SkipInit SkipInitA (
		.clock(				clock						),
		.reset(				reset						),
		.is_Valid(			I_FTk_A.v					),
		.is_AuxData(		is_DataWord_A				),
		.is_Rls(			is_Fired_Rls				),
		.is_Shared(			is_Shared_A					),
		.is_NonZero(		is_NonZero_A				),
		.is_Sent(			Send_Shared_Data			),
		.O_Ready(			ReadyInit_A					),
		.O_Store(			Store_SFTk_A				),
		.O_Zero(			O_Zero_A					),
		.O_Shared(			Shared_A					),
		.O_Send_SZero(		W_Send_SZero_A				),
		.O_Send_SNZero(		W_Send_SNZero_A				),
		.O_Run_NoShared(	Run_NoShared_A				)
	);

	SkipInit SkipInitB (
		.clock(				clock						),
		.reset(				reset						),
		.is_Valid(			I_FTk_B.v					),
		.is_AuxData(		is_DataWord_B				),
		.is_Rls(			is_Fired_Rls				),
		.is_Shared(			is_Shared_B					),
		.is_NonZero(		is_NonZero_B				),
		.is_Sent(			Send_Shared_Data			),
		.O_Ready(			ReadyInit_B					),
		.O_Store(			Store_SFTk_B				),
		.O_Zero(			O_Zero_B					),
		.O_Shared(			Shared_B					),
		.O_Send_SZero(		W_Send_SZero_B				),
		.O_Send_SNZero(		W_Send_SNZero_B				),
		.O_Run_NoShared(	Run_NoShared_B				)
	);

	assign Send_SZero_A		= IndexMismatch_A & R_SFTk_A.v;
	assign Send_SZero_B		= IndexMismatch_B & R_SFTk_B.v;

	assign Send_SNZero_A	= IndexMismatch_A & R_SFTk_A.v;
	assign Send_SNZero_B	= IndexMismatch_B & R_SFTk_B.v;


	//// Index Handler												////
	//	 Evaluation Data Word Selection
	assign W_FTk_A			= FTk_A;
	assign W_FTk_B			= FTk_B;

	//	 Validation
	assign Validation_A		= W_FTk_A.v;
	assign Validation_B		= W_FTk_B.v;

	//	 Index
	assign Index_A			= ( Run_NoShared_A ) ? '0 : W_FTk_A.i;
	assign Index_B			= ( Run_NoShared_B ) ? '0 : W_FTk_B.i;

	//	 Mismatch Detection
	assign IndexMismatch_A	= ( Index_A > Index_B ) & Validation_A & Validation_B & ReadyOp;
	assign IndexMismatch_B	= ( Index_B > Index_A ) & Validation_B & Validation_A & ReadyOp;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_IndexMismatch_A	<= 1'b0;
		end
		else begin
			R_IndexMismatch_A	<= IndexMismatch_A;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_IndexMismatch_B	<= 1'b0;
		end
		else begin
			R_IndexMismatch_B	<= IndexMismatch_B;
		end
	end

	//	 Set Ready State for Sending Shared Data Word
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Ready_SFTk_A	<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			R_Ready_SFTk_A	<= 1'b0;
		end
		else if ( IndexMismatch_A ) begin
			R_Ready_SFTk_A	<= 1'b1;
		end
		else if ( Send_Data_A ) begin
			R_Ready_SFTk_A	<= 1'b0;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Ready_SFTk_B	<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			R_Ready_SFTk_B	<= 1'b0;
		end
		else if ( IndexMismatch_B ) begin
			R_Ready_SFTk_B	<= 1'b1;
		end
		else if ( Send_Data_B ) begin
			R_Ready_SFTk_B	<= 1'b0;
		end
	end


	//// Release Handling											////
	//	 Token Decoder
	TokenDec TokenDec_A (
		.I_FTk(				I_FTk_A						),
		.O_acq_message(									),
		.O_rls_message(		rls_message_A				),
		.O_acq_flagmsg(									),
		.O_rls_flagmsg(		rls_flagmsg_A				)
	);

	TokenDec TokenDec_B (
		.I_FTk(				I_FTk_B						),
		.O_acq_message(									),
		.O_rls_message(		rls_message_B				),
		.O_acq_flagmsg(									),
		.O_rls_flagmsg(		rls_flagmsg_B				)
	);


	//// Release Token												////
	assign is_Rls_A			= I_Active & ReadyOp & ( rls_message_A | rls_flagmsg_A | ~I_EnSrcA );
	assign is_Rls_B			= I_Active & ReadyOp & ( rls_message_B | rls_flagmsg_B | ~I_EnSrcB );

	//	 Firing of Release Token
	assign is_Fired_Rls		= R_Rls_A & R_Rls_B & O_FTk_A.r & O_FTk_B.r & ~BTk_A.n & ~BTk_B.n;

	//	 Capture Release Token
	//	 Needed for Firing the Release when Block Length is Different
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rls_A			<= 1'b0;
		end
		else if ( is_Fired_Rls )  begin
			R_Rls_A			<= 1'b0;
		end
		else if ( is_Rls_A ) begin
			R_Rls_A			<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rls_B			<= 1'b0;
		end
		else if ( is_Fired_Rls )  begin
			R_Rls_B			<= 1'b0;
		end
		else if ( is_Rls_B ) begin
			R_Rls_B			<= 1'b1;
		end
	end

	assign is_Ready_Rls_A	= R_Rls_A & Send_Data_A;
	assign is_Ready_Rls_B	= R_Rls_B & Send_Data_B;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Ready_Rls_A		<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			Ready_Rls_A		<= 1'b0;
		end
		else if ( is_Ready_Rls_A ) begin
			Ready_Rls_A		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Ready_Rls_B		<= 1'b0;
		end
		else if ( is_Fired_Rls ) begin
			Ready_Rls_B		<= 1'b0;
		end
		else if ( is_Ready_Rls_B ) begin
			Ready_Rls_B		<= 1'b1;
		end
	end

endmodule
