///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Top Module for Most Frequently Appeared (MFA) Unit
//	Module Name:	MFA_CRAM
//	Function:
//					Top Module for Index Compression in CRAM
//					This unit is used for extension; Index-Compression.
//					The extension find most frequently appeared value.
//					The value is removed from the data block,
//						and treated as a shared data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MFA_CRAM
	import	pkg_en::*;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input	FTk_t					I_Ld_Bps,			//Load for Restoring
	input	FTk_t					I_Ld_FTk,			//Load Config. Data from StLdCRAM
	output	BTk_t					O_Ld_BTk,			//to StLdCRAM
	output	FTk_t					O_Ld_FTk,			//to Ld_CRAM
	input	BTk_t					I_Ld_BTk,			//from StLdCRAM
	input							I_End_Ld,			//Flag: End of Loading
	input							I_Ld_End,			//End of Access for Loadig
	input	FTk_t					I_St_FTk,			//Store Config. Data from StLdCRAM
	output	BTk_t					O_St_BTk,			//from StLdCRAM
	output	FTk_t					O_St_FTk,			//to St_CRAM
	input	BTk_t					I_St_BTk,			//to StLDCRAM
	input							I_End_St,			//Flag: End of Storing
	input							I_St_End,			//End of Access for Storing
	input	[WIDTH_INDEX-1:0]		I_Index,			//Write Index Val
	output	logic					is_SharedAttrib,	//Flag: Share Indicator in Attrib Word
	output	logic					is_SharedConfig,	//Flag: Share Command in RConfig
	output	logic					O_Busy_MFA,			//Flag: Busy State on MFA unit
	output	logic 					O_Str_Restore,		//Flag: Start Restoring
	output	logic					O_Run_Restore,		//Flag: State in Restoring
	output	logic					O_NeLoad,			//Flag: Not-Enable Loading
	output	logic					O_Next_Restore,		//Flag: Next is Restore
	output	logic					O_Shared_Valid,		//Flag: Sharing is Valid
	output	[WIDTH_DATA-1:0]		O_Shared_Data,		//Shared Data Word (Value)
	output	[WIDTH_LENGTH-1:0]		O_LengthAttrib,		//Block=length
	output	logic					O_is_NotZero		//Flag: Non-Zero
);


	localparam int WIDTH_ADDR	= WIDTH_LENGTH-2;
	localparam int LENGTH_MEM	= 2**WIDTH_ADDR;
	localparam int WIDTH_VAL	= $clog2(WIDTH_LENGTH)+1;


	//// MFA Unit													////
	//	 Enable working on MFA Unit
	logic						En_MFA;
	logic						Run_Restore;
	logic						NeLoad;
	logic						Next_Restore;
	logic						Busy_MFA;

	//	 Read MFA Unit
	logic						Rd_MFA;


	//// Sharing Attribution										////
	logic						is_NonZero;
	logic						is_Dense;


	//// Attribution Length											////
	//	 Length at Storing
	logic [WIDTH_LENGTH+1:0]	LengthAttrib;

	//	 Length at R-Config Data
	logic [WIDTH_LENGTH-1:0]	LengthConfig;

	//	 Length for Loading
	logic [WIDTH_LENGTH-1:0]	LengthAttrib_Ld;


	//// Shared Data												////
	//	 Check Matching between Shared Data Word and MFA Shared Word
	logic						is_Matched_SharedWord;

	//	 MFA Count Val is Greater than Length in Attribute Word in Data BlockS
	logic						is_Gt_LengthConfigAttrib;

	//	 Capture Shared Data Word at Storing
	logic						Set_SharedWord;

	//	 Shared Data at Storing
	logic [WIDTH_DATA-1:0]		Shared_Data_St;

	//	 Shared Data from MFA
	logic [WIDTH_DATA-1:0]		Shared_Data_MFA;

	//	 Shared Data for Loading
	logic [WIDTH_DATA-1:0]		Shared_Data_Ld;


	//// Store Counter												////
	//	 Enable to Count
	logic						En_Cnt_Stores;

	//	 Number of Stores for Sharing
	logic [WIDTH_LENGTH-1:0]	Num_Stores;

	//	 Output from MFA Controller
	FTk_t						Ld_FTk;


	//// Configuration Data											////
	//	 Control
	logic						Str_St_Cfg;

	//	 Flag: Snooping Attribute Word
	logic						Snoop_AttribRCfg;
	logic						Snoop_AttribData;

	//	 Flag: Start Configuration
	logic						Str_Snoop;

	//	 Flag: End of Configuration
	logic						End_Snoop;

	//	 Flag: Start Read Configuration
	logic						Str_Rd_Cfg;

	//	 Flag: End of Read Configuration
	logic						End_Rd_Cfg;

	//	 Path
	FTk_t						Cfg_FTk;


	//// MFA Workers												////
	//	 Number of MFA Values
	logic [WIDTH_LENGTH-1:0]	MFA_CountVal;
	logic						MFA_Valid;
	logic						MFA_End;


	//// MFA Controller												////
	FTk_t						St_FTk;
	logic						Sel_St;


	//// Check Matched												////
	logic						is_Matched;


	//// FOrce Termination											////
	logic						Forse_Term_Ld;


	//// Retime Input												////
	FTk_t						W_Ld_FTk;
	BTk_t						W_Ld_BTk;
	BTk_t						C_Ld_BTk;


	//// Caputure Signal											////
	logic						R_En_Compress;

	FTk_t						R_St_FTk;
	BTk_t						R_St_BTk;

	FTk_t						R_Ld_Bps;

	logic						R_End_Ld;
	logic						R_End_Load;

	logic						R_End_St;
	logic						R_End_Store;

	logic [WIDTH_INDEX-1:0]		R_Index;


	//// Shared Data Word											////
	assign O_Shared_Valid	= MFA_CountVal > '0;
	assign O_Shared_Data	= Shared_Data_Ld;
	assign O_is_NotZero		= Shared_Data_Ld != '0;


	//// Index Write in IMEM										////
	//	 Send to Load Unit
	assign O_Ld_FTk.v		= Ld_FTk.v;
	assign O_Ld_FTk.a		= Ld_FTk.a;
	assign O_Ld_FTk.c		= Ld_FTk.c;
	assign O_Ld_FTk.r		= Ld_FTk.r;
	assign O_Ld_FTk.i		= ( is_SharedConfig ) ? R_Index : '0;
	assign O_Ld_FTk.d		= Ld_FTk.d;

	assign En_Cnt_Stores	= Busy_MFA & R_St_FTk.v;


	//// Capture Loading Word										////
	DReg R_Ld(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_Ld_FTk					),
		.I_BTk(				I_Ld_BTk					),
		.O_FTk(				W_Ld_FTk					),
		.O_BTk(				C_Ld_BTk					)
	);


	//// Capture Input Signals										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_Load		<= 1'b0;
		end
		else begin
			R_End_Load		<= I_Ld_End;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_St_FTk		<= '0;
		end
		else begin
			R_St_FTk		<= I_St_FTk;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_St_BTk		<= '0;
		end
		else begin
			R_St_BTk		<= I_St_BTk;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_Store		<= 1'b0;
		end
		else begin
			R_End_Store		<= R_Ld_Bps.r;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_St		<= 1'b0;
		end
		else begin
			R_End_St		<= I_End_St;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Index			<= '0;
		end
		else begin
			R_Index			<= I_Index;
		end
	end


	//// Flag: Busy State on MFA									////
	//	 High: MFA Detector runs
	//	 NOTE: MFA CTRL can run after end of detector run
	assign O_Busy_MFA		= Busy_MFA;


	//// Forse termination of the loading when						////
	//	 Loading is not ended after storing is ended
	assign Forse_Term_Ld	= R_End_St & ~R_End_Ld & Busy_MFA;


	//// Shared Data												////
	//	 Shared_Data_St:	Shared Data at Storing Sequence (comming from extern)
	//	 Shared_Data_MFA:	Detected Shared Data Candidate by MFA detector
	assign is_Matched_SharedWord	= Shared_Data_MFA == Shared_Data_St;
	assign is_Gt_LengthConfigAttrib	= MFA_CountVal > ( LengthConfig - LengthAttrib );

	//	 Attribution Block Length embedded in Attribution Word used for loading
	assign LengthAttrib_Ld	= (   MFA_Valid & ~is_Matched_SharedWord &  is_Gt_LengthConfigAttrib ) ?	LengthConfig - MFA_CountVal :
								( MFA_Valid & ~is_Matched_SharedWord & ~is_Gt_LengthConfigAttrib ) ?	Num_Stores :
								( MFA_Valid &  is_Matched_SharedWord ) ?								LengthAttrib - MFA_CountVal :
																										'0;
	assign O_LengthAttrib	= LengthAttrib_Ld;

	//	 Shared Data Word used for loading
	assign Shared_Data_Ld	= (   MFA_Valid & ~is_Matched_SharedWord &  is_Gt_LengthConfigAttrib ) ?	Shared_Data_MFA :
								( MFA_Valid & ~is_Matched_SharedWord & ~is_Gt_LengthConfigAttrib ) ?	Shared_Data_St :
								( MFA_Valid &  is_Matched_SharedWord ) ?								Shared_Data_St :
																										'0;


	//// Backward Tokens											////
	//	 Ld_CRAM
	assign O_Ld_BTk.n		= I_Ld_BTk.n | Sel_St;// | Busy_MFA;
	assign O_Ld_BTk.t		= I_Ld_BTk.t | Forse_Term_Ld;
	assign O_Ld_BTk.v		= I_Ld_BTk.v;
	assign O_Ld_BTk.c		= I_Ld_BTk.c;


	//// Store Data Word to Memory									////
	assign O_Run_Restore	= Run_Restore;
	assign O_NeLoad			= NeLoad;
	assign O_Next_Restore	= Next_Restore;

	//	 Match Detection
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			is_Matched		<= 1'b0;
		end
		else begin
			is_Matched		<= MFA_Valid & ( I_Ld_Bps.d == Shared_Data_Ld );
		end
	end

	//	 Send Tokens to Store unit when NOT Mached or
	//		Common Storing
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Ld_Bps		<= '0;
		end
		else begin
			R_Ld_Bps		<= I_Ld_Bps;
		end
	end

	//	 Send to Store Unit
	assign O_St_FTk.v		= (  is_Matched & R_En_Compress ) ?		1'b0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.v :
																	St_FTk.v;

	assign O_St_FTk.a		= (  is_Matched & R_En_Compress ) ?		1'b0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.a :
																	St_FTk.a;

	assign O_St_FTk.c		= (  is_Matched & R_En_Compress ) ?		1'b0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.c :
																	St_FTk.c;

	assign O_St_FTk.r		= (  is_Matched & R_En_Compress ) ?		1'b0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.r :
																	St_FTk.r;

	assign O_St_FTk.i		= (  is_Matched & R_En_Compress ) ?		'0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.i :
																	St_FTk.i;

	assign O_St_FTk.d		= (  is_Matched & R_En_Compress ) ?		'0 :
								( ~is_Matched & R_En_Compress ) ?	R_Ld_Bps.d :
																	St_FTk.d;


	//// Steering of of Restoring									////
	//	 Check Storing is ended before the loading
	//	 When both of loading and storing ended, restoring is completed
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_Ld		<= 1'b0;
		end
		else if ( MFA_End ) begin
			R_End_Ld		<= 1'b0;
		end
		else if ( R_End_Ld ) begin
			R_End_Ld		<= 1'b1;
		end
	end


	//// Enable to Compress											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_En_Compress	<= 1'b0;
		end
		else if ( R_Ld_Bps.r ) begin
			R_En_Compress	<= 1'b0;
		end
		else if ( Sel_St & ~MFA_End ) begin
			R_En_Compress	<= 1'b1;
		end
	end


	//// Store Address Generation									////
	//	 This counter is used when;
	//		- R-Config takes "sharing" high
	//		- Attribute Word takes "shared" high
	Counter #(
		.WIDTH_COUNT(		WIDTH_LENGTH				)
	) ST_Counter
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_En(				En_Cnt_Stores				),
		.I_Clr(				Str_Rd_Cfg					),
		.O_Val(				Num_Stores					)
	);


	//// Most Significantly Appeared (MFA) Value Detector			////
	//	 Configuration Date Snoop and Provide
	MFA_CfgGen MFA_CfgGen (
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				R_St_FTk					),
		.I_Snoop_AttribRCfg(Snoop_AttribRCfg			),
		.I_Str_Snoop(		Str_Snoop					),
		.O_End_Snoop(		End_Snoop					),
		.I_Snoop_AttribData(Snoop_AttribData			),
		.I_Str_Rd(			Str_Rd_Cfg					),
		.O_End_Rd(			End_Rd_Cfg					),
		.I_End_Store(		R_End_Store					),
		.I_End_Load(		R_End_Load					),
		.O_FTk(				Cfg_FTk						),
		.is_SharedConfig(	is_SharedConfig				),
		.is_SharedAttrib(	is_SharedAttrib				),
		.is_NonZero(		is_NonZero					),
		.is_Dense(			is_Dense					),
		.I_Set_SData(		Set_SharedWord				),
		.O_SharedData(		Shared_Data_St				),
		.O_LengthData(		LengthAttrib				),
		.O_LengthConfig(	LengthConfig				)
	);

	//	 MFA Workers
	MFAUnit #(
		.LENGTH(			LENGTH_MEM					)
	) MFAUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_En(				Busy_MFA					),
		.I_Rd_MFA(			Rd_MFA						),
		.I_Rls(				R_St_FTk.r					),
		.I_Valid(			R_St_FTk.v					),
		.I_Data(			R_St_FTk.d					),
		.O_Valid(			MFA_Valid					),
		.O_SharedData(		Shared_Data_MFA				),
		.O_CountVal(		MFA_CountVal				)
	);

	//	 MFA Controller
	MFA_CTRL MFA_CTRL (
		.clock(				clock						),
		.reset(				reset						),
		.I_Cfg_FTk(			Cfg_FTk						),
		.I_Ld_FTk(			I_Ld_FTk					),
		.O_Ld_FTk(			Ld_FTk						),
		.I_Ld_BTk(			I_Ld_BTk					),
		.O_Ld_BTk(			W_Ld_BTk					),
		.I_Ld_End(			R_End_Load					),
		.I_St_FTk(			R_St_FTk					),
		.O_St_FTk(			St_FTk						),
		.I_St_BTk(			R_St_BTk					),
		.O_St_BTk(			O_St_BTk					),
		.I_St_End(			R_End_Store					),
		.O_Snoop_AttribRCfg(Snoop_AttribRCfg			),
		.O_Str_Snoop(		Str_Snoop					),
		.I_End_Snoop(		End_Snoop					),
		.O_Snoop_AttribData(Snoop_AttribData			),
		.is_SharedAttrib(	is_SharedAttrib				),
		.is_SharedConfig(	is_SharedConfig				),
		.O_Str_Rd(			Str_Rd_Cfg					),
		.I_End_Rd(			End_Rd_Cfg					),
		.O_En_MFA(			En_MFA						),
		.O_Rd_MFA(			Rd_MFA						),
		.O_Sel_St(			Sel_St						),
		.O_Set_SData(		Set_SharedWord				),
		.O_Busy_MFA(		Busy_MFA					),
		.O_Str_Restore(		O_Str_Restore				),
		.O_Run_Restore(		Run_Restore					),
		.O_NeLoad(			NeLoad						),
		.O_Next_Restore(	Next_Restore				),
		.O_End_MFA(			MFA_End						)
	);

endmodule