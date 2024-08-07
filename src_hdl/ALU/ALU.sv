///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Arithmetic Logic Unit
//	Module Name:	ALU
//	Function:
//					Arithmetic and Logic Unit
//					- Integer Addition/Subtraction
//					- Integer Multiplication
//					- Logic
//					- Shift/Rotate
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module ALU
	import	pkg_en::*;
	import	pkg_alu::*;
	import	pkg_extend_index::*;
#(
	parameter WIDTH_DATA			= 32,
	parameter WIDTH_LENGTH			= 10,
	parameter WIDTH_OPCODE			= 24,
	parameter WIDTH_CONSTANT		= 8
)(
	input							clock,
	input							reset,
	input	FTk_t					I_FTkA,				//Source-1
	output	BTk_t					O_BTkA,				//Source-A
	input	FTk_t					I_FTkB,				//Source-B
	output	BTk_t					O_BTkB,				//Source-B
	input	FTk_t					I_FTkC,				//Soiurce-C
	output	BTk_t					O_BTkC,				//Source-C
	output	FTk_t					O_FTk,				//Forward Token
	input	BTk_t					I_BTk,				//Backward Token
	output	bit2_t					O_InCA,				//Condition to FanIn
	output	bit2_t					O_InCB,				//Condition to FanIn
	output	bit2_t					O_InCC				//Condition to FanIn
);


	localparam int LSB_CONFIG		= WIDTH_DATA-3;

	//// Token Decode												////
	//	 Token Decoder-A
	logic						TokenDecA_acq_message;
	logic						TokenDecA_rls_message;
	logic						TokenDecA_acq_flagmsg;
	logic						TokenDecA_rls_flagmsg;

	logic						AcqMsgA;
	logic						AcqFlgA;
	logic						AcqA;
	logic						RlsMsgA;
	logic						RlsFlgA;
	logic						RlsA;

	logic						TokenDecB_acq_message;
	logic						TokenDecB_rls_message;
	logic						TokenDecB_acq_flagmsg;
	logic						TokenDecB_rls_flagmsg;

	logic						AcqMsgB;
	logic						AcqFlgB;
	logic						AcqB;
	logic						RlsMsgB;
	logic						RlsFlgB;
	logic						RlsB;

	logic						TokenDecC_acq_message;
	logic						TokenDecC_rls_message;
	logic						TokenDecC_acq_flagmsg;
	logic						TokenDecC_rls_flagmsg;

	logic						AcqMsgC;
	logic						AcqFlgC;
	logic						AcqC;
	logic						RlsMsgC;
	logic						RlsFlgC;
	logic						RlsC;

	logic [WIDTH_DATA-1:0]		AttribDecA_I_Data;
	logic						AttribDecA_is_PullReq;
	logic						AttribDecA_is_DataWord;
	logic						AttribDecA_is_RConfigData;
	logic						AttribDecA_is_PConfigData;
	logic						AttribDecA_is_RoutingData;
	logic						AttribDecA_is_Shared;
	logic						AttribDecA_is_NonZero;
	logic						AttribDecA_is_Dense;
	logic						AttribDecA_is_MyAttribute;
	logic						AttribDecA_is_Term_Block;
	logic						AttribDecA_is_In_Cond;
	logic [WIDTH_LENGTH-1:0]	AttribDecA_O_Length;

	logic						is_Valid_A;
	logic						is_RoutingData_A;
	logic						is_PConfigData_A;
	logic						is_RConfigData_A;

	logic [WIDTH_DATA-1:0]		AttribDecB_I_Data;
	logic						AttribDecB_is_PullReq;
	logic						AttribDecB_is_DataWord;
	logic						AttribDecB_is_RConfigData;
	logic						AttribDecB_is_PConfigData;
	logic						AttribDecB_is_RoutingData;
	logic						AttribDecB_is_Shared;
	logic						AttribDecB_is_Dense;
	logic						AttribDecB_is_MyAttribute;
	logic						AttribDecB_is_Term_Block;
	logic						AttribDecB_is_In_Cond;
	logic [WIDTH_LENGTH-1:0]	AttribDecB_O_Length;

	logic						is_Valid_B;
	logic						is_RoutingData_B;
	logic						is_PConfigData_B;
	logic						is_RConfigData_B;

	logic [WIDTH_DATA-1:0]		AttribDecC_I_Data;
	logic						AttribDecC_is_PullReq;
	logic						AttribDecC_is_DataWord;
	logic						AttribDecC_is_RConfigData;
	logic						AttribDecC_is_PConfigData;
	logic						AttribDecC_is_RoutingData;
	logic						AttribDecC_is_Shared;
	logic						AttribDecC_is_Dense;
	logic						AttribDecC_is_MyAttribute;
	logic						AttribDecC_is_Term_Block;
	logic						AttribDecC_is_In_Cond;
	logic [WIDTH_LENGTH-1:0]	AttribDecC_O_Length;

	logic						is_Valid_C;
	logic						is_RoutingData_C;
	logic						is_PConfigData_C;
	logic						is_RConfigData_C;

	FTk_t						ConfigDataA;
	FTk_t						ConfigDataB;
	FTk_t						ConfigDataC;

	FTk_t                       OperandA;
	BTk_t						InRegA_I_BTk;
	BTk_t						InRegA_O_BTk;
	FTk_t						InRegA_FTk;
	BTk_t						InRegA_BTk;

	FTk_t						OperandB;
	BTk_t						InRegB_I_BTk;
	BTk_t						InRegB_O_BTk;
	FTk_t						InRegB_FTk;
	BTk_t						InRegB_BTk;

	FTk_t						OperandC;
	BTk_t						InRegC_I_BTk;
	BTk_t						InRegC_O_BTk;
	FTk_t						InRegC_FTk;
	BTk_t						InRegC_BTk;

	logic	[WIDTH_DATA-1:0]	Instruction;
	logic	[WIDTH_DATA-1:0]	R_IR;

	cond_t				    	Condition;

	// Opcode and Condition Code
	logic	[WIDTH_CMD-1:0]		Command;
	logic	[2:0]				ConfigData;
	logic	[1:0]				SelA;
	logic	[1:0]				SelB;
	logic						SelD;

	logic						SelMS;
	logic						SelAL;

	logic						EnSrcA;
	logic						EnSrcB;
	logic						EnSrcC;

	logic						Active;
	logic						Done;

	FTk_t						DataPath_FTkA;
	FTk_t						DataPath_FTkB;
	FTk_t						DataPath_FTkC;
	FTk_t						DataPath_FTk;

	BTk_t						DataPath_BTkA;
	BTk_t						DataPath_BTkB;
	BTk_t						DataPath_BTkC;

	logic [WIDTH_LENGTH-1:0]	PortA_I_Length;
	logic						PortA_I_Valid;
	logic						PortA_I_Valid_Other1;
	logic						PortA_I_Valid_Other2;
	logic						PortA_I_Acq;
	logic						PortA_I_Rls;
	logic						PortA_I_Nack;
	logic						PortA_I_Done;
	logic						PortA_is_Ready1;
	logic						PortA_is_Ready2;
	logic						PortA_is_PConfigData;
	logic						PortA_is_RConfigData;
	logic						PortA_is_RouteData;
	logic						PortA_is_AuxData;
	logic						PortA_O_Ready;
	logic						PortA_O_Bypass;
	logic						PortA_O_SendHead;
	logic						PortA_O_InputData;
	logic						PortA_O_SetAttrib;
	logic						PortA_O_Nack;
	logic [WIDTH_LENGTH-1:0]	PortA_O_Length;
	logic						PortA_O_Configure;
	logic						PortA_O_SelPort;
	logic						PortA_O_Backup_Attrib;
	logic						PortA_O_Set_Backup;
	logic						PortA_O_is_Valid;

	logic [WIDTH_LENGTH-1:0]	PortB_I_Length;
	logic						PortB_I_Valid;
	logic						PortB_I_Valid_Other1;
	logic						PortB_I_Valid_Other2;
	logic						PortB_I_Acq;
	logic						PortB_I_Rls;
	logic						PortB_I_Nack;
	logic						PortB_I_Done;
	logic						PortB_is_Ready1;
	logic						PortB_is_Ready2;
	logic						PortB_is_PConfigData;
	logic						PortB_is_RConfigData;
	logic						PortB_is_RouteData;
	logic						PortB_is_AuxData;
	logic						PortB_O_Ready;
	logic						PortB_O_Bypass;
	logic						PortB_O_SendHead;
	logic						PortB_O_InputData;
	logic						PortB_O_SetAttrib;
	logic						PortB_O_Nack;
	logic [WIDTH_LENGTH-1:0]	PortB_O_Length;
	logic						PortB_O_Configure;
	logic						PortB_O_SelPort;
	logic						PortB_O_Backup_Attrib;
	logic						PortB_O_Set_Backup;
	logic						PortB_O_is_Valid;

	logic [WIDTH_LENGTH-1:0]	PortC_I_Length;
	logic						PortC_I_Valid;
	logic						PortC_I_Valid_Other1;
	logic						PortC_I_Valid_Other2;
	logic						PortC_I_Acq;
	logic						PortC_I_Rls;
	logic						PortC_I_Nack;
	logic						PortC_I_Done;
	logic						PortC_is_Ready1;
	logic						PortC_is_Ready2;
	logic						PortC_is_PConfigData;
	logic						PortC_is_RConfigData;
	logic						PortC_is_RouteData;
	logic						PortC_is_AuxData;
	logic						PortC_O_Ready;
	logic						PortC_O_Bypass;
	logic						PortC_O_SendHead;
	logic						PortC_O_InputData;
	logic						PortC_O_SetAttrib;
	logic						PortC_O_Nack;
	logic [WIDTH_LENGTH-1:0]	PortC_O_Length;
	logic						PortC_O_Configure;
	logic						PortC_O_SelPort;
	logic						PortC_O_Backup_Attrib;
	logic						PortC_O_Set_Backup;
	logic						PortC_O_is_Valid;

	logic						Rls;

	logic	[WIDTH_LENGTH-1:0]	Port_Length;

	FTk_t						Attrib_FTk;
	logic						Attrib_Shared;
	logic						Attrib_NonZero;

	logic						SendHead_A;
	logic						SendHead_B;
	logic						SendHead_C;

	logic						Bypass_A;
	logic						Bypass_B;
	logic						Bypass_C;

	logic						SetAttrib;
	logic						Configure;

	FTk_t						In_Buff_FTkA;
	FTk_t						In_Buff_FTkB;
	FTk_t						In_Buff_FTkC;


	//// Capture Signal												////
	FTk_t						Backup_Attrib_A;
	FTk_t						Backup_Attrib_B;
	FTk_t						Backup_Attrib_C;

	logic						R_Attrib_Shared_A;
	logic						R_Attrib_Shared_B;
	logic						R_Attrib_Shared_C;

	logic						R_Attrib_NonZero_A;
	logic						R_Attrib_NonZero_B;
	logic						R_Attrib_NonZero_C;

	logic						R_Configured;


	//// Logic Body													////
	//	 Token Decoders
	assign AcqMsgA			= TokenDecA_acq_message;
	assign AcqFlgA			= TokenDecA_acq_flagmsg;
	assign AcqA				= AcqMsgA | AcqFlgA;

	assign RlsMsgA			= TokenDecA_rls_message;
	assign RlsFlgA			= TokenDecA_rls_flagmsg;
	assign RlsA				= RlsMsgA | RlsFlgA;

	//	 Token Decoder-A
	TokenDec TokenDecA (
		.I_FTk(				I_FTkA						),
		.O_acq_message(		TokenDecA_acq_message		),
		.O_rls_message(		TokenDecA_rls_message		),
		.O_acq_flagmsg(		TokenDecA_acq_flagmsg		),
		.O_rls_flagmsg(		TokenDecA_rls_flagmsg		)
	);

	//	 Token Decoder-B
	assign AcqMsgB			= TokenDecB_acq_message;
	assign AcqFlgB			= TokenDecB_acq_flagmsg;
	assign AcqB				= AcqMsgB | AcqFlgB;

	assign RlsMsgB			= TokenDecB_rls_message;
	assign RlsFlgB			= TokenDecB_rls_flagmsg;
	assign RlsB				= RlsMsgB | RlsFlgB;

	TokenDec TokenDecB (
		.I_FTk(				I_FTkB						),
		.O_acq_message(		TokenDecB_acq_message		),
		.O_rls_message(		TokenDecB_rls_message		),
		.O_acq_flagmsg(		TokenDecB_acq_flagmsg		),
		.O_rls_flagmsg(		TokenDecB_rls_flagmsg		)
	);

	//	 Token Decoder-C
	assign AcqMsgC			= TokenDecC_acq_message;
	assign AcqFlgC			= TokenDecC_acq_flagmsg;
	assign AcqC				= AcqMsgC | AcqFlgC;

	assign RlsMsgC			= TokenDecC_rls_message;
	assign RlsFlgC			= TokenDecC_rls_flagmsg;
	assign RlsC				= RlsMsgC | RlsFlgC;

	TokenDec TokenDecC (
		.I_FTk(				I_FTkC						),
		.O_acq_message(		TokenDecC_acq_message		),
		.O_rls_message(		TokenDecC_rls_message		),
		.O_acq_flagmsg(		TokenDecC_acq_flagmsg		),
		.O_rls_flagmsg(		TokenDecC_rls_flagmsg		)
	);


	//// Attribute Block Decode										////
	//	 Attribute Decoder-A
	assign is_Valid_A		= PortA_O_is_Valid;
	assign is_RoutingData_A	= AttribDecA_is_RoutingData & is_Valid_A;
	assign is_PConfigData_A	= AttribDecA_is_PConfigData & is_Valid_A;
	assign is_RConfigData_A	= AttribDecA_is_RConfigData & is_Valid_A;

	assign AttribDecA_I_Data= I_FTkA.d;
	AttributeDec AttribDecA
	(
		.I_Data(			AttribDecA_I_Data			),
		.is_Pull(			AttribDecA_is_PullReq		),
		.is_DataWord(		AttribDecA_is_DataWord		),
		.is_RConfigData(	AttribDecA_is_RConfigData	),
		.is_PConfigData(	AttribDecA_is_PConfigData	),
		.is_RoutingData(	AttribDecA_is_RoutingData	),
		.is_Shared(			AttribDecA_is_Shared		),
		.is_NonZero(		AttribDecA_is_NonZero		),
		.is_Dense(			AttribDecA_is_Dense			),
		.is_MyAttribute(	AttribDecA_is_MyAttribute	),
		.is_Term_Block(		AttribDecA_is_Term_Block	),
		.is_In_Cond(		AttribDecA_is_In_Cond		),
		.O_Length(			AttribDecA_O_Length			)
	);

	//	 Attribute Decoder-B
	assign is_Valid_B		= PortB_O_is_Valid;
	assign is_RoutingData_B	= AttribDecB_is_RoutingData & is_Valid_B;
	assign is_PConfigData_B	= AttribDecB_is_PConfigData & is_Valid_B;
	assign is_RConfigData_B	= AttribDecB_is_RConfigData & is_Valid_B;

	assign AttribDecB_I_Data= I_FTkB.d;
	AttributeDec AttribDecB (
		.I_Data(			AttribDecB_I_Data			),
		.is_Pull(			AttribDecB_is_PullReq		),
		.is_DataWord(		AttribDecB_is_DataWord		),
		.is_RConfigData(	AttribDecB_is_RConfigData	),
		.is_PConfigData(	AttribDecB_is_PConfigData	),
		.is_RoutingData(	AttribDecB_is_RoutingData	),
		.is_Shared(			AttribDecB_is_Shared		),
		.is_NonZero(		AttribDecB_is_NonZero		),
		.is_Dense(			AttribDecB_is_Dense			),
		.is_MyAttribute(	AttribDecB_is_MyAttribute	),
		.is_Term_Block(		AttribDecB_is_Term_Block	),
		.is_In_Cond(		AttribDecB_is_In_Cond		),
		.O_Length(			AttribDecB_O_Length			)
	);

	//	 Attribute Decoder-C
	assign is_Valid_C		= PortC_O_is_Valid;
	assign is_RoutingData_C	= AttribDecC_is_RoutingData & is_Valid_C;
	assign is_PConfigData_C	= AttribDecC_is_PConfigData & is_Valid_C;
	assign is_RConfigData_C	= AttribDecC_is_RConfigData & is_Valid_C;

	assign AttribDecC_I_Data= I_FTkC.d;
	AttributeDec AttribDecC (
		.I_Data(			AttribDecC_I_Data			),
		.is_Pull(			AttribDecC_is_PullReq		),
		.is_DataWord(		AttribDecC_is_DataWord		),
		.is_RConfigData(	AttribDecC_is_RConfigData	),
		.is_PConfigData(	AttribDecC_is_PConfigData	),
		.is_RoutingData(	AttribDecC_is_RoutingData	),
		.is_Shared(			AttribDecC_is_Shared		),
		.is_NonZero(		AttribDecC_is_NonZero		),
		.is_Dense(			AttribDecC_is_Dense			),
		.is_MyAttribute(	AttribDecC_is_MyAttribute	),
		.is_Term_Block(		AttribDecC_is_Term_Block	),
		.is_In_Cond(		AttribDecC_is_In_Cond		),
		.O_Length(			AttribDecC_O_Length			)
	);


	//// Porting Configuration Data									////
	assign ConfigDataA		= I_FTkA;
	assign ConfigDataB		= I_FTkB;
	assign ConfigDataC		= I_FTkC;


	//// Backup for Attribute Word									////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Backup_Attrib_A	<= '0;
		end
		else if ( PortA_O_Backup_Attrib ) begin
			Backup_Attrib_A	<= I_FTkA;
		end
		else begin
			Backup_Attrib_A	<= Backup_Attrib_A;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Backup_Attrib_B	<= '0;
		end
		else if ( PortB_O_Backup_Attrib ) begin
			Backup_Attrib_B	<= I_FTkB;
		end
		else begin
			Backup_Attrib_B	<= Backup_Attrib_B;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Backup_Attrib_C	<= '0;
		end
		else if ( PortC_O_Backup_Attrib ) begin
			Backup_Attrib_C	<= I_FTkC;
		end
		else begin
			Backup_Attrib_C	<= Backup_Attrib_C;
		end
	end


	//// Input Register												////
	//	 Input Reg-A
	assign InRegA_I_BTk.n	= ( PortA_O_InputData ) ? DataPath_BTkA.n : I_BTk.n | PortA_O_Nack;
	assign InRegA_I_BTk.t	= ( PortA_O_InputData ) ? DataPath_BTkA.t : I_BTk.t;
	assign InRegA_I_BTk.v	= ( PortA_O_InputData ) ? DataPath_BTkA.v : I_BTk.v;
	assign InRegA_I_BTk.c	= ( PortA_O_InputData ) ? DataPath_BTkA.c : I_BTk.c;
	BTk_t					InRegA_BTk_;
	assign InRegA_BTk.n		= InRegA_BTk_.n | Full_Buff_A;
	assign InRegA_BTk.t		= InRegA_BTk_.t;
	assign InRegA_BTk.v		= InRegA_BTk_.v;
	assign InRegA_BTk.c		= InRegA_BTk_.c;
	DReg InRegA (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_FTkA						),
		.I_BTk(				InRegA_BTk					),
		.O_FTk(				InRegA_FTk					),
		.O_BTk(				InRegA_O_BTk				)
	);

	assign In_Buff_FTkA			= ( PortA_O_InputData ) ? InRegA_FTk : '0;
	logic					Full_Buff_A;
	SimpleBuff #(
		.DEPTH_BUFF(		8							),
		.THRESHOLD(			4							),
		.TYPE_FWRD(			FTk_t						)
	) SimpleBuffA
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				In_Buff_FTkA				),
		.O_BTk(				InRegA_BTk_					),
		.O_FTk(				OperandA					),
		.I_BTk(				InRegA_I_BTk				),
		.O_Empty(										),
		.O_Full(			Full_Buff_A					)
	);

	//	 Input Reg-B
	assign InRegB_I_BTk.n	= ( PortB_O_InputData ) ? DataPath_BTkB.n : I_BTk.n | PortB_O_Nack;
	assign InRegB_I_BTk.t	= ( PortB_O_InputData ) ? DataPath_BTkB.t : I_BTk.t;
	assign InRegB_I_BTk.v	= ( PortB_O_InputData ) ? DataPath_BTkB.v : I_BTk.v;
	assign InRegB_I_BTk.c	= ( PortB_O_InputData ) ? DataPath_BTkB.c : I_BTk.c;
	BTk_t					InRegB_BTk_;
	assign InRegB_BTk.n		= InRegB_BTk_.n | Full_Buff_B;
	assign InRegB_BTk.t		= InRegB_BTk_.t;
	assign InRegB_BTk.v		= InRegB_BTk_.v;
	assign InRegB_BTk.c		= InRegB_BTk_.c;
	DReg InRegB (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_FTkB						),
		.I_BTk(				InRegB_BTk					),
		.O_FTk(				InRegB_FTk					),
		.O_BTk(				InRegB_O_BTk				)
	);

	assign In_Buff_FTkB			= ( PortB_O_InputData ) ? InRegB_FTk : '0;
	logic					Full_Buff_B;
	SimpleBuff #(
		.DEPTH_BUFF(		8							),
		.THRESHOLD(			4							),
		.TYPE_FWRD(			FTk_t						)
	) SimpleBuffB
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				In_Buff_FTkB				),
		.O_BTk(				InRegB_BTk_					),
		.O_FTk(				OperandB					),
		.I_BTk(				InRegB_I_BTk				),
		.O_Empty(										),
		.O_Full(			Full_Buff_B					)
	);

	//	 Input Reg-C
	assign InRegC_I_BTk.n	= ( PortC_O_InputData ) ? DataPath_BTkC.n : I_BTk.n | PortC_O_Nack;
	assign InRegC_I_BTk.t	= ( PortC_O_InputData ) ? DataPath_BTkC.t : I_BTk.t;
	assign InRegC_I_BTk.v	= ( PortC_O_InputData ) ? DataPath_BTkC.v : I_BTk.v;
	assign InRegC_I_BTk.c	= ( PortC_O_InputData ) ? DataPath_BTkC.c : I_BTk.c;
	BTk_t					InRegC_BTk_;
	assign InRegC_BTk.n		= InRegC_BTk_.n | Full_Buff_C;
	assign InRegC_BTk.t		= InRegC_BTk_.t;
	assign InRegC_BTk.v		= InRegC_BTk_.v;
	assign InRegC_BTk.c		= InRegC_BTk_.c;
	DReg InRegC (
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_FTkC						),
		.I_BTk(				InRegC_BTk					),
		.O_FTk(				InRegC_FTk					),
		.O_BTk(				InRegC_O_BTk				)
	);

	assign In_Buff_FTkC			= ( PortC_O_InputData ) ? InRegC_FTk : '0;
	logic					Full_Buff_C;
	SimpleBuff #(
		.DEPTH_BUFF(		8							),
		.THRESHOLD(			4							),
		.TYPE_FWRD(			FTk_t						)
	) SimpleBuffC
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				In_Buff_FTkC				),
		.O_BTk(				InRegC_BTk_					),
		.O_FTk(				OperandC					),
		.I_BTk(				InRegC_I_BTk				),
		.O_Empty(										),
		.O_Full(			Full_Buff_C					)
	);


	//// Configuration												////
	assign Instruction		= ( PortA_O_Configure ) ? 	InRegA_FTk.d :
								( PortB_O_Configure ) ? InRegB_FTk.d :
								( PortC_O_Configure ) ? InRegC_FTk.d :
														'0;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_IR			<= '0;
		end
		else if ( Configure ) begin
			R_IR			<= Instruction;
		end
		else begin
			R_IR			<= R_IR;
		end
	end

	// Datapath Interconnect
	assign Command			= R_IR[MSB_COMMAND:LSB_COMMAND];
	assign ConfigData		= Command[MSB_CFG:LSB_CFG];


	assign SelA				= ( ConfigData[1:0] == 2'h3 ) ?		2'h2 :
								( ConfigData[2:0] == 3'h5 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h4 ) ?	2'h0 :
								( ConfigData[2:0] == 3'h2 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h1 ) ?	2'h1 :
																2'h0;

	assign SelB				=( ConfigData[1:0] == 2'h3 ) ?		2'h2 :
								( ConfigData[2:0] == 3'h5 ) ?	2'h0 :
								( ConfigData[2:0] == 3'h4 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h2 ) ?	2'h1 :
								( ConfigData[2:0] == 3'h1 ) ?	2'h1 :
																2'h0;

	assign SelD				= ( ConfigData[1:0] == 2'h3 ) ?		1'b1 :
								( ConfigData[2:0] == 3'h2 ) ?	1'b1 :
								( ConfigData[2:1] == 2'h3 ) ?	1'b0 :
																1'b0;

	assign Condition		= R_IR[WIDTH_COND-1:0];

	assign SelMS			= ConfigData[MSB_SELMS:MSB_SELMS];
	assign SelAL			= ( ConfigData[MSB_SELAL:LSB_SELAL] == 2'h0 ) | ConfigData[LSB_SELAL];

	// Source-Operand Enable
	assign EnSrcA			= ( ( SelA == 2'h1 ) | SelMS );
	assign EnSrcB			= ( ( SelB == 2'h1 ) | SelD );
	assign EnSrcC			= ( ConfigData[1:0] == 2'h3 );

	// Configuration Flag
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Configured	<= 1'b0;
		end
		else if ( Configure ) begin
			R_Configured	<= 1'b1;
		end
		else if ( Rls ) begin
			R_Configured	<= 1'b0;
		end
	end

	// Activate Datapath after Configuration
	assign Active			= R_Configured;


	//// Porting Control											////
	assign Done				= Rls;

	//	 Port-A
	assign PortA_I_Length		= AttribDecA_O_Length;
	assign PortA_I_Valid		= I_FTkA.v;
	assign PortA_I_Valid_Other1	= I_FTkB.v;
	assign PortA_I_Valid_Other2	= I_FTkC.v;
	assign PortA_I_Acq			= AcqA;
	assign PortA_I_Rls			= RlsA;
	assign PortA_I_Nack			= I_BTk.n;
	assign PortA_I_Done			= Done;
	assign PortA_is_Ready1		= PortB_O_Ready;
	assign PortA_is_Ready2		= PortC_O_Ready;
	assign PortA_is_PConfigData	= AttribDecA_is_PConfigData;
	assign PortA_is_RConfigData	= AttribDecA_is_RConfigData;
	assign PortA_is_RouteData	= AttribDecA_is_RoutingData;
	assign PortA_is_AuxData		= AttribDecA_is_DataWord;
	PortSync #(
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) PortA
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Length(			PortA_I_Length				),
		.I_Valid(			PortA_I_Valid				),
		.I_Valid_Other1(	PortA_I_Valid_Other1		),
		.I_Valid_Other2(	PortA_I_Valid_Other2		),
		.I_Acq(				PortA_I_Acq					),
		.I_Rls(				PortA_I_Rls					),
		.I_Nack(			PortA_I_Nack				),
		.I_Done(			PortA_I_Done				),
		.is_Configured(		R_Configured				),
		.is_Ready1(			PortA_is_Ready1				),
		.is_Ready2(			PortA_is_Ready2				),
		.is_PConfigData(	PortA_is_PConfigData		),
		.is_RConfigData(	PortA_is_RConfigData		),
		.is_RouteData(		PortA_is_RouteData			),
		.is_AuxData(		PortA_is_AuxData			),
		.O_Ready(			PortA_O_Ready				),
		.O_Bypass(			PortA_O_Bypass				),
		.O_SendHead(		PortA_O_SendHead			),
		.O_InputData(		PortA_O_InputData			),
		.O_SetDAttrib(		PortA_O_SetAttrib			),
		.O_Nack_My(			PortA_O_Nack				),
		.O_Length(			PortA_O_Length				),
		.O_Configure(		PortA_O_Configure			),
		.O_SelPort(			PortA_O_SelPort				),
		.O_Backup_Attrib(	PortA_O_Backup_Attrib 		),
		.O_Set_Backup(		PortA_O_Set_Backup			),
		.O_is_Valid(		PortA_O_is_Valid 			)
	);

	//	 Port-B
	assign PortB_I_Length		= AttribDecB_O_Length;
	assign PortB_I_Valid		= I_FTkB.v;
	assign PortB_I_Valid_Other1	= I_FTkC.v;
	assign PortB_I_Valid_Other2	= I_FTkA.v;
	assign PortB_I_Acq			= AcqB;
	assign PortB_I_Rls			= RlsB;
	assign PortB_I_Nack			= I_BTk.n;
	assign PortB_I_Done			= Done;
	assign PortB_is_Ready1		= PortC_O_Ready;
	assign PortB_is_Ready2		= PortA_O_Ready;
	assign PortB_is_PConfigData	= AttribDecB_is_PConfigData;
	assign PortB_is_RConfigData	= AttribDecB_is_RConfigData;
	assign PortB_is_RouteData	= AttribDecB_is_RoutingData;
	assign PortB_is_AuxData		= AttribDecB_is_DataWord;
	PortSync #(
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) PortB
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Length(			PortB_I_Length				),
		.I_Valid(			PortB_I_Valid				),
		.I_Valid_Other1(	PortB_I_Valid_Other1		),
		.I_Valid_Other2(	PortB_I_Valid_Other2		),
		.I_Acq(				PortB_I_Acq					),
		.I_Rls(				PortB_I_Rls					),
		.I_Nack(			PortB_I_Nack				),
		.I_Done(			PortB_I_Done				),
		.is_Configured(		R_Configured				),
		.is_Ready1(			PortB_is_Ready1				),
		.is_Ready2(			PortB_is_Ready2				),
		.is_PConfigData(	PortB_is_PConfigData		),
		.is_RConfigData(	PortB_is_RConfigData		),
		.is_RouteData(		PortB_is_RouteData			),
		.is_AuxData(		PortB_is_AuxData			),
		.O_Ready(			PortB_O_Ready				),
		.O_Bypass(			PortB_O_Bypass				),
		.O_SendHead(		PortB_O_SendHead			),
		.O_InputData(		PortB_O_InputData			),
		.O_SetDAttrib(		PortB_O_SetAttrib			),
		.O_Nack_My(			PortB_O_Nack				),
		.O_Length(			PortB_O_Length				),
		.O_Configure(		PortB_O_Configure			),
		.O_SelPort(			PortB_O_SelPort				),
		.O_Backup_Attrib(	PortB_O_Backup_Attrib		),
		.O_Set_Backup(		PortB_O_Set_Backup			),
		.O_is_Valid(		PortB_O_is_Valid 			)
	);

	//	 Port-C
	assign PortC_I_Length		= AttribDecC_O_Length;
	assign PortC_I_Valid		= I_FTkC.v;
	assign PortC_I_Valid_Other1	= I_FTkA.v;
	assign PortC_I_Valid_Other2	= I_FTkB.v;
	assign PortC_I_Acq			= AcqC;
	assign PortC_I_Rls			= RlsC;
	assign PortC_I_Nack			= I_BTk.n;
	assign PortC_I_Done			= Done;
	assign PortC_is_Ready1		= PortA_O_Ready;
	assign PortC_is_Ready2		= PortB_O_Ready;
	assign PortC_is_PConfigData	= AttribDecC_is_PConfigData;
	assign PortC_is_RConfigData	= AttribDecC_is_RConfigData;
	assign PortC_is_RouteData	= AttribDecC_is_RoutingData;
	assign PortC_is_AuxData		= AttribDecC_is_DataWord;
	PortSync #(
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) PortC
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Length(			PortC_I_Length				),
		.I_Valid(			PortC_I_Valid				),
		.I_Valid_Other1(	PortC_I_Valid_Other1		),
		.I_Valid_Other2(	PortC_I_Valid_Other2		),
		.I_Acq(				PortC_I_Acq					),
		.I_Rls(				PortC_I_Rls					),
		.I_Nack(			PortC_I_Nack				),
		.I_Done(			PortC_I_Done				),
		.is_Configured(		R_Configured				),
		.is_Ready1(			PortC_is_Ready1				),
		.is_Ready2(			PortC_is_Ready2				),
		.is_PConfigData(	PortC_is_PConfigData		),
		.is_RConfigData(	PortC_is_RConfigData		),
		.is_RouteData(		PortC_is_RouteData			),
		.is_AuxData(		PortC_is_AuxData			),
		.O_Ready(			PortC_O_Ready				),
		.O_Bypass(			PortC_O_Bypass				),
		.O_SendHead(		PortC_O_SendHead			),
		.O_InputData(		PortC_O_InputData			),
		.O_SetDAttrib(		PortC_O_SetAttrib			),
		.O_Nack_My(			PortC_O_Nack				),
		.O_Length(			PortC_O_Length				),
		.O_Configure(		PortC_O_Configure			),
		.O_SelPort(			PortC_O_SelPort				),
		.O_Backup_Attrib(	PortC_O_Backup_Attrib		),
		.O_Set_Backup(		PortC_O_Set_Backup			),
		.O_is_Valid(		PortC_O_is_Valid 			)
	);


	//// Datapath													////
	assign DataPath_FTkA	= ( PortA_O_Set_Backup ) ?	Backup_Attrib_A : OperandA;
	assign DataPath_FTkB	= ( PortB_O_Set_Backup ) ?	Backup_Attrib_B : OperandB;
	assign DataPath_FTkC	= ( PortC_O_Set_Backup ) ?	Backup_Attrib_C : OperandC;
	IntDataPath IntDataPath
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Active(			Active						),
		.I_Command(			Command						),
		.I_Cond(			Condition					),
		.I_EnSrcA(			EnSrcA						),
		.I_EnSrcB(			EnSrcB						),
		.I_EnSrcC(			EnSrcC						),
		.I_OperandA(		DataPath_FTkA				),
		.I_OperandB(		DataPath_FTkB				),
		.I_OperandC(		DataPath_FTkC				),
		.O_Result(			DataPath_FTk				),
		.I_BTk(				I_BTk						),
		.O_BTkA(			DataPath_BTkA   	        ),
		.O_BTkB(			DataPath_BTkB       	    ),
		.O_BTkC(			DataPath_BTkC           	)
	);


	//// Output														////
	assign Rls				= Active & DataPath_FTk.r & ~(
									PortA_O_SendHead |
									PortB_O_SendHead |
									PortC_O_SendHead |
									PortA_O_Bypass |
									PortB_O_Bypass |
									PortC_O_Bypass
								);

	//	 Attribute Word Composition
	assign Port_Length		= ( PortA_O_SetAttrib ) ?	PortA_O_Length :
								( PortB_O_SetAttrib ) ?	PortB_O_Length :
								( PortC_O_SetAttrib ) ?	PortC_O_Length :
														'0;

	assign Attrib_Shared	= ( PortA_O_SetAttrib ) ?	R_Attrib_Shared_A :
								( PortB_O_SetAttrib ) ?	R_Attrib_Shared_B :
								( PortC_O_SetAttrib ) ?	R_Attrib_Shared_C :
														'0;

	assign Attrib_NonZero	= ( PortA_O_SetAttrib ) ?	R_Attrib_NonZero_A :
								( PortB_O_SetAttrib ) ?	R_Attrib_NonZero_B :
								( PortC_O_SetAttrib ) ?	R_Attrib_NonZero_C :
														'0;

	assign Attrib_FTk.v	= 1'b1;
	assign Attrib_FTk.a	= 1'b0;
	assign Attrib_FTk.c	= 1'b0;
	assign Attrib_FTk.r	= 1'b0;
	assign Attrib_FTk.d	= { 4'h0, Attrib_Shared, Attrib_NonZero, 8'h00, Port_Length, 8'h00 };
	`ifdef EXTEND
	assign Attrib_FTk.i	= '0;
	`endif

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_Shared_A	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_Shared_A	<= 1'b0;
		end
		else if ( AttribDecA_is_Shared ) begin
			R_Attrib_Shared_A	<= 1'b1;
		end
		else begin
			R_Attrib_Shared_A	<= R_Attrib_Shared_A;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_Shared_B	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_Shared_B	<= 1'b0;
		end
		else if ( AttribDecB_is_Shared ) begin
			R_Attrib_Shared_B	<= 1'b1;
		end
		else begin
			R_Attrib_Shared_B	<= R_Attrib_Shared_B;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_Shared_C	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_Shared_C	<= 1'b0;
		end
		else if ( AttribDecC_is_Shared ) begin
			R_Attrib_Shared_C	<= 1'b1;
		end
		else begin
			R_Attrib_Shared_C	<= R_Attrib_Shared_C;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_NonZero_A	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_NonZero_A	<= 1'b0;
		end
		else if ( AttribDecA_is_NonZero ) begin
			R_Attrib_NonZero_A	<= 1'b1;
		end
		else begin
			R_Attrib_NonZero_A	<= R_Attrib_NonZero_A;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_NonZero_B	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_NonZero_B	<= 1'b0;
		end
		else if ( AttribDecB_is_NonZero ) begin
			R_Attrib_NonZero_B	<= 1'b1;
		end
		else begin
			R_Attrib_NonZero_B	<= R_Attrib_NonZero_B;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Attrib_NonZero_C	<= 1'b0;
		end
		else if ( Rls ) begin
			R_Attrib_NonZero_C	<= 1'b0;
		end
		else if ( AttribDecC_is_NonZero ) begin
			R_Attrib_NonZero_C	<= 1'b1;
		end
		else begin
			R_Attrib_NonZero_C	<= R_Attrib_NonZero_C;
		end
	end

	//	 Send Header
	assign SendHead_A		= PortA_O_SendHead;
	assign SendHead_B		= PortB_O_SendHead;
	assign SendHead_C		= PortC_O_SendHead;

	//	 Send Attribute Word before Data Block
	assign SetAttrib		= PortA_O_SetAttrib | PortB_O_SetAttrib | PortC_O_SetAttrib;

	//	 Bypass Follow Blocks
	assign Bypass_A			= PortA_O_Bypass;
	assign Bypass_B			= PortB_O_Bypass;
	assign Bypass_C			= PortC_O_Bypass;

	//	 Configure then not Send
	assign Configure		= PortA_O_Configure | PortB_O_Configure | PortC_O_Configure;

	//	 Output Forward Tokens
	assign O_FTk			= 	( Configure ) ?		'0 :
								( SendHead_A ) ?	InRegA_FTk :
								( SendHead_B ) ?	InRegB_FTk :
								( SendHead_C ) ?	InRegC_FTk :
								( SetAttrib ) ?		Attrib_FTk :
								( Bypass_A ) ?		InRegA_FTk :
								( Bypass_B ) ?		InRegB_FTk :
								( Bypass_C ) ?		InRegC_FTk :
													DataPath_FTk;

	//	 Output Backward Tokens
	assign O_BTkA			= ( PortA_O_SendHead ) ?	InRegA_O_BTk :
								( PortA_O_SetAttrib ) ?	InRegA_O_BTk :
								( PortA_O_Bypass ) ?	InRegA_O_BTk :
								( Configure ) ?			'0 :
														InRegA_O_BTk;

	assign O_BTkB			= ( PortB_O_SendHead ) ?	InRegB_O_BTk :
								( PortB_O_SetAttrib ) ?	InRegB_O_BTk :
								( PortB_O_Bypass ) ?	InRegB_O_BTk :
								( Configure ) ?			'0 :
														InRegB_O_BTk;

	assign O_BTkC			= ( PortC_O_SendHead ) ?	InRegC_O_BTk :
								( PortC_O_SetAttrib ) ?	InRegC_O_BTk :
								( PortC_O_Bypass ) ?	InRegC_O_BTk :
								( Configure ) ?			'0 :
														InRegC_O_BTk;

	//	 Output Condition
	assign O_InCA[1]		= DataPath_BTkA.v;
	assign O_InCA[0]		= DataPath_BTkA.c;

	assign O_InCB[1]		= DataPath_BTkB.v;
	assign O_InCB[0]		= DataPath_BTkB.c;

	assign O_InCC[1]		= DataPath_BTkC.v;
	assign O_InCC[0]		= DataPath_BTkC.c;

endmodule
