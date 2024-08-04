///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Interface Unit
//	Module Name:	IFUnit
//	Function:
//					Top Module of Ritch IF
//					Interface Logic connecting between External Memory, Buffers, and Compute Tile
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IFUnit
    import pkg_en::FTk_t;
    import pkg_en::BTk_t;
    import pkg_en::data_t;
    import pkg_en::WIDTH_DATA;
    import pkg_en::FTk_if_t;
    import pkg_en::BTk_if_t;
	import pkg_en::NUM_LINK;
	import pkg_en::sbit_t;
	import pkg_en::bit_12_t;
	import pkg_en::FTk_12_t;
	import pkg_en::BTk_12_t;
	import pkg_en::FTk_1_t;
	import pkg_en::BTk_1_t;
	import pkg_en::BTk_2_t;
	import pkg_bram_if::*;
(
	input										clock,
	input										reset,
	input										I_Boot,			//Boot Signal
	input	io_bram_t							I_Port,			//Input from Compute Tile
	output	io_bram_t							O_Port,			//Output to Compute Tile
	output	[NUM_EXT_IFS-1:0]					O_Ld_Req,		//Load Request
	output	ext_word_addr_t[NUM_EXT_IFS-1:0]	O_Ld_Addr,		//Load Address
	input	[NUM_EXT_IFS-1:0]					I_Ld_Ack,		//Load-Ack
	input	ext_data_t[NUM_EXT_IFS-1:0]			I_Ld_FTk,		//Loading Data
	output	BTk_if_t							O_Ld_BTk,		//Load Backward Tokens
	output	[NUM_EXT_IFS-1:0]					O_St_Req,		//Store Request
	output	ext_word_addr_t[NUM_EXT_IFS-1:0]	O_St_Addr,		//Store Address
	input	[NUM_EXT_IFS-1:0]					I_St_Ack,		//Store-Ack
	output	ext_data_t[NUM_EXT_IFS-1:0]			O_St_FTk,		//Storing Data
	input	BTk_if_t							I_St_BTk,		//Store Ack, etc
	output	logic	[11:0]						O_State			//Status
);

	localparam NUM_IF			= NUM_EXT_IFS+NUM_ELMS;
	localparam MOD_IF			= 4-(NUM_IF%4);


	//// Logic Connect												////
	//// Instruction-Fetch											////
	logic						W_Req_IRAM;

	//
	logic						acq_message;
	logic						acq_flagmsg;
	logic						rls_message;
	logic						rls_flagmsg;

	//	 Instruction Memory
	logic	[NUM_UNITS-1:0]		W_Busy;

	logic						W_StEn;
	logic						W_Req;

	FTk_t						W_Instr;
	logic						IFCTRL_Stall;

	//	 Instruction Decode
	logic						W_Op_MOVE;

	logic	[WIDTH_AID-1:0]		W_ADstID;
	logic	[WIDTH_AID-1:0]		W_ASrcID;

	logic						WAR_NEn;

	//	 Rename Unit
	logic						Rename_Ready;
	logic						Rename_Req;
	logic						Rename_Full;
	logic						Rename_Empty;

	logic						Rename_Hazard;

	//	 Commit Unit
	logic						Commit_Ready;
	logic						Commit_Req;
	logic						Commit_Full;
	logic						Commit_Empty;

	logic						W_Commit_Req;
	logic	[NUM_UNITS-1:0]		W_Commit;
	logic						W_Req_Commit;
	logic	[NUM_UNITS-1:0]		W_Ack_Commit;
	logic	[NUM_UNITS-1:0]		W_Clr_Commit;



	//	 Port-Map Unit
	logic						Port_Ready;
	logic						PortMap_Req;
	logic						W_Port_Req;

	nbit_t						W_VldPort;
	port_pdst_id_t				W_DstPort;
	port_psrc_id_t				W_SrcPort;
	logic	[NUM_UNITS-1:0]		W_SrcRls;

	logic						Port_Valid;
	logic						Port_Empty_BRAM;
	logic						Port_Full_BRAM;
	logic						Port_Empty_IFLogic;
	logic						Port_Full_IFLogic;
	logic						Port_Empty;
	logic						Port_Full;

	//	 Port-Select Number
	logic	[NUM_UNITS-1:0]		W_DstVld;
	logic	[NUM_UNITS-1:0]		W_SrcVld;

	//	 Port-Pattern Unit
	logic	[WIDTH_PID-1:0]		W_PDstID;
	logic	[WIDTH_PID-1:0]		W_PSrcID;
	logic						SelDst;

	//	 Interconnection Network Tracks
	FTk_t						W_I_Data	[NUM_UNITS-1:0];
	FTk_t						W_O_Data	[NUM_UNITS-1:0];

	BTk_t						W_I_CTRL	[NUM_UNITS-1:0];
	BTk_t						W_O_CTRL	[NUM_UNITS-1:0];

	//	 Load/Store Indicator
	logic						Ld			[NUM_UNITS-1:0];
	logic						St			[NUM_UNITS-1:0];

	//	 External Store Unit
	logic	[NUM_EXT_IFS-1:0]	St_Req;
	ext_word_addr_t				St_Addr		[NUM_EXT_IFS-1:0];
	ext_data_t					St_Data		[NUM_EXT_IFS-1:0];
	BTk_if_t					St_BTk;
	CSel_t	[NUM_EXT_IFS-1:0]	W_O_CSel;
	logic	[NUM_EXT_IFS-1:0]	St_Ack;

	//	 External Load Unit
	logic	[NUM_EXT_IFS-1:0]	Ld_Req;
	ext_word_addr_t				Ld_Addr		[NUM_EXT_IFS-1:0];
	ext_data_t					Ld_FTk		[NUM_EXT_IFS-1:0];
	BTk_if_t					Ld_BTk;
	logic	[NUM_EXT_IFS-1:0]	Ld_Ack;

	//	 IF-Logic to FanIn-Tree Select
	FTk_t	[NUM_ELMS-1:0]		Req_FTk;
	BTk_t	[NUM_ELMS-1:0]		Req_BTk;

	//	 FanIn-Tree <-> IRAM Port
	FTk_t						FanIn_FTk;
	BTk_t						FanIn_BTk;

	//	 IRAM to External Load Unit
	logic						CacheMiss;
	FTk_t						Ld_Req_FTk;
	BTk_t						Ld_Req_BTk;

	//	 External Load Unit to FanIn-Tree
	FTk_extif_t					W_LdSt_FTk;
	BTk_extif_t					W_LdSt_BTk;

	FTk_t	[NUM_EXT_IFS-1:0]	W_Ld_FTk;
	BTk_t	[NUM_EXT_IFS-1:0]	W_Ld_BTk;

	FTk_t	[NUM_EXT_IFS-1:0]	W_Ld_Req_FTk;
	BTk_t	[NUM_EXT_IFS-1:0]	W_Ld_Req_BTk;

	FTk_t	[NUM_EXT_IFS-1:0]	Ld_FTk_;
	BTk_t	[NUM_EXT_IFS-1:0]	Ld_BTk_;

	//
	FTk_12_t					Branch_FTk	[NUM_EXT_IFS-1:0];
	BTk_12_t					Branch_BTk	[NUM_EXT_IFS-1:0];

	//
	FTk_t						W_RCFG;

	//
	logic						IFCTRL_Rls;

	//	 Pipeline Stall
	logic						Stall;

	logic						Rename_Busy;
	logic						Port_Busy;
	logic						Commit_Busy;

	//	 Stall Control
	logic						Stop_Load;
	logic						Clr_Stall;

	logic						Branch_AcqOut;

	BTk_2_t						W_Branch_BTk	[NUM_EXT_IFS-1:0];

	logic						W_St_Done;

	logic						Enable_Load;

	logic						Start_Load;
	logic						End_Load;
	logic						Start_Store;
	logic						End_Store;
	logic						State_Load;
	logic						State_Store;


	//// Capture Signal												////
	logic						R_Boot;

	//	 Status Register
	logic	[15:0]				R_State;

	//	 Stall Flag
	logic						R_Stall;

	logic						R_Port_Valid;


	//// Pipeline Stall												////
	assign  Stall			= Rename_Full | Port_Full | Commit_Full;


	//// Request FanIn-Tree											////
	always_comb begin
		for ( int i=0; i<NUM_EXT_IFS; ++i ) begin
			W_LdSt_FTk[ i ]			= Branch_FTk[ i ][1];
			W_Branch_BTk[ i ][1]	= W_LdSt_BTk[ i ];

			Branch_BTk[ i ][0][0].n	= W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ].n | R_Stall | Rename_Hazard;
			Branch_BTk[ i ][0][0].t	= W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ].t;
			Branch_BTk[ i ][0][0].v	= W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ].v;
			Branch_BTk[ i ][0][0].c	= W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ].c;

			Branch_BTk[ i ][1][0].n	= W_Branch_BTk[ i ][1].n | R_Stall | Rename_Hazard;
			Branch_BTk[ i ][1][0].t	= W_Branch_BTk[ i ][1].t;
			Branch_BTk[ i ][1][0].v	= W_Branch_BTk[ i ][1].v;
			Branch_BTk[ i ][1][0].c	= W_Branch_BTk[ i ][1].c;
		end
	end

	FanInTree FanInTree(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				Req_FTk						),
		.O_BTk(				Req_BTk						),
		.O_FTk(				FanIn_FTk					),
		.I_BTk(				FanIn_BTk					),
		.I_LdSt_FTk(		W_LdSt_FTk					),
		.O_LdSt_BTk(		W_LdSt_BTk					)
	);


	//// Boot Sequence												////
	//	 In State of Booting
	assign W_StEn			= R_Boot;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Boot			<= 1'b0;
		end
		else if ( W_I_Data[ 0 ].r ) begin
			R_Boot			<= 1'b0;
		end
		else begin
			R_Boot			<= I_Boot;
		end
	end


	//// IF Unit Controller											////
	assign IFCTRL_Stall		= Stall | Rename_Hazard;
	assign FanIn_BTk.n		= IFCTRL_Stall;
	assign FanIn_BTk.t		= 1'b0;
	assign FanIn_BTk.v		= 1'b0;
	assign FanIn_BTk.c		= 1'b0;
	assign W_St_Done		= W_O_CTRL[ ID_OFFSET_IFEXTRN + 1 ].t;
	assign IFCTRL_Rls		= W_SrcRls[ID_OFFSET_IFEXTRN] | W_Req_Commit;
	IFCTRL IFCTRL (
		.clock(				clock						),
		.reset(				reset						),
		.I_Stall(			IFCTRL_Stall				),
		.I_Done(			Port_Valid					),
		.I_FTk(				FanIn_FTk					),
		.O_FTk(				W_Instr						),
		.O_RCFG(			W_RCFG						),
		.O_Req(				W_Req_IRAM					),
		.O_Busy(			W_Busy[0]					),
		.I_St_Done(			W_St_Done					),
		.I_Rls(				IFCTRL_Rls					)
	);


	//// Instruction Decode											////
	IDec IDec (
		.I_Instr(			W_Instr						),
		.O_OpCode_Move(		W_Op_MOVE					),
		.O_WAR_NEn(			WAR_NEn						),
		.O_ADstID(			W_ADstID					),
		.O_ASrcID(			W_ASrcID					)
	);


	//// ID-Rename													////
	//	 Status
	assign Rename_Busy		= ~Rename_Empty & ~Rename_Full;
	assign Rename_Ready		= Rename_Empty | Rename_Busy;

	//	 Reqest
	assign Rename_Req		= W_Req_IRAM & Rename_Ready & ~Stall;

	RenameUnit RenameUnit (
		.clock(				clock						),
		.reset(				reset						),
		.I_Req(				Rename_Req					),
		.I_WAR_NEn(			WAR_NEn						),
		.I_ADstID(			W_ADstID					),
		.I_ASrcID(			W_ASrcID					),
		.O_PDstID(			W_PDstID					),
		.O_PSrcID(			W_PSrcID					),
		.O_Req(				PortMap_Req					),
		.I_Rls(				W_Req_Commit				),
		.I_Commit(			W_Clr_Commit				),
		.O_Hazard(			Rename_Hazard				),
		.O_Error(										),
		.O_Full(			Rename_Full					),
		.O_Empty(			Rename_Empty				)
	);


	//// Port Mapping												////
	//	 Status
	assign Port_Busy		= ~Port_Empty & ~Port_Full;
	assign Port_Ready		= Port_Empty | Port_Busy;

	//	 Request
	assign W_Port_Req		= PortMap_Req & Port_Ready & ~Stall;

	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			W_SrcRls[ i ]	= Ld[ i ] & W_O_Data[ i ].v & W_O_Data[ i ].a & W_O_Data[ i ].r;
		end
	end

	PortMap PortMap (
		.clock(				clock						),
		.reset(				reset						),
		.I_Req(				W_Port_Req					),
		.I_PDstID(			W_PDstID					),
		.I_PSrcID(			W_PSrcID					),
		.O_VldPort( 		W_VldPort					),
		.O_DstPort(			W_DstPort					),
		.O_SrcPort(			W_SrcPort					),
		.I_Commit(			W_SrcRls					),
		.O_Req(				W_Commit_Req				),
		.O_Commit(			W_Commit					),
		.I_Ack(				W_Ack_Commit				),
		.O_DstVld(			W_DstVld					),
		.O_SrcVld(			W_SrcVld					),
		.O_Valid(			Port_Valid					),
		.O_Empty_BRAM(		Port_Empty_BRAM				),
		.O_Full_BRAM(		Port_Full_BRAM				),
		.O_Empty_IFLogic(	Port_Empty_IFLogic			),
		.O_Full_IFLogic(	Port_Full_IFLogic			),
		.O_Empty(			Port_Empty					),
		.O_Full(			Port_Full					)
	);


	//// Destination Select											////
	IFPattern IFPattern (
		.I_PDstID(			W_PDstID					),
		.I_PSrcID(			W_PSrcID					),
		.O_SelDst(			SelDst						)
	);


	//// Commit Unit												////
	//	 Status
	assign Commit_Busy		= ~Commit_Empty & ~Commit_Full;
	assign Commit_Ready		= Commit_Empty | Commit_Busy;

	//	 Request
	assign Commit_Req		= W_Commit_Req & Commit_Ready & ~Stall;

	Commit Commit (
		.clock(				clock						),
		.reset(				reset						),
		.I_Req(				Commit_Req					),
		.I_SrcPort(			W_PSrcID					),
		.I_Commit(			W_Commit					),
		.O_Req(				W_Req_Commit				),
		.O_Ack(				W_Ack_Commit				),
		.O_Commit(			W_Clr_Commit				),
		.O_Full(			Commit_Full					),
		.O_Empty(			Commit_Empty				),
		.O_Ready(										),
		.O_Busy(										)
	);


	//// Status Register											////
	assign O_State			= R_State;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_State		<= '0;
		end
		else begin
			R_State		<= {
								W_Busy[ID_OFFSET_BRAM+3],
								W_Busy[ID_OFFSET_BRAM+2],
								W_Busy[ID_OFFSET_BRAM+1],
								W_Busy[ID_OFFSET_BRAM+0],
								W_Busy[0],
								1'b0,
								Rename_Empty,
								Rename_Full,
								Port_Empty,
								Port_Full,
								Commit_Empty,
								Commit_Full,
								Port_Empty_BRAM,
								Port_Full_BRAM,
								Port_Empty_IFLogic,
								Port_Full_IFLogic
							};
		end
	end


	//// Interconnection Network									////
	//	 Load/Store Flag
	always_comb begin: c_stld
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Ld[ i ]			= W_SrcVld[ i ];
			St[ i ]			= W_DstVld[ i ];
		end
	end

	//	 Input Select for Front-End
	always_comb begin: i_net
		for ( int i=0; i<NUM_CTRLS; ++i ) begin
			W_I_Data[ ID_OFFSET_CTRL + i ]		= ( I_Boot ) ? I_Ld_FTk[ i ]	: ( Ld[ W_SrcPort[ ID_OFFSET_CTRL + i ] ] & W_VldPort[ ID_OFFSET_CTRL + i ] ) ?		W_O_Data[ W_SrcPort[ ID_OFFSET_CTRL + i ] ] : '0;
			W_I_CTRL[ ID_OFFSET_CTRL + i ]		= ( I_Boot ) ? '0				: ( W_VldPort[ W_DstPort[ ID_OFFSET_CTRL + i ] ] ) ?								W_O_CTRL[ W_DstPort[ ID_OFFSET_CTRL + i ] ] : '0;
			W_O_Data[ ID_OFFSET_CTRL + i ]		= '0;
			W_O_CTRL[ ID_OFFSET_CTRL + i ]		= '0;
		end
	end

	//	 Input Select for BRAM
	always_comb begin: c_net
		for ( int i=0; i<NUM_BRAMS; ++i ) begin
			W_I_Data[ ID_OFFSET_BRAM + i ]		= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_BRAM + i ] ] & W_VldPort[ ID_OFFSET_BRAM + i ] ) ?							W_O_Data[ W_SrcPort[ ID_OFFSET_BRAM + i ] ] : '0;
			W_I_CTRL[ ID_OFFSET_BRAM + i ]		= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_BRAM + i ] ] ) ?														W_O_CTRL[ W_DstPort[ ID_OFFSET_BRAM + i ] ] : '0;
		end
	end

	//	 Input Select for Interface Logic (connecting to Compute Tile)
	always_comb begin: c_iflogic
		for ( int i=0; i<NUM_ELMS; ++i ) begin
			W_I_Data[ ID_OFFSET_IFLOGIC + i ]	= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_IFLOGIC + i ] ] & W_VldPort[ ID_OFFSET_IFLOGIC + i ] ) ?						W_O_Data[ W_SrcPort[ ID_OFFSET_IFLOGIC + i ] ] : '0;
			W_I_CTRL[ ID_OFFSET_IFLOGIC + i ]	= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_IFLOGIC + i ] ] ) ?													W_O_CTRL[ W_DstPort[ ID_OFFSET_IFLOGIC + i ] ] : '0;
		end
	end

	//	 Input Select for External Memory Load/Store Unit
	always_comb begin: c_ext
		for ( int i=0; i<NUM_EXT_IFS; ++i ) begin
			// Load Unit
			//W_I_Data[ ID_OFFSET_IFEXTRN + i*2 + 0 ]	= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_IFEXTRN + i*2 + 0 ] ] & W_VldPort[ ID_OFFSET_IFEXTRN + i*2 + 0 ] ) ?		W_O_Data[ W_SrcPort[ ID_OFFSET_IFEXTRN + i*2 + 0 ] ] : '0;
			//W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ]	= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_IFEXTRN + i*2 + 0 ] ] ) ?											W_O_CTRL[ W_DstPort[ ID_OFFSET_IFEXTRN + i*2 + 0 ] ] : '0;

			// Store Unit
			//W_I_Data[ ID_OFFSET_IFEXTRN + i*2 + 1 ]	= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_IFEXTRN + i*2 + 1 ] ] & W_VldPort[ ID_OFFSET_IFEXTRN + i*2 + 1 ] ) ?		W_O_Data[ W_SrcPort[ ID_OFFSET_IFEXTRN + i*2 + 1 ] ] : '0;
			//W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 1 ]	= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_IFEXTRN + i*2 + 1 ] ] ) ?											W_O_CTRL[ W_DstPort[ ID_OFFSET_IFEXTRN + i*2 + 1 ] ] : '0;

			// Un-used for Store Unit
			W_O_Data[ ID_OFFSET_IFEXTRN + i*2 + 1 ]	= '0;
		end
	end

	// Load Unit
	assign W_I_Data[ ID_OFFSET_IFEXTRN + 0 ]	= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_IFEXTRN + 0 ] ] & W_VldPort[ ID_OFFSET_IFEXTRN + 0 ] ) ?		W_O_Data[ W_SrcPort[ ID_OFFSET_IFEXTRN + 0 ] ] : '0;
	assign W_I_CTRL[ ID_OFFSET_IFEXTRN + 0 ]	= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_IFEXTRN + 0 ] ] ) ?									W_O_CTRL[ W_DstPort[ ID_OFFSET_IFEXTRN + 0 ] ] : '0;

	// Store Unit
	assign W_I_Data[ ID_OFFSET_IFEXTRN + 1 ]	= ( ~I_Boot & Ld[ W_SrcPort[ ID_OFFSET_IFEXTRN + 1 ] ] & W_VldPort[ ID_OFFSET_IFEXTRN + 1 ] ) ?		W_O_Data[ W_SrcPort[ ID_OFFSET_IFEXTRN + 1 ] ] : '0;
	assign W_I_CTRL[ ID_OFFSET_IFEXTRN + 1 ]	= ( ~I_Boot & W_VldPort[ W_DstPort[ ID_OFFSET_IFEXTRN + 1 ] ] ) ?									W_O_CTRL[ W_DstPort[ ID_OFFSET_IFEXTRN + 1 ] ] : '0;


	//// BRAMs														////
	for ( genvar i=0; i<NUM_BRAMS; ++i ) begin: g_bram
		BRAM BRAM (
			.clock(		clock									),
			.reset(		reset									),
			.I_Data(	W_I_Data[ ID_OFFSET_BRAM + i ]			),
			.O_Data(	W_O_Data[ ID_OFFSET_BRAM + i ]			),
			.I_CTRL(	W_I_CTRL[ ID_OFFSET_BRAM + i ]			),
			.O_CTRL(	W_O_CTRL[ ID_OFFSET_BRAM + i ]			),
			.I_St(		Ld[ W_SrcPort[ ID_OFFSET_BRAM + i ] ]	),
			.I_Ld(		St[ W_DstPort[ ID_OFFSET_BRAM + i ] ]	),
			.I_SelDst(	SelDst									),
			.I_RCFG(	W_RCFG									),
			.I_Done(	Port_Valid								),
			.O_Busy(	W_Busy[ ID_OFFSET_BRAM + i ]			)
		);
	end


	//// Porting to External Memory and Compute Tile				////
	for ( genvar i=0; i<NUM_ELMS; ++i ) begin: if_logic
		IFLogic IFLogic (
			.clock(		clock									),
			.reset(		reset									),
			.I_St(	St[ W_DstPort[ ID_OFFSET_IFLOGIC + i ] ]	),
			.I_Ld(	Ld[ W_SrcPort[ ID_OFFSET_IFLOGIC + i ] ]	),
			.I_FTk_IF(	W_I_Data[ ID_OFFSET_IFLOGIC + i ]		),
			.O_BTk_IF(	W_O_CTRL[ ID_OFFSET_IFLOGIC + i ]		),
			.O_FTk_IF(	W_O_Data[ ID_OFFSET_IFLOGIC + i ]		),
			.I_BTk_IF(	W_I_CTRL[ ID_OFFSET_IFLOGIC + i ]		),
			.I_FTk(		I_Port[ i ].IO_Data						),
			.O_BTk(		O_Port[ i ].IO_CTRL						),
			.O_FTk(		O_Port[ i ].IO_Data						),
			.I_BTk(		I_Port[ i ].IO_CTRL						),
			.O_Header(											),
			.O_Req_FTk(	Req_FTk[ i ]							)
		);
	end


	//// ME_IF <-> External World									////
	for ( genvar i=0; i<NUM_EXT_IFS; ++i ) begin: emem_if
		DReg ILdDReg(
			.clock(		clock									),
			.reset(		reset									),
			.I_We(		1'b1									),
			.I_FTk(		W_Ld_FTk[ i ]							),
			.O_BTk(		W_Ld_BTk[ i ]							),
			.O_FTk(		W_Ld_Req_FTk[ i ]						),
			.I_BTk(		W_Ld_Req_BTk[ i ]						)
		);

	//	 Load/Store Unit for External Memory
		EMEM_IF EMEM_IF (
			.clock(		clock									),
			.reset(		reset									),
			.I_Boot(	I_Boot									),
			.I_FTk(		W_Ld_Req_FTk[ i ]						),
			.O_BTk(		W_Ld_Req_BTk[ i ]						),
			.O_FTk(		Ld_FTk_[ i ]							),
			.I_BTk(		Ld_BTk_[ i ]							),
			.O_Ld_Req(	Ld_Req[ i ]								),
			.O_Ld_Addr(	Ld_Addr[ i ]							),
			.I_Ld_Ack(	Ld_Ack[ i ]								),
			.I_Ld_Data(	Ld_FTk[ i ]								),
			.O_Ld_BTk(	Ld_BTk[ i ]								),
			.O_St_Req(	St_Req[ i ]								),
			.O_St_Addr(	St_Addr[ i ]							),
			.I_St_Ack(	St_Ack[ i ]								),
			.O_St_Data(	St_Data[ i ]							),
			.I_St_BTk(	St_BTk[ i ]								),
			.I_St_FTk(	W_I_Data[ ID_OFFSET_IFEXTRN + i*2 + 1 ]	),
			.O_St_BTk(	W_O_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 1 ]	)
		);

		FanOut_Link #(
			.WIDTH_DATA(	WIDTH_DATA							),
			.NUM_LINK(		2									),
			.NUM_CHANNEL(	1									),
			.WIDTH_LENGTH(	10									),
			.DEPTH_FIFO(	16									),
			.TYPE_FTK(		FTk_12_t							),
			.TYPE_BTK(		BTk_12_t							),
			.TYPE_I_FTK(	FTk_1_t								),
			.TYPE_O_BTK(	BTk_1_t								),
			.TYPE_BITS(		logic[0:0][1:0]						)
		) BranchLdUnit
		(
			.clock(			clock								),
			.reset(			reset								),
			.I_FTk(			Ld_FTk_[ i ]						),
			.O_BTk(			Ld_BTk_[ i ]						),
			.O_FTk(			Branch_FTk[ i ]						),
			.I_BTk(			Branch_BTk[ i ]						),
			.O_InC(												)
		);

		DReg OLdDReg(
			.clock(		clock									),
			.reset(		reset									),
			.I_We(		1'b1									),
			.I_FTk(		Branch_FTk[ i ][0]						),
			.O_BTk(		W_Branch_BTk[ i ][0]					),
			.O_FTk(		W_O_Data[ ID_OFFSET_IFEXTRN + i*2 + 0 ]	),
			.I_BTk(		W_I_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ]	)
		);
	end

	assign Start_Load		= ( W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].v & W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].a & ~W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].r );
	assign End_Load			= ( W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].v & W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].a &  W_O_Data[ ID_OFFSET_IFEXTRN + 0 ].r );

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			State_Load		<= 1'b0;
		end
		else if ( End_Load ) begin
			State_Load		<= 1'b0;
		end
		else if ( Start_Load & ~State_Store ) begin
			State_Load		<= 1'b1;
		end
	end

	assign Start_Store		= ( W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].v & W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].a & ~W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].r );
	assign End_Store		= ( W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].v & W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].a &  W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].r );

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			State_Store		<= 1'b0;
		end
		else if ( End_Store ) begin
			State_Store		<= 1'b0;
		end
		else if ( Start_Store & ~State_Load ) begin
			State_Store		<= 1'b1;
		end
	end

	assign Enable_Load		= ( W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].v & W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].a &  W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].r );
	assign Stop_Load		= ( W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].v & W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].a & ~W_I_Data[ ID_OFFSET_IFEXTRN + 1 ].r );

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Port_Valid	<= 1'b0;
		end
		else if ( W_Port_Req & ( W_PDstID != (ID_OFFSET_IFEXTRN+1) ) ) begin
			R_Port_Valid	<= 1'b0;
		end
		else if ( Port_Valid | Enable_Load ) begin
			R_Port_Valid	<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Clr_Stall		<= 1'b0;
		end
		else begin
			Clr_Stall		<= ( ~R_Port_Valid & Port_Valid ) & ( W_PDstID != (ID_OFFSET_IFEXTRN+1) );
		end
	end


	assign Branch_AcqOut	= Branch_FTk[0][1][0].v & Branch_FTk[0][1][0].a & Branch_FTk[0][1][0].r;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stall			<= 1'b0;
		end
		else if ( Clr_Stall | End_Load | End_Store | Enable_Load  ) begin
			R_Stall			<= 1'b0;
		end
		else if ( Branch_AcqOut | Stop_Load  | ( Branch_FTk[0][1][0].v & Branch_FTk[0][1][0].a & Branch_FTk[0][1][0].r ) ) begin
			R_Stall			<= 1'b1;
		end
	end

	for ( genvar i=0; i<NUM_EXT_IFS; ++i ) begin: g_port
		assign O_Ld_Req[ i ]	= Ld_Req[ i ];
		assign O_Ld_Addr[ i ]	= Ld_Addr[ i ];
		assign Ld_Ack[ i ]		= I_Ld_Ack[ i ];

		assign Ld_FTk[ i ] 		= W_Ld_Req_FTk[ i ];

		assign W_Ld_FTk[ i ]	= I_Ld_FTk[ i ];
		assign O_Ld_BTk[ i ]	= W_Ld_BTk[ i ];
		assign W_O_CTRL[ ID_OFFSET_IFEXTRN + i*2 + 0 ] = W_Ld_BTk[ i ];

		assign O_St_Req[ i ]	= St_Req[ i ];
		assign O_St_Addr[ i ]	= St_Addr[ i ];
		assign St_Ack[ i ]		= I_St_Ack[ i ];

		assign O_St_FTk[ i ]	= St_Data[ i ];
		assign St_BTk[ i ]		= I_St_BTk[ i ];
	end

endmodule
