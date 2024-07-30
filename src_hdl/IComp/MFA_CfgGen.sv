///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Configuration Data Generator for Most Frequently Appeared (MFA) Unit
//	Module Name:	MFA_CfgGen
//	Function:
//					used for Index Compression
//					Generate Configuration Data
//					This unit is used for extension; Index-Compression.
//					The extension find most frequently appeared value.
//					The value is removed from the data block,
//						and treated as a shared data.
//					Generated data is used for restoring (the compression).
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MFA_CfgGen
	import	pkg_en::*;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input							I_Snoop_AttribRCfg,	//Flag: Snoop Attribute for RConfig
	input							I_End_MFACfgGen,	//Flag: End of Congfig Generation
	input							I_Str_Snoop,		//Flag: Start Snooping Config. Data
	output							O_End_Snoop,		//Flag: End of Snooping Config. Data
	input							I_Snoop_AttribData,	//Flag: Snoop Attribute for Data Block
	input	FTk_t					I_FTk,				//Snooping Data
	output	FTk_t					O_FTk,				//Output Snooped Config. Data
	input							I_Str_Rd,			//Flag: Start Read Config. Data
	output							O_End_Rd,			//Flag: End Read Config. Data
	input							I_End_Store,		//Flag: End of Storing
	input							I_End_Load,			//Flag: End of Storing
	output	logic					is_SharedConfig,	//Flag: Share Flag in Config Word in R-Config
	output	logic					is_SharedAttrib,	//Flag: Share Flag in Attrib Word for Data Block
	output	logic					is_NonZero,			//Flag: NonZero in Attribute Word
	output	logic					is_Dense,			//Flag: Dense in Attribute Word
	input							I_Set_SData,		//Flag: Capture Shared Data Word
	output	[WIDTH_DATA-1:0]		O_SharedData,		//Shared Data,
	output	[WIDTH_LENGTH+1:0]		O_LengthData,		//Length in Attrib Block,
	output	[WIDTH_LENGTH-1:0]		O_LengthConfig		//Length in RConfig,
);


	//// Control FSM												////
	fsm_cfg_gen					FSM_CfgGen;
	logic [2:0]					FSM_CfgCnt;


	//// Token														////
	logic						Valid;
	logic						Snoop_RConfig;


	//// Attribute Word for Data Block								////
	logic						Rd_AttribData;
	logic						Rd_AttribRConfig;
	logic						Rd_RCfgData;


	//// Setting Configuration Data									////
	logic						Set_Length;
	logic						Set_Stride;
	logic						Set_Base;


	//// Read Configuration Data									////
	logic						Rd_Length;
	logic						Rd_Stride;
	logic						Rd_Base;


	logic						End_Cnt;


	//// Attribute Word Data										////
	logic [WIDTH_DATA-1:0]		R_AttribWord_Data;


	//// Shared Data												////
	logic [WIDTH_DATA-1:0]		R_SharedData;


	//// Attribute Word	for R-Config								////
	logic [WIDTH_DATA-1:0]		R_AttribWord_RCfg;


	//// Attribute Word for R-Config Data							////
	FTk_t						R_Snoop_RConfig;


	//// Snoop Attribute Word for R-Config Data						////
	logic						R_Snoop_AttribRCfg;


	//// Configuration Data											////
	logic [WIDTH_DATA-1:0]		R_Length;
	logic [WIDTH_DATA-1:0]		R_Stride;
	logic [WIDTH_DATA-1:0]		R_Base;


	//// Capture Signal												////
	FTk_t						R_FTk;
	logic						R_Str_Snoop;
	logic						R_Set_SData;

	// End of Counting
	logic						R_End_Cnt;


	//// End of Snooping											////
	assign O_End_Snoop		= ( FSM_CfgGen == MFA_CFG_GET_B );


	//// Shared Data												////
	assign O_SharedData		= R_SharedData;


	//// Attribution Block Length									////
	assign O_LengthData		= R_AttribWord_Data[WIDTH_LENGTH+POSIT_ATTRIB_LENGTH_LSB-1:POSIT_ATTRIB_LENGTH_LSB];


	//// Length defined in R-Config Data							////
	assign O_LengthConfig	= R_Length;


	//// End of Reading												////
	assign O_End_Rd			= R_End_Cnt;


	//// Read-out Configuration Data								////
	assign Valid			= ( FSM_CfgCnt != 3'h0 );
	assign Rd_AttribRConfig	= ( FSM_CfgCnt == 3'h1 );
	assign Rd_RCfgData		= ( FSM_CfgCnt == 3'h2 );
	assign Rd_Length		= ( FSM_CfgCnt == 3'h3 );
	assign Rd_Stride		= ( FSM_CfgCnt == 3'h4 );
	assign Rd_Base			= ( FSM_CfgCnt == 3'h5 );
	assign Rd_AttribData	= ( FSM_CfgCnt == 3'h6 );


	//// Output RConfig Data Block for Restoring					////
	assign O_FTk.v			= Valid;
	assign O_FTk.a			= 1'b0;
	assign O_FTk.r			= 1'b0;
	assign O_FTk.c			= 1'b0;
	`ifdef EXTEND
	assign O_FTk.i			= '0;
	`endif
	assign O_FTk.d			= ( Rd_AttribRConfig )?	{ 1'b0, R_AttribWord_RCfg[WIDTH_DATA-2:0] } :
								( Rd_RCfgData ) ?	R_Snoop_RConfig.d :
								( Rd_Length ) ? 	R_Length :
								( Rd_Stride ) ? 	R_Stride :
								( Rd_Base ) ? 		R_Base :
								( Rd_AttribData ) ?	R_AttribWord_Data :
													'0;


	//// Retime Storing Forward Tokens								////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FTk				<= '0;
		end
		else begin
			R_FTk				<= I_FTk;
		end
	end


	//// Start to Snoop Configuration Data							////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Str_Snoop			<= 1'b0;
		end
		else begin
			R_Str_Snoop			<= I_Str_Snoop;
		end
	end


	//// Retime Snoop R-Config										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Snoop_AttribRCfg	<= 1'b0;
		end
		else begin
			R_Snoop_AttribRCfg	<= I_Snoop_AttribRCfg;
		end
	end


	//// Attribute Word	for R-Config								////
	//	 is_Shared flag is removed
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_AttribWord_RCfg	<= '0;
		end
		else if ( R_Snoop_AttribRCfg ) begin
			R_AttribWord_RCfg	<= { R_FTk.d[WIDTH_DATA-1:WIDTH_DATA-4], 1'b0, R_FTk.d[WIDTH_DATA-6:0] } ;
		end
		else begin
			R_AttribWord_RCfg	<= R_AttribWord_RCfg;
		end
	end


	//// Share Flag in R-Config Data								////
	assign Snoop_RConfig	= FSM_CfgGen == MFA_CFG_GET_R;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Snoop_RConfig		<= '0;
		end
		else if ( Snoop_RConfig ) begin
			R_Snoop_RConfig		<= R_FTk;
		end
	end


	//// Capture Configuration Data									////
	assign Set_Length		= ( FSM_CfgGen == MFA_CFG_GET_L ) & R_FTk.v;
	assign Set_Stride		= ( FSM_CfgGen == MFA_CFG_GET_S ) & R_FTk.v;
	assign Set_Base			= ( FSM_CfgGen == MFA_CFG_GET_B ) & R_FTk.v;


	//// Capture Configuration Data									////
	//	 Access Length
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Length		<= '0;
		end
		else if ( Set_Length ) begin
			R_Length		<= R_FTk.d;
		end
	end

	//	 Stride Factor
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Stride		<= '0;
		end
		else if ( Set_Stride ) begin
			R_Stride		<= R_FTk.d;
		end
	end

	//	 Base Address
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Base			<= '0;
		end
		else if ( Set_Base ) begin
			R_Base			<= R_FTk.d;
		end
	end


	//// Share Flag in Attribute Word of Data						////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_AttribWord_Data	<= '0;
		end
		else if ( I_Snoop_AttribData ) begin
			R_AttribWord_Data	<= R_FTk.d;
		end
	end


	//// Capture Shared Data										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Set_SData		<= 1'b0;
		end
		else begin
			R_Set_SData		<= I_Set_SData;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_SharedData	<= '0;
		end
		else if ( R_Set_SData ) begin
			R_SharedData	<= R_FTk.d;
		end
	end


	//// Read-out Counter											////
	//	 0: N/A
	//	 1: R-Config Data
	//	 2: Length
	//	 3: Stride
	//	 4: Base
	//	 5: Attrib for Data Block
	//	 6: Shared Data if is_SharedAttrib is High
	always_ff @( posedge clock ) begin: ff_fsm_read_config
		if ( reset ) begin
			FSM_CfgCnt		<= 3'h0;
		end
		else if ( I_Str_Rd ) begin
			FSM_CfgCnt		<= 3'h1;
		end
		else if ( FSM_CfgCnt > 3'h6 ) begin
			FSM_CfgCnt		<= 3'h0;
		end
		else if ( FSM_CfgCnt > 3'h0 ) begin
			FSM_CfgCnt		<= FSM_CfgCnt + 3'h1;
		end
		else begin
			FSM_CfgCnt		<= 3'h0;
		end
	end


	//// Retime End of Counting										////
	assign End_Cnt			= ( ~is_SharedAttrib & ( FSM_CfgCnt == 3'h6 )) | ( is_SharedAttrib & ( FSM_CfgCnt == 3'h7 ));
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_Cnt		<= 1'b0;
		end
		else begin
			R_End_Cnt		<= End_Cnt;
		end
	end


	//// Snooping Control											////
	always_ff @( posedge clock ) begin: ff_fsm_snoop_config
		if ( reset ) begin
			FSM_CfgGen		<= MFA_CFG_INIT;
		end
		else case ( FSM_CfgGen )
			MFA_CFG_INIT: begin
				if ( R_Str_Snoop ) begin
					FSM_CfgGen	<= MFA_CFG_GET_R;
				end
				else begin
					FSM_CfgGen	<= MFA_CFG_INIT;
				end
			end
			MFA_CFG_GET_R: begin	// Get R-Config Data
				if ( R_FTk.v ) begin
					FSM_CfgGen	<= MFA_CFG_GET_L;
				end
			end
			MFA_CFG_GET_L: begin	// Get Store Length
				if ( R_FTk.v ) begin
					FSM_CfgGen	<= MFA_CFG_GET_S;
				end
			end
			MFA_CFG_GET_S: begin	// Get Store Stride
				if ( R_FTk.v ) begin
					FSM_CfgGen	<= MFA_CFG_GET_B;
				end
			end
			MFA_CFG_GET_B: begin	// Get Store Base Addr
				if ( R_FTk.v ) begin
					FSM_CfgGen	<= MFA_CFG_WAIT;
				end
			end
			MFA_CFG_WAIT: begin		// Wait for End of Store IN MFA Seq
				if ( ~is_SharedAttrib ) begin
					FSM_CfgGen	<= MFA_CFG_INIT;
				end
				else if ( I_Str_Rd ) begin
					FSM_CfgGen	<= MFA_CFG_READ_S;
				end
			end
			MFA_CFG_READ_S: begin	// Read-Out Config-Data for Storing
				if ( ~is_SharedAttrib ) begin
					FSM_CfgGen	<= MFA_CFG_INIT;
				end
				else if ( I_End_Store ) begin
					FSM_CfgGen	<= MFA_CFG_READ_L;
				end
			end
			MFA_CFG_READ_L: begin	// Read-Out Config-Data for Loading
				if ( I_End_Load ) begin
					FSM_CfgGen	<= MFA_CFG_INIT;
				end
			end
			default: begin
				FSM_CfgGen	<= MFA_CFG_INIT;
			end
		endcase
	end


	//// Configuration Word Decoding								////
	ConfigDec_RAM #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				)
	) MFA_ConfigDec
	(
		.I_FTk(				R_Snoop_RConfig				),
		.O_Share(			is_SharedConfig				),
		.O_Decrement(									),
		.O_Mode(										),
		.O_Indirect(									),
		.O_Length(										),
		.O_Stride(										),
		.O_Base(										)
	);


	//// Attribution Word Decoding									////
	AttributeDec MFA_AttribDec
	(
		.I_Data(			R_AttribWord_Data			),
		.is_Pull(										),
		.is_DataWord(									),
		.is_RConfigData(								),
		.is_PConfigData(								),
		.is_RoutingData(								),
		.is_Shared(			is_SharedAttrib				),
		.is_NonZero(		is_NonZero					),
		.is_Dense(			is_Dense					),
		.is_MyAttribute(								),
		.is_Term_Block(									),
		.is_In_Cond(									),
		.O_Length(										)
	);

endmodule