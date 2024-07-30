///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	ElectronNest (Top Module)
//	ModuleName:		ElectronNest
//	Function:
//					Top Module for Ritch External Memory I/F
//					The unit having;
//					- Multiple Buffers having enough capacity
//					- ComputeTile Element is connected to IFLogic
//					- Frontend connects between Buffers, Buffer and IFLogic,
//						Buffer and Ext. Mem IF, and IFLogtic and Ext Mem IF
//					- Frontend connects in-rder defined by its program
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module ElectronNest
	import	pkg_en::*;
	import	pkg_mem::*;
	import	pkg_extend_index::*;
	import	pkg_bram_if::*;
(
	input										clock,
	input										reset,
	input					[NUM_EXT_IFS-1:0]	I_Boot,

	output					[NUM_EXT_IFS-1:0]	O_Ld_Req,			//Load Request
	output	ext_word_addr_t	[NUM_EXT_IFS-1:0]	O_Ld_Addr,			//Load Address
	input					[NUM_EXT_IFS-1:0]	I_Ld_Ack,			//Load-Ack
	input	ext_data_t		[NUM_EXT_IFS-1:0]	I_Ld_FTk,			//Load Data
	output	BTk_extif_t							O_Ld_BTk,			//Load Back-Token
	output					[NUM_EXT_IFS-1:0]	O_St_Req,			//Store Request
	output	ext_word_addr_t	[NUM_EXT_IFS-1:0]	O_St_Addr,			//Store Address
	input					[NUM_EXT_IFS-1:0]	I_St_Ack,			//Store-Ack
	output	ext_data_t		[NUM_EXT_IFS-1:0]	O_St_FTk,			//Store Data
	input	BTk_extif_t							I_St_BTk			//Store Back-Token
);


	//// Store														////
	logic			[NUM_EXT_IFS-1:0]	St_Req;
	ext_word_addr_t	[NUM_EXT_IFS-1:0]	St_Addr;
	ext_data_t		[NUM_EXT_IFS-1:0]	St_Data;
	BTk_extif_t							St_BTk;


	//// Load														////
	ext_word_addr_t	[NUM_EXT_IFS-1:0]	Ld_Addr;
	ext_data_t		[NUM_EXT_IFS-1:0]	Ld_Data;
	BTk_extif_t							Ld_BTk;


	//// IFUnit <-> External World									////
	io_bram_t				IFU_I_Port;
	io_bram_t				IFU_O_Port;

	logic					valid;
	logic					acq;
	logic					rls;
	logic					cond;
	logic	[4+WIDTH_DATA-1:0]data;


	IFUnit IFUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Boot(			I_Boot[0]					),
		.I_Port(			IFU_I_Port					),
		.O_Port(			IFU_O_Port					),
		.O_Ld_Req(			O_Ld_Req[0]					),
		.O_Ld_Addr(			O_Ld_Addr[0]				),
		.I_Ld_Ack(			I_Ld_Ack[0]					),
		.I_Ld_FTk(			I_Ld_FTk[0]					),
		.O_Ld_BTk(			O_Ld_BTk[0]					),
		.O_St_Req(			O_St_Req[0]					),
		.O_St_Addr(			O_St_Addr[0]				),
		.I_St_Ack(			I_St_Ack[0]					),
		.O_St_FTk(			O_St_FTk[0]					),
		.I_St_BTk(			I_St_BTk[0]					)
	);


	//// Page <-> ME_IF Connection									////
	FTk_cclm_if_t				CT_I_Port_FTk;
	BTk_cclm_if_t				CT_O_Port_BTk;
	FTk_cclm_if_t				CT_O_Port_FTk;
	BTk_cclm_if_t				CT_I_Port_BTk;

	always_comb begin
		for ( int i=0; i<NUM_CLM; ++i ) begin
			CT_I_Port_FTk[0][ i ]		= IFU_O_Port[ i ].IO_Data;
			CT_I_Port_BTk[0][ i ]		= IFU_O_Port[ i ].IO_CTRL;

			IFU_I_Port[ i ].IO_Data		= CT_O_Port_FTk[0][ i ];
			IFU_I_Port[ i ].IO_CTRL		= CT_O_Port_BTk[0][ i ];
		end
	end


	//// Compute Tile												////
	ComputeTile #(
		.EnIF_North(		EnIF_North					),
		.EnIF_East(			EnIF_East					),
		.EnIF_West(			EnIF_West					),
		.EnIF_South(		EnIF_South					),
		.WIDTH_DATA(		WIDTH_DATA					),
		.NUM_LINK(			NUM_LINK					),
		.NUM_CHANNEL(		NUM_CHANNEL					),
		.WIDTH_LENGTH(		WIDTH_LENGTH				),
		.WIDTH_ADDR(		WIDTH_ADDR					),
		.WIDTH_UNIT(		WIDTH_UNIT					),
		.NUM_MEMUNIT(		NUM_MEMUNIT					),
		.SIZE_CRAM(			SIZE_CRAM					),
		.DEPTH_FIFO(		DEPTH_FIFO					),
		.WIDTH_OPCODE(		WIDTH_OPCODE				),
		.WIDTH_CONSTANT(	WIDTH_CONSTANT				),
		.NUM_WORKER(		NUM_WORKER					),
		.NUM_ROW(			NUM_ROW						),
		.NUM_CLM(			NUM_CLM						),
		.NUM_ALU(			NUM_ALU						),
		.NUM_CRAM(			NUM_CRAM					),
		.ExtdConfig(		ExtdConfig					)
	) CT
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_FTk(				CT_I_Port_FTk				),
		.O_BTk(				CT_O_Port_BTk				),
		.O_FTk(				CT_O_Port_FTk				),
		.I_BTk(				CT_I_Port_BTk				)
	);

endmodule
