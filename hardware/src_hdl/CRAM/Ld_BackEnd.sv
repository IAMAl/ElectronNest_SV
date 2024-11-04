///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load Server Unit (Back-End)
//		Module Name:	Ld_BackEnd
//		Function:
//						Serves Loading Data and Sends Data.
//						Top Module of Back-End Part in Load Unit
//						Service is kicked start by Front-End Server unit.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Ld_BackEnd
	import pkg_en::FTk_t;
	import pkg_en::BTk_t;
	import pkg_en::WIDTH_DATA;
	import pkg_en::POSIT_ATTRIB_TERM_BLOCK;
	import pkg_en::POSIT_MEM_CONFIG_INDIRECT;
#(
	parameter int EXTERNAL			= 1,
	parameter int WIDTH_ADDR		= 8,
	parameter int WIDTH_LENGTH		= 8,
	parameter int BUFF_SIZE			= 8
)(
	input							clock,
	input							reset,
	input							I_Boot,
	input	    					I_Req_BackEnd,		//Kick Start Sequence
	input	[3:0]					I_MetaData,			//Meta Data from FrontEnd
	input	FTk_t					I_FTk,				//Data from FrontEnd
    output	FTk_t					O_FTk,				//Output FTk
    input 	BTk_t					I_BTk,				//Input BTk
	input	FTk_t					I_Ld_FTk,			//Loaded Data
	output	BTk_t					O_Ld_BTk,			//Send BTk to Loading Source
    input	[WIDTH_DATA-1:0]		I_MyID,				//MyID used for Indirect-Access
    input	[WIDTH_DATA-1:0]		I_ID_T,				//MyID used for Indirect-Access
    input	[WIDTH_DATA-1:0]		I_ID_F,				//MyID used for Indirect-Access
	input	[WIDTH_DATA-1:0]		I_AttribWord,		//Attribute WOrd for R-Config Block
	input	[WIDTH_DATA-1:0]		I_RConfig,			//R-Config Data
	input	[WIDTH_LENGTH-1:0]		I_Length,			//Access-Length
	input	[WIDTH_ADDR-1:0]		I_Stride,			//Stride Factor
	input	[WIDTH_ADDR-1:0]		I_Base,				//Base Address
	input							I_Bypass,			//Flag: Bypass
	input	FTk_t					I_Bypass_FTk,		//Bypass Data
	output	BTk_t					O_Bypass_BTk,		//Back-Prop Tokens for Stall
	input							is_Zero,			//Flag: Shared Data is Zero
	input							is_Shared,			//Flag SBlock has hared Data:
	input	[WIDTH_DATA-1:0]		I_Shared_Data,		//Shared Value
	output	[WIDTH_ADDR+2:0]		O_ReqLoad,			//Ld-Req, Access-Mode, Address
    output							O_is_Ack_BackEnd,	//Ack to FrontEnd
	output	FTk_t					O_Ld_FTk,			//Send Loaded Data to FrontEnd
	output	logic					O_Req_Stall,		//Req to Buffer
	output	logic					O_is_Term_Load,		//Flag: End of Loading
    output	logic					O_is_Matched,		//Flag: is_Matched used for Indirect-Access
	output	logic					O_is_Term_BTk,		//Flag: Termination by I_BTk.t
	output	logic					O_is_End_Rename,	//Flag: End of Indirec-Access Service
	output	logic					O_Read_Buff,		//Req-Request to Buffer
	output	logic					O_Busy				//Flag: Busy Status
);

	localparam int WIDTH_BUFF		= $clog2(BUFF_SIZE);
	logic							Extern;

	assign Extern					= EXTERNAL;


	//// Connecting Logic											////
	//	 Loading Event Detection
	logic							Event_Load;

	//	 State in Controller
	logic							is_Start_Load;
	logic							is_StoredIDs;
	logic							is_Descrement;
	logic							is_IndirectMode;
	logic							is_Data_Block;

	// Buffer
	//	Common Buffer
	logic							We_Buff_Req;
	logic							Re_Buff_Req;
	logic							We_Buff_Data;
	logic							Re_Buff_Data;

	logic							Buff_Full_Req;
	logic							Buff_Empty_Req;
	logic							Buff_Full_Data;
	logic							Buff_Empty_Data;

	FTk_t							W_Ld_FTk;
	BTk_t							W_Ld_BTk;

	//	Load Buffer
	logic							We_Buff_Req_Ld;
	logic							Re_Buff_Req_Ld;
	logic							We_Buff_Data_Ld;
	logic							Re_Buff_Data_Ld;

	logic							Buff_Empty_Req_Ld;
	logic							Buff_Full_Data_Ld;
	logic							Buff_Full_Req_Ld;
	logic							Buff_Empty_Data_Ld;

	//	 LOaded Data
	FTk_t							W_Ld_FTk_Ld;

	//	 Output
	FTk_t							W_FTk;
	BTk_t							W_BTk;
	FTk_t							Send_FTk;

	logic							Stall;
	logic							LoadIDs;
	logic							Test_First_Load;
	logic							Set_RConfig;

	//	 Check Tag used for Indirect-Access (Extension)
	logic							Check_Match;
	logic							is_Matched;

	//	 End of Back-End Service
	logic							End_BackEnd;

	//	 AGU
	logic							En_AddrGen;
	logic							Term_AddrGen;

	//	 Context-Switch
	logic							Write_Switch;
	logic							Read_Switch;

	//	 End of Storing R-Config Data Block
	logic							End_RConfig;

	//	 Access-Mode for Loading
	logic	[1:0]					AccessMode;

	//	 Address for Loading
	logic	[WIDTH_ADDR-1:0]		Address;

	//	 Access-Request, Access-Mode, Address
	logic	[WIDTH_ADDR+2:0]		ReqLoad;
	logic	[WIDTH_ADDR+2:0]		W_ReqLoad;
	logic	[WIDTH_ADDR+2:0]		W_ReqLoad_Ld;

	//	 Attribute WOrd for Loaded Data Block
	FTk_t							AttributeWord;


	//	 R-Config Data Composition for Input to Decoder
	logic							Set_Config;
	FTk_t							RConfigData;

	logic							We_RConfig;
	logic	[WIDTH_DATA-1:0]		W_Length;
	logic	[WIDTH_DATA-1:0]		W_Stride;
	logic	[WIDTH_DATA-1:0]		W_Base;

	logic	[WIDTH_DATA-1:0]		B_RConfig;
	logic	[WIDTH_DATA-1:0]		B_Length;
	logic	[WIDTH_DATA-1:0]		B_Stride;
	logic	[WIDTH_DATA-1:0]		B_Base;

	//	 Access-Length
	logic							Set_Length;
	logic	[WIDTH_LENGTH+1:0]		Length;
	logic	[WIDTH_LENGTH+1:0]		Length_Ld;
	logic	[WIDTH_ADDR:0]			C_Length;

	//	 Attribute Word
	logic							is_AttributeWord;
	logic							is_RConfigData;
	logic							is_RoutingData;
	logic							is_MyAttribute;
	logic							is_Term_Block;
	logic							is_End_Term_Block;

	//	 End of Block
	logic							is_End_Block;

	//	 End of Terminal Block
	logic							End_Terimanl_Block;



	//	 Set RElease Token for Loaded Block
	logic							Set_Load_Rls;

	logic							LdCTRL_Sleep;
	logic							LdCTRL_Run;

	FTk_t							W_Ld_FTk_Out;

	//	 Cancel Buffer-REad
	logic							Cancel_Req;
	logic							Cancel_Req_Ld;

	logic							Set_RConfig_Ld;
	logic							Set_AttribWord;

	logic							Tail_Load;
	logic							Tail_Load_Ld;

	logic							is_End_Load;
	logic							Data_Load;

	FTk_t							Ld_FTk;
	logic							is_MyID;

	FTk_t							Ld_FTk_Ld;

	logic							R_RNo;

	logic	[WIDTH_BUFF:0]			Buff_Num_Data;

	logic							Valid;
	logic							Bypass;

	FTk_t							W_AttribWord;
	FTk_t							B_AttribWord;

	logic							CTRL_Valid;
	logic							Stall_Input;


	logic							Block_is_Terminated;
	logic							Start_LoadCTRL;
	logic							First_Load;

	//	 State in Busy
	logic							Busy;

	//	 RouteGen
	logic							Start_RouteGen;
	logic							Send_RouteGen;
	logic							SendRetarget;
	FTk_t							FTk_RouteGen;
	logic							Send_RCfgShared;
	logic							is_End_Rename;
	logic							Stall_RouteGen;

	logic							Nack_Bar_Pulse;

	logic							is_Load;
	logic							is_Rls;

	FTk_t							W_Bypass_FTk;
	logic							Set_Attrib_by_IAccess;
	logic							Set_Acq;

	logic							is_Indirect;

	logic							Send_B_AttribWord;
	logic							Send_W_AttribWord;
	logic							Send_AttribWord;
	logic							Send_Bypass;
	logic							Send_IDs;
	logic							Load;
	logic							No_Nack;
	logic							Activate_SysLd;
	logic							Activate_Load;
	logic							Remove_is_Term;
	logic	[WIDTH_DATA-1:0]		RM_FTk_d;

	logic							Make_Share;
	logic							Send_Shared;
	FTk_t							Shared_Data;
	logic							is_Loaded;

	logic	[WIDTH_BUFF:0]			Num;
	logic							Buff_Full;

	logic							End_Term_Block;


	//// Caprturing Logic											////
	logic							R_Boot;
	logic	[WIDTH_DATA-1:0]		R_MyID;

	FTk_t							R_Dst_FTk;

	logic	[WIDTH_DATA-1:0]		R_AttribWord;
	logic	[WIDTH_DATA-1:0]		R_RConfig;
	logic	[WIDTH_DATA-1:0]		R_Length;
	logic	[WIDTH_DATA-1:0]		R_Stride;
	logic	[WIDTH_DATA-1:0]		R_Base;

	//	 State in Busy
	logic							R_Busy;

	//	 State in Buffers　あれFull
	logic							R_Buff_Full;

	logic							R_is_Ack_BackEnd;
	logic							R_Term_AddrGen;

	logic							R_is_Matched;

	logic	[WIDTH_ADDR+2:0]		R_ReqLoad;

	logic							R_is_Term;

	logic							R_BTk_n;
	logic							BTk_nD2;

	logic							R_Set_AttribWord;
	logic							R_Send_Attribute;

	logic							R_Cancel_Req;

	logic							R_Bypass;
	logic							R_LoadIDs;

	logic							R_is_Rls;


	//// Read-Request to Buffer										////
	assign O_Read_Buff		= ( LoadIDs | ~Busy ) & ~W_Ld_BTk.n;


	//// Send to FrontEnd											////
	assign O_Ld_FTk			= ( Load ) ?	W_FTk :
											'0;

	// End of Sequence
	assign O_is_Term_Load	= R_Term_AddrGen;

	// Stall Request to FrontEnd
	assign O_Req_Stall		= Buff_Full;

	// Termination by Term Token
	assign O_is_Term_BTk	= W_Ld_BTk.t;

	// Ack to FrontEnd
	assign O_is_Ack_BackEnd	= R_is_Ack_BackEnd;
	assign O_is_Matched		= R_is_Matched;


	//// Output														////
	assign W_Bypass_FTk.v	= I_Bypass_FTk.v;
	assign W_Bypass_FTk.a	= I_Bypass_FTk.a & ~I_Bypass_FTk.r;
	assign W_Bypass_FTk.c	= I_Bypass_FTk.c;
	assign W_Bypass_FTk.r	= 1'b0;
	assign W_Bypass_FTk.d	= I_Bypass_FTk.d;
	assign W_Bypass_FTk.i	= I_Bypass_FTk.i;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Bypass		<= 1'b0;
			R_LoadIDs		<= 1'b0;
		end
		else begin
			R_Bypass		<= I_Bypass;
			R_LoadIDs		<= LoadIDs & ~W_Ld_BTk.n;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Rls		<= 1'b0;
		end
		else begin
			R_is_Rls		<= Re_Buff_Data_Ld;
		end
	end


	assign Set_Attrib_by_IAccess	= R_Bypass & ~I_Bypass & R_is_Matched;

	assign O_FTk			= Send_FTk;

	assign O_Bypass_BTk		= I_BTk;

	assign O_is_End_Rename	= is_End_Rename;


	//// Output Token to Loading Source								////
	assign O_Ld_BTk.n		= R_Buff_Full;
	assign O_Ld_BTk.t		= 1'b0;
	assign O_Ld_BTk.v		= 1'b0;
	assign O_Ld_BTk.c		= 1'b0;


	//// Output Load-Req, Access-Mode, Address						////
	assign O_ReqLoad		= R_ReqLoad;


	//// State in Busy												////
	assign O_Busy			= Busy;


	//// Logic														////
	assign CTRL_Valid		= ( ( W_FTk.v | ( LoadIDs & I_FTk.v ) | I_Ld_FTk.v ) & ~Check_Match ) | ( W_Ld_FTk_Ld.v & Check_Match );
	assign is_Rls			= Send_FTk.v & Send_FTk.a & Send_FTk.r;

	assign is_Loaded		= ( W_FTk.v & ~Check_Match ) | ( W_Ld_FTk_Ld.v & Check_Match );


	assign Valid			= ( Data_Load & ~Set_RConfig_Ld & ~End_RConfig ) ? W_Ld_FTk_Ld.v : W_Ld_FTk.v;

	// Sending Data
	assign Send_FTk.v		= W_FTk.v;
	assign Send_FTk.a		= W_FTk.a | Set_Acq;
	assign Send_FTk.c		= W_FTk.c;
	assign Send_FTk.r		= W_FTk.r;
	assign Send_FTk.d		= W_FTk.d;
	assign Send_FTk.i		= W_FTk.i;

	// Buff Status
	assign Buff_Full		= Buff_Full_Req | Buff_Full_Data | Buff_Full_Req_Ld | Buff_Full_Data_Ld;

	// Stall Info
	assign Stall			= Buff_Full | I_BTk.n | R_BTk_n;


	//// Parsing Attribute Word										////
	assign is_Start_Load	= I_Req_BackEnd;
	assign is_StoredIDs		= I_MetaData[2];
	//assign is_Shared		= I_MetaData[1];
	assign is_Data_Block	= I_MetaData[0];


	//// Cancel Reading Buffer										////
	assign Cancel_Req		= Tail_Load | ( is_End_Block & Event_Load );
	assign Cancel_Req_Ld	= Tail_Load_Ld;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			BTk_nD2		<= 1'b0;
		end
		else begin
			BTk_nD2		<= W_Ld_BTk.n;
		end
	end

	assign Nack_Bar_Pulse	= W_BTk.n & ~W_Ld_BTk.n & BTk_nD2;


	//// Buffer Control												////
	assign No_Nack			= ~W_Ld_BTk.n & ~Nack_Bar_Pulse;

	assign Activate_SysLd	= ~LdCTRL_Run & Busy & ~End_RConfig;
	assign We_Buff_Req		= Activate_SysLd & ~Data_Load & ~Buff_Full_Req & ~Buff_Full_Data & ~Term_AddrGen & ~Cancel_Req &
								~( ~R_ReqLoad[WIDTH_ADDR+2] & is_AttributeWord & ~First_Load ) | ( Term_AddrGen & ~Extern );
	assign Re_Buff_Req		= Activate_SysLd & ~Buff_Full_Data & ~Buff_Empty_Req;
	assign We_Buff_Data		= ~LdCTRL_Run & ~R_Boot & I_Ld_FTk.v;
	assign Re_Buff_Data		= ( Activate_SysLd & ~Buff_Empty_Data & No_Nack ) |
								( Busy & R_Cancel_Req & No_Nack );


	//// Buffer Control												////
	assign Activate_Load	= LdCTRL_Run & Busy & ~End_RConfig;
	assign We_Buff_Req_Ld	= Activate_Load & ~Buff_Full_Req_Ld & ~Buff_Full_Data_Ld & ~Cancel_Req_Ld;
	assign Re_Buff_Req_Ld	= Activate_Load & ~Buff_Full_Data_Ld & ~Buff_Empty_Req_Ld & ~I_Bypass;
	assign We_Buff_Data_Ld	= Activate_Load & I_Ld_FTk.v;
	assign Re_Buff_Data_Ld	= Activate_Load & ~Buff_Empty_Data_Ld & ~Set_AttribWord & No_Nack & ~I_Bypass;


	//// Indirect-Access (Extension)								////
	assign is_Matched		= Check_Match & W_Ld_FTk_Ld.v & ( W_Ld_FTk_Ld.d == R_MyID );


	//// Address Generatin Unit										////
	assign En_AddrGen		= (
								( Busy & (
										( LdCTRL_Run & is_IndirectMode ) |
										( Data_Load & ~Set_RConfig_Ld ) |
										( First_Load & ( ~Buff_Empty_Req | ~Buff_Empty_Req_Ld ) )
									) & ~W_BTk.n
								) |
								Test_First_Load ) &
								~Buff_Full & ~( Cancel_Req | Cancel_Req_Ld ) |
								( R_Term_AddrGen & ~Extern );


	//// Send to Buffer												////
	assign ReqLoad			= ( We_Buff_Req | We_Buff_Req_Ld | ( Term_AddrGen & ~Extern ) ) ? { En_AddrGen, AccessMode, Address } : '0;


	//// Input to Output Register									////
	assign W_BTk			= I_BTk;

	assign Length_Ld		= ( Bypass ) ?		I_Length :
								( Data_Load ) ? B_Length[WIDTH_ADDR-1:0] :
												I_Length | Length[WIDTH_ADDR-1:0];


	//// Select Input for AGU										////
	assign W_Length			= ( Set_RConfig ) ? 0 | I_Length	: B_Length;
	assign W_Stride			= ( Set_RConfig ) ? 0 | I_Stride	: B_Stride;
	assign W_Base			= ( Set_RConfig ) ? 0 | I_Base		: B_Base;


	//// Composite R-Config Data for Its Decoding					////
	assign RConfigData.v	= 1'b0;
	assign RConfigData.a	= 1'b0;
	assign RConfigData.r	= 1'b0;
	assign RConfigData.c	= 1'b0;
	assign RConfigData.d	= R_RConfig;
	assign RConfigData.v	= '0;


	//// Attribute Word for Loading Data Block						////
	assign AttributeWord.v	= 1'b1;
	assign AttributeWord.a	= 1'b0;
	assign AttributeWord.c	= 1'b0;
	assign AttributeWord.r	= 1'b0;
	assign AttributeWord.d	= {4'h0, is_Shared, I_Shared_Data != 0, 10'h00, B_Length[7:0], 8'h00};
	assign AttributeWord.i	= '0;

	assign Shared_Data.v	= is_Shared;
	assign Shared_Data.a	= 1'b0;
	assign Shared_Data.c	= 1'b0;
	assign Shared_Data.r	= 1'b0;
	assign Shared_Data.d	= I_Shared_Data;
	assign Shared_Data.i	= '0;


	//// Loading Event Detection									////
	assign Event_Load		= is_AttributeWord & is_MyAttribute & is_RConfigData & Busy;


	//// Set AGU Config												////
	assign Set_Config		= Set_RConfig | Read_Switch;


	//// Switch Context												////
	assign Write_Switch		= ( Event_Load & LdCTRL_Sleep ) | is_End_Load;
	assign Read_Switch		= End_RConfig | is_End_Load;


	//// Set Release for Loading									////
	assign Set_Load_Rls		= ( is_End_Term_Block & ~Set_RConfig_Ld ) |
								( R_is_Term & ( Buff_Num_Data == 1 ) & W_Ld_FTk.v );


	////
	assign End_Term_Block	= is_End_Term_Block & LdCTRL_Run;


	//// Input to Output Register									////
	assign Remove_is_Term	= is_AttributeWord & is_Term_Block;
	assign RM_FTk_d			= {
									W_Ld_FTk.d[WIDTH_DATA-1:POSIT_ATTRIB_TERM_BLOCK+1],
									1'b0,
									W_Ld_FTk.d[POSIT_ATTRIB_TERM_BLOCK-1:0]
								};
	assign Ld_FTk.v			= W_Ld_FTk.v;
	assign Ld_FTk.a			= W_Ld_FTk.a | Set_Load_Rls | ( is_MyID & ~Bypass );
	assign Ld_FTk.c			= W_Ld_FTk.c;
	assign Ld_FTk.r			= W_Ld_FTk.r | Set_Load_Rls;
	assign Ld_FTk.d			= ( Remove_is_Term ) ?	RM_FTk_d :
													W_Ld_FTk.d;
	assign Ld_FTk.i			= W_Ld_FTk.i;

	assign Ld_FTk_Ld.v		= W_Ld_FTk_Ld.v;
	assign Ld_FTk_Ld.a		= W_Ld_FTk_Ld.a | is_End_Load | Set_Load_Rls;
	assign Ld_FTk_Ld.c		= W_Ld_FTk_Ld.c;
	assign Ld_FTk_Ld.r		= W_Ld_FTk_Ld.r | is_End_Load | Set_Load_Rls;
	assign Ld_FTk_Ld.d		= W_Ld_FTk_Ld.d;
	assign Ld_FTk_Ld.i		= W_Ld_FTk_Ld.i;

	assign Send_B_AttribWord= Send_AttribWord & ~R_BTk_n & Bypass;

	assign Send_W_AttribWord= Set_AttribWord & ~R_BTk_n & ~is_IndirectMode;

	assign Send_Bypass		= I_Bypass | Check_Match;

	assign Send_IDs			= LoadIDs;

	assign W_Ld_FTk_Out		=( Send_IDs ) ?					I_FTk :
								( Send_Bypass ) ?			W_Bypass_FTk :
								( Send_RouteGen ) ?			FTk_RouteGen :
								( Send_Shared ) ?			Shared_Data :
								( Send_W_AttribWord ) ?		( Extern )  ? AttributeWord : W_AttribWord :
								( Event_Load ) ?			'0 :
								( Send_B_AttribWord ) ? 	B_AttribWord :
								( LdCTRL_Sleep ) ?			Ld_FTk :
								( ~Set_RConfig_Ld ) ? 		Ld_FTk_Ld :
															'0;

	assign W_AttribWord.v	= 1'b1;
	assign W_AttribWord.a	= 1'b0;
	assign W_AttribWord.c	= 1'b0;
	assign W_AttribWord.r	= 1'b0;
	assign W_AttribWord.d	= {4'h0, is_Shared,  I_Shared_Data != 0, 10'h00, R_Length[7:0], 8'h00};
	assign W_AttribWord.i	= '0;

	assign B_AttribWord.v	= 1'b1;
	assign B_AttribWord.a	= 1'b0;
	assign B_AttribWord.c	= 1'b0;
	assign B_AttribWord.r	= 1'b0;
	assign B_AttribWord.d	= R_AttribWord;
	assign B_AttribWord.i	= '0;

	assign End_Terimanl_Block	= is_End_Term_Block;

	assign We_RConfig			= Set_RConfig_Ld & ( R_Cancel_Req | W_Ld_FTk.v );

	assign Start_LoadCTRL		= Event_Load | ( Set_RConfig & Bypass );

	assign Block_is_Terminated	= is_Term_Block | Bypass;

	assign is_Indirect			= I_RConfig[POSIT_MEM_CONFIG_INDIRECT];


	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_BTk_n				<= 1'b0;
			R_Set_AttribWord	<= 1'b0;
			R_Send_Attribute	<= 1'b0;
			R_Cancel_Req		<= 1'b0;
			R_Boot				<= 1'b0;
		end
		else begin
			R_BTk_n				<= I_BTk.n;
			R_Set_AttribWord	<= Set_AttribWord | Set_Attrib_by_IAccess;
			R_Send_Attribute	<= Send_AttribWord;
			R_Cancel_Req		<= Cancel_Req;
			R_Boot				<= I_Boot;
		end
	end


	// is_Term for Last Block of Message
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Term 	<= 1'b0;
		end
		else if ( Set_Load_Rls ) begin
			R_is_Term	<= 1'b0;
		end
		else if ( ( R_RNo == 0 ) & Tail_Load & is_Term_Block & W_Ld_FTk.v ) begin
			R_is_Term	<= 1'b1;
		end
	end

	// Buffer State in Full
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Buff_Full		<= 1'b0;
		end
		else begin
			R_Buff_Full		<= Buff_Full;
		end
	end

	// Capture IDs
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_MyID			<= '0;
		end
		else if ( is_Start_Load & ~Busy ) begin
			R_MyID			<= I_MyID;
		end
	end

	// State in Busy (Run)
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Busy			<= 1'b0;
		end
		else begin
			R_Busy			<= Busy;
		end
	end

	// Ack to Notify is_Match to Front-End
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Ack_BackEnd	<= 1'b0;
		end
		else if ( ~Busy ) begin
			R_is_Ack_BackEnd	<= 1'b0;
		end
		else if ( Check_Match ) begin
			R_is_Ack_BackEnd	<= 1'b1;
		end
	end

	// Capture is_Matched
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Matched	<= 1'b0;
		end
		else if ( ~Busy ) begin
			R_is_Matched	<= 1'b0;
		end
		else if ( Check_Match ) begin
			R_is_Matched	<= is_Matched;
		end
	end

	// Capture Termination of AGU
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Term_AddrGen	<= 1'b0;
		end
		else begin
			R_Term_AddrGen	<= Term_AddrGen;
		end
	end

	// Capture Access-Req, Access-Mode, Address
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_ReqLoad		<= '0;
		end
		else begin
			R_ReqLoad		<= ( LdCTRL_Sleep ) ? W_ReqLoad : W_ReqLoad_Ld;
		end
	end


	//// Capture R-Config Data
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_AttribWord	<= '0;
			R_RConfig		<= '0;
			R_Length		<= '0;
			R_Stride		<= '0;
			R_Base			<= '0;
		end
		else if ( is_Start_Load ) begin
			R_AttribWord	<= I_AttribWord;
			R_RConfig		<= I_RConfig;
			R_Length		<= I_Length;
			R_Stride		<= I_Stride;
			R_Base			<= I_Base;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Dst_FTk		<= '0;
		end
		else if ( Start_RouteGen ) begin
			R_Dst_FTk		<= W_FTk;
		end
	end


	//// Store R-Config Data flor Loading							////
	RConfigData #(
		.WIDTH_DATA(		WIDTH_DATA					)
	) RConfigData_Ld
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_RConfig					),
		.I_Clr(				Set_AttribWord				),
		.I_Data(			W_Ld_FTk.d					),
		.O_RConfig(			B_RConfig					),
		.O_Length(			B_Length					),
		.O_Stride(			B_Stride					),
		.O_Base(			B_Base						),
		.O_End_RConfig(		End_RConfig					)
	);

	ConfigDec_RAM #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) ConfigDec_RAM_Ld
	(
		.I_FTk(				RConfigData					),
		.O_Share(			Make_Share					),
		.O_Decrement(		is_Descrement				),
		.O_Mode(			AccessMode					),
		.O_Indirect(		is_IndirectMode				),
		.O_Length(										),
		.O_Stride(										),
		.O_Base(										)
	);

	AttributeDec AttributeDec_ld
	(
		.I_Data(			W_Ld_FTk.d					),
		.is_Pull(										),
		.is_DataWord(									),
		.is_RConfigData(	is_RConfigData				),
		.is_PConfigData(								),
		.is_RoutingData(	is_RoutingData				),
		.is_Shared(										),
		.is_NonZero(									),
		.is_Dense(										),
		.is_MyAttribute(	is_MyAttribute				),
		.is_Term_Block(		is_Term_Block				),
		.is_In_Cond(									),
		.O_Length(			Length[8+1:0]				)
	);

	AddrGenUnit_Ld #(
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.WIDTH_LENGTH(		WIDTH_ADDR					)
	) AddrGenUnit_Ld
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Cond(			0							),
		.I_Set_Config(		Set_Config					),
		.I_Write_Switch(	Write_Switch				),
		.I_Read_Switch(		Read_Switch					),
		.I_En_AddrGen(		En_AddrGen					),
		.I_Decrement(		is_Descrement				),
		.I_Length(			W_Length[WIDTH_ADDR-1:0]	),
		.I_Stride(			W_Stride[WIDTH_ADDR-1:0]	),
		.I_Base(			W_Base[WIDTH_ADDR-1:0]		),
		.O_Address(			Address						),
		.O_RNo(				R_RNo						),
		.O_Term(			Term_AddrGen				)
	);

	RingBuff #(
		.DEPTH_BUFF(		BUFF_SIZE					),
		.WIDTH_DEPTH(		WIDTH_BUFF					),
		.TYPE_FWRD(			logic[WIDTH_ADDR+3-1:0]		)
	) Buff_ReqLoad
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_Buff_Req					),
		.I_Re(				Re_Buff_Req					),
		.I_FTk(				ReqLoad						),
		.O_FTk(				W_ReqLoad					),
		.O_Full(			Buff_Full_Req				),
		.O_Empty(			Buff_Empty_Req				),
		.O_Num(				Num							)
	);

	RingBuff #(
		.DEPTH_BUFF(		BUFF_SIZE					),
		.WIDTH_DEPTH(		WIDTH_BUFF					),
		.TYPE_FWRD(			FTk_t						)
	) Buff_Load_Data
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_Buff_Data				),
		.I_Re(				Re_Buff_Data				),
		.I_FTk(				I_Ld_FTk					),
		.O_FTk(				W_Ld_FTk					),
		.O_Full(			Buff_Full_Data				),
		.O_Empty(			Buff_Empty_Data				),
		.O_Num(				Buff_Num_Data				)
	);

	RingBuff #(
		.DEPTH_BUFF(		BUFF_SIZE					),
		.WIDTH_DEPTH(		WIDTH_BUFF					),
		.TYPE_FWRD(			logic[WIDTH_ADDR+3-1:0]		)
	) Buff_ReqLoad_Ld
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_Buff_Req_Ld				),
		.I_Re(				Re_Buff_Req_Ld				),
		.I_FTk(				ReqLoad						),
		.O_FTk(				W_ReqLoad_Ld				),
		.O_Full(			Buff_Full_Req_Ld			),
		.O_Empty(			Buff_Empty_Req_Ld			),
		.O_Num(											)
	);

	RingBuff #(
		.DEPTH_BUFF(		BUFF_SIZE					),
		.WIDTH_DEPTH(		WIDTH_BUFF					),
		.TYPE_FWRD(			FTk_t						)
	) Buff_Load_Data_Ld
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				We_Buff_Data_Ld				),
		.I_Re(				Re_Buff_Data_Ld				),
		.I_FTk(				I_Ld_FTk					),
		.O_FTk(				W_Ld_FTk_Ld					),
		.O_Full(			Buff_Full_Data_Ld			),
		.O_Empty(			Buff_Empty_Data_Ld			),
		.O_Num(											)
	);

	DReg OutPutData (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				W_Ld_FTk_Out				),
		.O_BTk(				W_Ld_BTk					),
		.O_FTk(				W_FTk						),
		.I_BTk(				W_BTk						)
	);

	BlockCTRL #(
		.EXTERNAL(			EXTERNAL					)
	) BlockCTRL
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Event_Load(		Set_RConfig					),
		.I_Indirect(		is_Indirect					),
		.I_Valid(			Valid 						),
		.is_Bypass(			Bypass						),
		.is_Term(			Block_is_Terminated			),
		.is_End_Rename(		is_End_Rename				),
		.I_Length(			Length_Ld[8-1:0]			),
		.I_Term_AddrGen(	Term_AddrGen				),
		.I_Set_RConfig(		Set_RConfig_Ld				),
		.is_RoutingData(	is_RoutingData				),
		.I_Run(				LdCTRL_Run					),
		.O_is_MyID(			is_MyID						),
		.O_is_AttributeWord(is_AttributeWord			),
		.O_is_End_Block(	is_End_Block				),
		.O_is_End_Term_Block(	is_End_Term_Block		)
	);

	LoadCTRL LoadCTRL (
		.clock(				clock						),
		.reset(				reset						),
		.I_Event_Load(		Start_LoadCTRL				),
		.I_Valid(			W_Ld_FTk.v					),
		.I_Stall(			Stall						),
		.I_End_RConfig(		End_RConfig					),
		.I_Term_AddrGen(	Term_AddrGen				),
		.I_End_Block(		is_End_Block				),
		.is_Bypass(			Bypass						),
		.is_End_Rename(		is_End_Rename				),
		.O_Sleep(			LdCTRL_Sleep				),
		.O_Run(				LdCTRL_Run					),
		.O_Set_RConfig(		Set_RConfig_Ld				),
		.O_Set_AttribWord(	Set_AttribWord				),
		.O_Tail_Load(		Tail_Load_Ld				),
		.O_End_Load(		is_End_Load					)
	);

	Ld_CTRL_BackEnd #(
		.EXTERNAL(			EXTERNAL					)
	) Ld_CTRL_BackEnd
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Req(				is_Start_Load				),
		.I_Valid(			CTRL_Valid					),
		.I_Stall(			Stall						),
		.I_Bypass(			I_Bypass					),
		.is_StoredIDs(		is_StoredIDs				),
		.is_Shared(			is_Shared					),
		.is_Data_Block(		is_Data_Block				),
		.is_Term_Load(		Term_AddrGen				),
		.is_IndirectMode(	is_IndirectMode				),
		.is_Matched(		is_Matched					),
		.is_Loaded(			is_Loaded					),
		.is_Zero(			is_Zero						),
		.is_Event_Load(		Event_Load					),
		.is_End_Load(		is_End_Load					),
		.is_Rls(			is_Rls						),
		.is_Bypass(			I_Bypass					),
		.is_End_Rename(		is_End_Rename				),
		.O_LoadIDs(			LoadIDs						),
		.O_Start_RouteGen(	Start_RouteGen				),
		.O_Set_RConfig(		Set_RConfig					),
		.O_Test_First_Load(	Test_First_Load				),
		.O_Check_ID(		Check_Match					),
		.O_Send_AttribWord(	Send_AttribWord				),
		.O_Send_Shared(		Send_Shared					),
		.O_First_Load(		First_Load					),
		.O_Load(			Load						),
		.O_Data_Load(		Data_Load					),
		.O_Set_Acq(			Set_Acq						),
		.O_Tail_Load(		Tail_Load					),
		.O_Bypass(			Bypass						),
		.O_Stall(			Stall_Input					),
		.O_Busy(			Busy						)
	);

	RouteGen RouteGen
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Start(			Start_RouteGen				),
		.I_Stall(			Stall						),
		.I_MyID(			R_MyID						),
		.I_FTk(				I_Bypass_FTk				),
		.I_Ld_FTk(			W_Ld_FTk_Ld					),
		.I_AttribWord(		R_AttribWord				),
		.I_RConfig(			R_RConfig					),
		.I_Length(			R_Length[10-1:0]			),
		.I_Stride(			R_Stride[10-1:0]			),
		.I_Base(			R_Base[10-1:0]				),
		.is_Shared(			is_Shared					),
		.O_Stall(			Stall_RouteGen				),
		.O_SendRouteGen(	Send_RouteGen				),
		.O_SendRetarget(	SendRetarget				),
		.O_SendRCfgShared(	Send_RCfgShared				),
		.O_Data(			FTk_RouteGen				),
		.O_is_End_Rename(	is_End_Rename				)
	);

endmodule