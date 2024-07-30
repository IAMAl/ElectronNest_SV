///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Indirect Routing Data Generator
//	Module Name:	RouteGen
//	Function:
//					-Dynamic routing support by Table Look-up.
//					-A part of memory on base address is used as a Tag compared with
//						accessing message's ID (My-ID), if not matched then take the looking-up.
//						Load unit configures its load access, after then;
//						-Generate Length of Routing Data Word Use
//						-Send Attribute Word
//						-Generate Routing Data Words for X-Y Routing
//						-Send Routing Data
//						-Send Load Access Configuration
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RouteGen
	import	pkg_en::WIDTH_DATA;
	import	pkg_en::WIDTH_LENGTH;
	import	pkg_en::FTk_t;
	import	pkg_en::BTk_t;
	import	pkg_mem::fsm_indirect;
	import	pkg_mem::lOAD_INIT_LD;
	import	pkg_mem::sEND_RCONFIG_LD;
	import	pkg_mem::sEND_RETARGET_LD;
	import	pkg_mem::sEND_RATTRIB_X_LD;
	import	pkg_mem::sEND_ROUTE_X_LD;
	import	pkg_mem::sEND_RATTRIB_Y_LD;
	import	pkg_mem::sEND_ROUTE_Y_LD;
	import	pkg_mem::sEND_ATTRIB_R_LD;
	import	pkg_mem::sEND_ROUTE_R_LD;
	import	pkg_mem::sEND_ATTRIB_A_LD;
	import	pkg_mem::sEND_ROUTE_A_LD;
	import	pkg_mem::sEND_RCATTRIB_X_LD;
	import	pkg_mem::sEND_RCROUTE_X_LD;
	import	pkg_mem::sEND_RCATTRIB_Y_LD;
	import	pkg_mem::sEND_RCROUTE_Y_LD;
	import	pkg_mem::lOAD_SET_ROUTE_X_LD;
	import	pkg_mem::lOAD_SET_ROUTE_Y_LD;
	import	pkg_mem::sEND_ATTRIB_C_LD;
	import	pkg_mem::sEND_ROUTE_C_LD;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input							I_Start,			//Enable to Work
	input							I_Stall,			//Nack Token
	input	[WIDTH_DATA-1:0]		I_MyID,				//My-ID
	input	FTk_t					I_FTk,				//Data
	input	FTk_t					I_Ld_FTk,			//Loaded Data
	input	[WIDTH_DATA-1:0]		I_AttribWord,		//Set Attribute Word
	input	[WIDTH_DATA-1:0]		I_RConfig,			//Set R-Config Data
	input	[WIDTH_LENGTH-1:0]		I_Length,			//Set Length
	input	[WIDTH_LENGTH-1:0]		I_Stride,			//Set Stride
	input	[WIDTH_LENGTH-1:0]		I_Base,				//Set Base Address
	input							is_Shared,			//Flag: Shared Data Word
	output	logic					O_SendRouteGen,		//Send Rebamed Routing Blocks
	output	logic					O_SendRetarget,		//Send Follower Blocks
	output	logic					O_SendRCfgShared,	//Send Shared Data
	output	FTk_t					O_Data,				//Sending Data Word
	output	logic					O_Stall,			//Stall Request to Retime
	output	logic					O_is_End_Rename		//Flag: End of Indirect Access Gen
);

	localparam WIDTH_LENGTH_	= 8;


	//// Routing Code Assignment									////
	localparam int NorthRoute	= 4'h1;
	localparam int EastRoute	= 4'h2;
	localparam int WestRoute	= 4'h4;
	localparam int SouthRoute	= 4'h8;


	//// Finite State Machine										////
	fsm_indirect				FSM_Indirect;

	FTk_t						RenameData;


	//// Connecting Logic											////
	//	 FSM Status
	logic						is_Load_Init;
	logic						is_Send_Retarget;
	logic						is_Rename_RConfig;
	logic						is_Rename_RAttib_X;
	logic						is_Rename_RRoute_X;
	logic						is_Rename_RAttib_Y;
	logic						is_Rename_RRoute_Y;
	logic						is_Rename_Attrib_R;
	logic						is_Rename_Route_R;
	logic						is_Rename_Attrib_A;
	logic						is_Rename_Route_A;
	logic						is_Rename_RCAttrib_X;
	logic						is_Rename_RCRoute_X;
	logic						is_Rename_RCAttrib_Y;
	logic						is_Rename_RCRoute_Y;

	logic						Start_Rename;

	//	 Code Assignment
	logic [3:0]					RouteX [1:0];
	logic [3:0]					RouteY [1:0];

	logic						SelY;
	logic [3:0]					Route [1:0];

	//	 Parse ID to Address
	//	 Requester's ID
	logic [WIDTH_LENGTH-1:0]	MyX;
	logic [WIDTH_LENGTH-1:0]	MyY;

	//	 Destination's ID
	logic [WIDTH_LENGTH-1:0]	DstX;
	logic [WIDTH_LENGTH-1:0]	DstY;

	//	 Address Calculation
	logic [WIDTH_LENGTH-1:0]	MyAddr;
	logic [WIDTH_LENGTH-1:0]	DstAddr;
	logic [WIDTH_LENGTH:0]		Result;
	logic [WIDTH_LENGTH-1:0]	AbsDst;
	logic [WIDTH_LENGTH-1:0]	AbsAddr;

	//	 Route Skip
	logic						Sign;
	logic						Set_Dir;
	logic						is_Zero;

	logic [WIDTH_DATA-WIDTH_LENGTH*2-1:0]	Tag_Base;
	logic [WIDTH_DATA-WIDTH_LENGTH*2-1:0]	Tag_Load;

	//	 Original Length
	logic [WIDTH_LENGTH:0]		OrigLength;

	//	 Receive Address Calculation
	logic [WIDTH_LENGTH-1:0]	RecoveredAbsAddr;
	logic						RecoveredvSign;

	logic						Set_RecoveredDir;
	logic						is_RecoveredZero;

	//	 Compose Routing Data
	FTk_t						RoutingData;

	//	 COmpose Attribute Word
	FTk_t						AttributeData;

	//	 Receive Routing Data
	FTk_t						RecoveredRoutingData;

	//	 Receive Attribute Word
	FTk_t						RecoveredAttribute;

	//	 Attribute Word for CRAM
	FTk_t						AttributeCRAM;

	//	 Follower Data Words
	FTk_t						RouteStLd;
	FTk_t						RouteLoad;

	//	 Setting Retargetting
	logic						Set_ReTarget_X;
	logic						Set_ReTarget_Y;

	logic						Set_Dir_X;
	logic						Set_Dir_Y;

	//	 Setting Destination (My-)ID
	logic						Set_DstID;

	//	 R-Config
	logic						Send_RecoveredXY;

	//	 Storing R-Condig
	logic						Done_RConfig;
	logic	[2:0]				R_CntRConfigData;

	//	 Send Renamed Routing Blocks
	logic						Send_RC;
	logic						SendRouteGen;

	//	 End of Service
	logic						is_End_Rename;

	//logic						Set_Dir_X;
	//logic						Set_Dir_Y;

	//	 R-Config Data for Retargetting
	FTk_t						RConfig;

	//	 Recovering Source-Port No. for Retargetting
	logic						PortIndex_XDir;
	logic	[11:0]				PortNo;
	FTk_t						PortData;

	//	 Follower Data for Retargetting
	FTk_t						FTk;
	BTk_t						BTk;
	FTk_t						R_FTk;


	//// Capture Signal												////
	logic						R_Start;

	logic						R_Stall;

	FTk_t						R_AttribWord;
	FTk_t						R_RConfig;
	FTk_t						R_Length;
	FTk_t						R_Stride;
	FTk_t						R_Base;

	logic						R_Mask_RConfig;
	logic	[WIDTH_DATA-1:0]	R_Check_Length;

	logic	[3:0]				R_Dir;

	logic	[WIDTH_DATA-1:0]	R_DstID;

	logic						R_SendRecovered;

	logic	[WIDTH_DATA-1:0]	R_MyID;

	logic [3:0]					R_CntRecover;

	logic						R_Set_Dir_X;


	//// Extension													////
	logic						R_is_Shared;


	//// State														////
	assign is_Load_Init			= ( FSM_Indirect == lOAD_INIT_LD );
	assign is_Rename_RConfig	= ( FSM_Indirect == sEND_RCONFIG_LD );
	assign is_Send_Retarget		= ( FSM_Indirect == sEND_RETARGET_LD );
	assign is_Rename_RAttib_X	= ( FSM_Indirect == sEND_RATTRIB_X_LD );
	assign is_Rename_RRoute_X	= ( FSM_Indirect == sEND_ROUTE_X_LD );
	assign is_Rename_RAttib_Y	= ( FSM_Indirect == sEND_RATTRIB_Y_LD );
	assign is_Rename_RRoute_Y	= ( FSM_Indirect == sEND_ROUTE_Y_LD );
	assign is_Rename_Attrib_R	= ( FSM_Indirect == sEND_ATTRIB_R_LD );
	assign is_Rename_Route_R	= ( FSM_Indirect == sEND_ROUTE_R_LD );
	assign is_Rename_Attrib_A	= ( FSM_Indirect == sEND_ATTRIB_A_LD );
	assign is_Rename_Route_A	= ( FSM_Indirect == sEND_ROUTE_A_LD );
	assign is_Rename_RCAttrib_X	= ( FSM_Indirect == sEND_RCATTRIB_X_LD );
	assign is_Rename_RCRoute_X	= ( FSM_Indirect == sEND_RCROUTE_X_LD );
	assign is_Rename_RCAttrib_Y	= ( FSM_Indirect == sEND_RCATTRIB_Y_LD );
	assign is_Rename_RCRoute_Y	= ( FSM_Indirect == sEND_RCROUTE_Y_LD );


	//// Start Renaming												////
	assign Start_Rename			= I_Start;


	//// Packing for Input											////
	//	 Forward Tokens
	assign FTk					= ( PortIndex_XDir ) ?		PortData :
									( is_Send_Retarget ) ?	I_FTk :
															'0;

	//	 Backword Tokens
	assign BTk.n				= I_Stall;
	assign BTk.t				= 1'b0;
	assign BTk.v				= 1'b0;
	assign BTk.c				= 1'b0;

	// Stall to Retime (Send Renamed Routing Blocks)
	assign O_Stall				= (( FSM_Indirect >= lOAD_SET_ROUTE_X_LD ) & ( FSM_Indirect <= sEND_RCONFIG_LD )) |
									( ( FSM_Indirect >= sEND_ATTRIB_R_LD ) & ( FSM_Indirect <= sEND_ROUTE_A_LD ) ) |
									I_Stall;

	// Send Renamed Routing Blocks
	assign SendRouteGen			= ( FSM_Indirect > lOAD_SET_ROUTE_X_LD ) & ( FSM_Indirect <= sEND_RETARGET_LD );
	assign O_SendRouteGen		= SendRouteGen;

	// Send Follower Blocks
	assign O_SendRetarget		= ( FSM_Indirect > lOAD_SET_ROUTE_Y_LD );

	// Send R-Config for Shared Data
	assign O_SendRCfgShared		= ( R_CntRConfigData == 6 ) & is_Rename_RConfig;

	// End of Service
	assign is_End_Rename		= ( is_Rename_RCRoute_Y | ( FSM_Indirect == sEND_RETARGET_LD )) & R_FTk.r & ~I_Stall;
	assign O_is_End_Rename		= is_End_Rename;


	//// CaptureInput Signal										////
	//	 used for Making Pulse
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Start			<= 1'b0;
		end
		else if ( ~I_Start ) begin
			R_Start			<= 1'b0;
		end
		else if ( I_Start & I_Ld_FTk.v ) begin
			R_Start			<= 1'b1;
		end
	end

	//	 Capture Signals
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_is_Shared		<= 1'b0;
			R_Stall			<= 1'b0;
		end
		else begin
			R_is_Shared		<= is_Shared;
			R_Stall			<= I_Stall;
		end
	end


	//// Capture My-ID												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_MyID			<= '0;
		end
		else if ( Start_Rename ) begin
			R_MyID			<= I_MyID;
		end
	end


	//// Capture CRAM Configuration Data Word						////
	//	 Capture Attrib Word
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_AttribWord	<= '0;
		end
		else if ( Start_Rename ) begin
			R_AttribWord	<= I_AttribWord;
		end
	end

	//	 Capture Configuration Data
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RConfig		<= '0;
		end
		else if ( Start_Rename ) begin
			R_RConfig		<= I_RConfig;
		end
	end

	//	 Capture Access Length
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Length	<= '0;
		end
		else if ( Start_Rename ) begin
			R_Length	<= I_Length;
		end
	end

	//	 Capture Stride Factor
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stride	<= '0;
		end
		else if ( Start_Rename ) begin
			R_Stride	<= I_Stride;
		end
	end

	//	 Capture Base Address
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Base		<= '0;
		end
		else if ( Start_Rename ) begin
			R_Base		<= I_Base;
		end
	end


	//// Capture Destination ID										////
	//	 This ID is loaded from Memory
	assign Set_DstID		= Start_Rename;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_DstID			<= '0;
		end
		else if ( Set_DstID ) begin
			R_DstID			<= I_Ld_FTk.d;
		end
	end


	//// Tag Match Detection										////
	//	 Parse Tags
	assign Tag_Base			= R_Base[WIDTH_DATA-1:WIDTH_LENGTH_*2];
	assign Tag_Load			= R_DstID[WIDTH_DATA-1:WIDTH_LENGTH_*2];


	//// Routng Code Select											////
	//	 SelY
	//	 0:		Select X-axis
	//	 1:		Select Y-axis
	//	 Select Y-axis
	assign SelY				= (  ( FSM_Indirect >= sEND_ROUTE_X_LD )    & ( FSM_Indirect  < sEND_ATTRIB_R_LD )) |
								(( FSM_Indirect >= sEND_RCATTRIB_Y_LD ) & ( FSM_Indirect <= sEND_RCROUTE_Y_LD ));

	//	 Routing Method: X-Y Routing
	//	 Routing Data (X and Y) is geneted with two-steps work
	//	 Direction Code Assignment									////
	assign RouteY[1]		= NorthRoute;
	assign RouteY[0]		= SouthRoute;
	assign RouteX[1]		= WestRoute;
	assign RouteX[0]		= EastRoute;

	//	 Read Direction Code
	assign Route			= ( SelY ) ? RouteY : RouteX;


	//// Direction-Code Select										////
	//	 Capture Direction-Code
	assign Set_Dir_X		= FSM_Indirect == lOAD_SET_ROUTE_X_LD;
	assign Set_Dir_Y		= ( FSM_Indirect == lOAD_SET_ROUTE_Y_LD ) | is_Rename_RRoute_X;
	assign Set_Dir			= Set_Dir_X | Set_Dir_Y ;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Dir			<= '0;
		end
		else if ( Set_Dir ) begin
			R_Dir			<= Route[ Sign ];
		end
	end


	//// ID Select													////
	//	 Parsing from My_ID
	assign MyX				= R_MyID[WIDTH_LENGTH-1:0];
	assign MyY				= R_MyID[WIDTH_LENGTH*2-1:WIDTH_LENGTH];

	//	 Parsing from Destination-ID
	assign DstX				= R_DstID[WIDTH_LENGTH-1:0];
	assign DstY				= R_DstID[WIDTH_LENGTH*2-1:WIDTH_LENGTH];

	assign MyAddr			= ( SelY ) ? MyY : MyX;
	assign DstAddr			= ( SelY ) ? DstY : DstX;


	//// Absolute Distance Calculation								////
	//	 Signed Distance
	assign Result			= $signed( DstAddr ) - $signed( MyAddr );
	assign Sign				= Result[WIDTH_LENGTH];

	//	 Absolute Distance
	assign AbsDst			= ( Sign ) ? ~Result + 1'b1 : Result;

	//	 Assigning Distance is "minus one"
	assign AbsAddr			= ( AbsDst != '0 ) ? AbsDst - 1'b1 : '0;


	//// Zero-Length Detection										////
	//	 	needed to detect routing to destination having same X/Y
	assign is_Zero			= ( AbsDst == '0 ) & ( FSM_Indirect >= lOAD_SET_ROUTE_X_LD );


	//// Recover Routing											////
	assign RecoveredvSign	= ~Sign;

	//	 Recovered Block Length embedded in Attrib Word
	assign RecoveredAbsAddr	= (( AbsAddr - Sign ) != 0 ) ?	AbsAddr - 1 :
															'0;


	//// Zero-Length Detection										////
	//	 	needed to detect routing to destination having same X/Y Length
	//		Hight then skip X-routing
	assign is_RecoveredZero	= ( RecoveredAbsAddr == '0 ) & ( FSM_Indirect >= sEND_RCONFIG_LD );


	//// Capture Recovered Direction								////
	//// Flag sent to X-direction									////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Set_Dir_X		<= 1'b0;
		end
		else if ( is_Load_Init ) begin
			R_Set_Dir_X		<= 1'b0;
		end
		else if ( Set_Dir_X ) begin
			R_Set_Dir_X		<= 1'b1;
		end
	end


	//// Routing Block												////
	//	 Attribute Word Composition
	assign AttributeData.v	= 1'b1;
	assign AttributeData.a	= 1'b0;
	assign AttributeData.c	= 1'b0;
	assign AttributeData.r	= 1'b0;
	`ifdef EXTEND_MEM
	assign AttributeData.i	= 1'b0;
	`endif
	assign AttributeData.d	= { 4'h3, 12'h000, AbsAddr, 8'h00 };

	//	 Routing Data Composition
	assign RoutingData.v	= 1'b1;
	assign RoutingData.a	= 1'b0;
	assign RoutingData.c	= 1'b0;
	assign RoutingData.r	= 1'b0;
	`ifdef EXTEND_MEM
	assign RoutingData.i	= '0;
	`endif
	assign RoutingData.d	= { 28'h0000000, R_Dir };


	//// Recovered Routing Block									////
	//	 Attribute Word Composition
	assign RecoveredAttribute.v	= 1'b1;
	assign RecoveredAttribute.a	= 1'b0;
	assign RecoveredAttribute.c	= 1'b0;
	assign RecoveredAttribute.r	= 1'b0;
	`ifdef EXTEND_MEM
	assign RecoveredAttribute.i	= 1'b0;
	`endif
	assign RecoveredAttribute.d	= { 4'h3, 12'h000, RecoveredAbsAddr, 8'h00 };

	//	 Routing Data Composition
	assign RecoveredRoutingData	= I_FTk;


	//// Entering into Retarget-RE									////
	//	 Attribute Word Composition
	assign AttributeCRAM.v	= 1'b1;
	assign AttributeCRAM.a	= 1'b0;
	assign AttributeCRAM.c	= 1'b0;
	assign AttributeCRAM.r	= 1'b0;
	`ifdef EXTEND_MEM
	assign AttributeCRAM.i	= 1'b0;
	`endif
	assign AttributeCRAM.d	= { 4'h3, 28'h0000000 };

	//	 Routing Data Composition
	//		Entering Retarget-RE
	assign RouteStLd.v		= 1'b1;
	assign RouteStLd.a		= 1'b0;
	assign RouteStLd.c		= 1'b0;
	assign RouteStLd.r		= 1'b0;
	`ifdef EXTEND_MEM
	assign RouteStLd.i		= 1'b0;
	`endif
	assign RouteStLd.d		= { 32'h00000010 };

	//		Entering Load Unit
	assign RouteLoad.v		= 1'b1;
	assign RouteLoad.a		= 1'b0;
	assign RouteLoad.c		= 1'b0;
	assign RouteLoad.r		= 1'b0;
	`ifdef EXTEND_MEM
	assign RouteLoad.i		= 1'b0;
	`endif
	assign RouteLoad.d		= { 32'h00000001 };


	//// Recover Blocks												////
	//	 Send/Not-Send Attrib Word for Routing Data
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_CntRecover	<= '0;
		end
		else if ( Done_RConfig ) begin
			R_CntRecover	<= 1;
		end
		else if ( is_Load_Init ) begin
			R_CntRecover	<= '0;
		end
		else if (( R_CntRecover > 0 ) & ~I_Stall ) begin
			R_CntRecover	<= R_CntRecover + 1'b1;
		end
	end

	assign Send_RecoveredXY	= ( R_Set_Dir_X ) ? ( R_CntRecover < 5 ) & ( R_CntRecover > 2 ) :
												( R_CntRecover < 3 ) & ( R_CntRecover > 0 );


	//// Recover Routing Data for Port-Connection					////
	//	 Use of Port Detection
	assign PortIndex_XDir	= I_FTk.d[23:12] != '0;

	//	 Recovering Port-No
	assign PortNo			= ( Sign ) ?	I_FTk.d[11:0] - AbsDst :
											I_FTk.d[11:0] + AbsDst;

	//	 Recovered Port Routing Data Composition
	assign PortData.v		= I_FTk.v;
	assign PortData.a		= I_FTk.a;
	assign PortData.c		= I_FTk.c;
	assign PortData.r		= I_FTk.r;
	assign PortData.d		= { I_FTk.d[WIDTH_DATA-1:12], PortNo };
	assign PortData.i		= I_FTk.i;


	//// RConfiguration for Loading Base Address is Done			////
	assign Done_RConfig		= ( R_is_Shared ) ? ( R_CntRConfigData == 3'h4 ) :
												( R_CntRConfigData == 3'h4 );
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_CntRConfigData		<= '0;
		end
		else if ( Done_RConfig ) begin
			R_CntRConfigData		<= '0;
		end
		else if ( ~I_Stall & is_Rename_RConfig ) begin
			R_CntRConfigData		<= R_CntRConfigData + 1;
		end
	end


	//// Output													////
	//	 Select Renamed Data
	assign RenameData		= ( is_Rename_RAttib_X ) ?		AttributeData :
								( is_Rename_RRoute_X ) ?	RoutingData :
								( is_Rename_RAttib_Y ) ?	AttributeData :
								( is_Rename_RRoute_Y ) ?	RoutingData :
								( is_Rename_Attrib_R ) ?	AttributeCRAM :
								( is_Rename_Route_R ) ?		RouteStLd :
								( is_Rename_Attrib_A ) ?	AttributeCRAM :
								( is_Rename_Route_A ) ?		RouteLoad :
								( is_Rename_Route_A ) ?		RecoveredAttribute :
								( is_Rename_RCRoute_X ) ?	RecoveredRoutingData :
								( is_Rename_RCAttrib_Y ) ?	RecoveredAttribute :
								( is_Rename_RCRoute_Y ) ?	RecoveredRoutingData :
								( is_Send_Retarget ) ?		R_FTk :
															'0;

	//	 Send Recovered Data
	assign Send_RC			= (( FSM_Indirect > lOAD_SET_ROUTE_X_LD ) & ( FSM_Indirect < sEND_RCONFIG_LD )) |
								Send_RecoveredXY |
								is_Send_Retarget;

	assign RConfig.v		= 1'b1;
	assign RConfig.a		= 1'b0;
	assign RConfig.c		= 1'b0;
	assign RConfig.r		= 1'b0;
	assign RConfig.d		=  ( R_CntRConfigData == 0 ) ?	R_AttribWord :
								( R_CntRConfigData == 1 ) ?	R_RConfig :
								( R_CntRConfigData == 2 ) ?	R_Length :
								( R_CntRConfigData == 3 ) ?	R_Stride :
								( R_CntRConfigData == 4 ) ?	R_Base :
															'0;
	assign RConfig.i		= '0;

	assign O_Data			= ( R_Stall ) ?												'0 :
								( Send_RC ) ?											RenameData :
								( R_CntRConfigData != '0 ) ?							RConfig :
								( ( R_CntRConfigData == '0 ) & is_Rename_RConfig ) ?	RConfig :
																						'0;


	//// Control Body												////
	always_ff @( posedge clock ) begin : ff_fsm_ld
		if ( reset ) begin
			FSM_Indirect		<= lOAD_INIT_LD;
		end
		else case ( FSM_Indirect )
			lOAD_INIT_LD: begin
				if ( Start_Rename ) begin
					FSM_Indirect	<= lOAD_SET_ROUTE_X_LD;
				end
				else begin
					FSM_Indirect	<= lOAD_INIT_LD;
				end
			end
			lOAD_SET_ROUTE_X_LD: begin
				// Compose Route X-axis
				if ( ~is_Zero ) begin
					FSM_Indirect	<= sEND_RATTRIB_X_LD;
				end
				else if ( is_Zero ) begin
					FSM_Indirect	<= lOAD_SET_ROUTE_Y_LD;
				end
			end
			sEND_RATTRIB_X_LD: begin
				// Send Attribute Word for X-axis
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ROUTE_X_LD;
				end
			end
			sEND_ROUTE_X_LD: begin
				// Send Routing Data X-axis, Compose Route Y-axis
				if ( ~is_Zero ) begin
					FSM_Indirect	<= sEND_RATTRIB_Y_LD;
				end
				else if ( is_Zero ) begin
					FSM_Indirect	<= sEND_ATTRIB_R_LD;
				end
			end
			lOAD_SET_ROUTE_Y_LD: begin
				// Compose Route Y-axis
				if ( ~is_Zero ) begin
					FSM_Indirect	<= sEND_RATTRIB_Y_LD;
				end
				else if ( is_Zero ) begin
					FSM_Indirect	<= sEND_ATTRIB_R_LD;
				end
			end
			sEND_RATTRIB_Y_LD: begin
				// Send Attribute Word for Y-axis
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ROUTE_Y_LD;
				end
			end
			sEND_ROUTE_Y_LD: begin
				// Send Routing Data Y-axis
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ATTRIB_R_LD;
				end
			end
			sEND_ATTRIB_R_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ROUTE_R_LD;
				end
			end
			sEND_ROUTE_R_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ATTRIB_A_LD;
				end
			end
			sEND_ATTRIB_A_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_ROUTE_A_LD;
				end
			end
			sEND_ROUTE_A_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_RCONFIG_LD;
				end
			end
			sEND_RCONFIG_LD: begin
				if ( Done_RConfig & ~is_RecoveredZero ) begin
					FSM_Indirect	<= sEND_RCATTRIB_X_LD;
				end
				else if ( Done_RConfig & is_RecoveredZero ) begin
					FSM_Indirect	<= sEND_RCATTRIB_Y_LD;
				end
			end
			sEND_RCATTRIB_X_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_RCROUTE_X_LD;
				end
			end
			sEND_RCROUTE_X_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_RCATTRIB_Y_LD;
				end
			end
			sEND_RCATTRIB_Y_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= sEND_RCROUTE_Y_LD;
				end
			end
			sEND_RCROUTE_Y_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= lOAD_INIT_LD;
				end
				else if ( ~R_FTk.r ) begin
					FSM_Indirect	<= sEND_RETARGET_LD;
				end
			end
			sEND_RETARGET_LD: begin
				if ( ~I_Stall ) begin
					FSM_Indirect	<= lOAD_INIT_LD;
				end
			end
			sEND_ATTRIB_C_LD: begin
				FSM_Indirect	<= sEND_ROUTE_C_LD;
			end
			sEND_ROUTE_C_LD: begin
				FSM_Indirect	<= lOAD_INIT_LD;
			end
			default: begin
				FSM_Indirect	<= lOAD_INIT_LD;
			end
		endcase
	end

	DReg RFTk (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				FTk							),
		.I_BTk(				BTk							),
		.O_FTk(				R_FTk						),
		.O_BTk(											)
	);

endmodule
