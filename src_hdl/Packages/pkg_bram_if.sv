///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Package for External Memory Wrapper
//	Package Name:	pkg_bram_if
//	Function:
//                  used for Wrapper of External Memory Access
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_bram_if;
import pkg_en::*;

	parameter int WIDTH_BYTE		= 8;								//Byte: 8-bit


	//// External Memory											////
	parameter int WIDTH_EXT_ADDR	= 32;								//Address Space
	parameter int WIDTH_EXT_LENGTH	= 10;								//Address Space
	parameter int WIDTH_EXT_DATA	= 32;								//Data-IO
	parameter int UNIT_EXT_DATA		= WIDTH_EXT_DATA/WIDTH_DATA;		//SerDes Unit


	//// Instruction												////
	parameter int WIDTH_INSTR		= WIDTH_DATA;


	//// ID-Field													////
	parameter int NUM_BLOCKS		= 1024;
	parameter int WIDTH_BLOCKS		= $clog2(NUM_BLOCKS);
	parameter int WIDTH_AID			= 2+WIDTH_BLOCKS;


	//// Instruction Bit-Fields										////
	//	 Position on Instruction
	//	 First Instruction Word
	parameter int POS_OPCODE_MSB	= WIDTH_DATA-1;
	parameter int POS_OPCODE_LSB	= WIDTH_DATA-4;
	parameter int POS_FUNC_MSB		= WIDTH_DATA-4-1;
	parameter int POS_FUNC_LSB		= WIDTH_DATA-4-4;
	parameter int POS_ADSTID_MSB	= WIDTH_AID*2-1;
	parameter int POS_ADSTID_LSB	= WIDTH_AID;
	parameter int POS_ASRCID_MSB	= WIDTH_AID-1;
	parameter int POS_ASRCID_LSB	= 0;

	//	 Width for Each Bit-Fields in First Instruction Word
	parameter int WIDTH_OPCODE		= POS_OPCODE_MSB-POS_OPCODE_LSB+1;
	parameter int WIDTH_FUNC		= POS_FUNC_MSB-POS_FUNC_LSB+1;


	//// Frontend													////
	parameter int NUM_CTRLS			= 1;
	parameter int WIDTH_NUM_CTRLS	= 1;


	//// Buffer														////
	parameter int NUM_BRAMS			= 4;
	parameter int LOG_NUM_BRAMS		= $clog2(NUM_BRAMS);


	//// Core-Array
	parameter int NUM_ELMS			= NUM_CLM;
	parameter int LOG_NUM_ELMS		= $clog2(NUM_ELMS);


	//// External Memory Interfaces									////
	parameter int NUM_EXT_IFS		= 1;
	parameter int WIDTH_EXT_IFS		= 1;


	//// UNITS														////
	//	 External I/F reserves two units (Load and Store units)
	parameter int NUM_UNITS			= NUM_BRAMS + NUM_ELMS + NUM_CTRLS + (NUM_EXT_IFS*2);
	parameter int WIDTH_UNITS		= $clog2(NUM_UNITS);


	//// Physical ID												////
	parameter int WIDTH_PID			= WIDTH_UNITS;


	//// Architecture ID											////
	//	 ID-Type
	typedef enum logic [1:0] {
		CTRL					= 2'h0,
		BRAM					= 2'h1,
		IFLGC					= 2'h2,
		IFEXT					= 2'h3
	} a_id_type_t;

	//	 Architecture ID Bit-Field
	typedef struct packed {
		a_id_type_t					t;
		logic [WIDTH_BLOCKS-1:0]	id;
	} a_id_t;


	//// ID Offset													////
	//	 used for selecting interconnect
	parameter int ID_OFFSET_CTRL	= 0;
	parameter int ID_OFFSET_BRAM	= NUM_CTRLS;
	parameter int ID_OFFSET_IFLOGIC	= NUM_CTRLS + NUM_BRAMS;
	parameter int ID_OFFSET_IFEXTRN	= NUM_CTRLS + NUM_BRAMS + NUM_ELMS;


	//// BRAM														////
	parameter int LENGTH_BRAM		= 8192;	//8K-Words
	parameter int WIDTH_BRAM_ADDR	= $clog2(LENGTH_BRAM);
	parameter int WIDTH_BRAM_LENGTH	= WIDTH_BRAM_ADDR;
	parameter int WIDTH_BRAM_STRIDE	= WIDTH_BRAM_ADDR;
	parameter int WIDTH_BRAM_BASE	= WIDTH_BRAM_ADDR;
	parameter int MAX_NUM_ARCH_BRAM	= 2**WIDTH_AID;


	//// Buffers													////
	parameter int LENGTH_BUFF_LD		= 16;
	parameter int WIDTH_LENGTH_BUFF_LD	= $clog2(LENGTH_BUFF_LD);
	parameter int LENGTH_BUFF_ST		= 16;
	parameter int WIDTH_LENGTH_BUFF_ST	= $clog2(LENGTH_BUFF_ST);


	//// Typedefs													////
	//	 Rename Table
	typedef logic	[WIDTH_AID-1:0]		adst_id_t;
	typedef logic	[WIDTH_AID-1:0]		asrc_id_t;
	typedef logic	[WIDTH_PID-1:0]		pdst_id_t;
	typedef logic	[WIDTH_PID-1:0]		psrc_id_t;
	typedef logic	[WIDTH_UNITS-1:0]	header_t;

	typedef struct packed {
		pdst_id_t				PDstID;
		psrc_id_t				PSrcID;
		adst_id_t				ADstID;
		asrc_id_t				ASrcID;
		header_t				Header;
		logic					Dirty;
	} rename_tab_t;

	typedef rename_tab_t	[NUM_UNITS-1:0]	RenameTab_t;

	typedef struct packed {
		logic			  		Valid;
		logic					Commit;
		logic	[WIDTH_PID-1:0]	PSrcID;
	} commit_t;

	//	 Port Map Table
	typedef logic					PortValid_t;
	typedef logic	[WIDTH_PID-1:0]	PortPDstID_t;
	typedef logic	[WIDTH_PID-1:0]	PortPSrcID_t;

	typedef struct packed {
		PortValid_t				Valid;
		PortPDstID_t			PDstID;
		PortPSrcID_t			PSrcID;
	} port_row_t;

	typedef port_row_t		[NUM_UNITS-1:0]	portmap_t;

	//	 ID for Port
	typedef PortPDstID_t	[NUM_UNITS-1:0]	port_pdst_id_t;
	typedef PortPSrcID_t	[NUM_UNITS-1:0]	port_psrc_id_t;

	//	 Interconnection Network
	typedef struct packed {
		FTk_t					IO_Data;
		BTk_t					IO_CTRL;
	} io_data_t;

	//	 BRAM <-> ComputeTile I/F
	typedef io_data_t	[NUM_ELMS-1:0]		io_bram_t;

	typedef FTk_t		[NUM_ELMS-1:0]		io_FTk_t;
	typedef BTk_t		[NUM_ELMS-1:0]		io_BTk_t;

	//	 Control Flags
	typedef logic							bit_t;
	typedef bit_t	[NUM_UNITS-1:0]			nbit_t;

	//	 Chip-Select
	typedef logic	[UNIT_EXT_DATA-1:0]		CSel_t;

	//	 Bit-Width for Word-Count on External Memory I/F
	typedef logic	[$clog2(UNIT_EXT_DATA)-1:0]	ext_ld_addr_t;

	//	 Bit-Width for Address on External Memory
	typedef logic	[WIDTH_EXT_ADDR-1:0]	ext_addr_t;

	//	 Bit-WIdth for Address on External Memory (Word-Count)
	typedef logic	[WIDTH_EXT_ADDR-$clog2(UNIT_EXT_DATA)-1:0]	ext_word_addr_t;

	//	 Bit-Width for Bare-Data
	typedef logic	[WIDTH_DATA-1:0]		ext_udata_t;

	//	 typedef ext_udata_t	[UNIT_EXT_DATA-1:0]	ext_data_t;
	typedef FTk_t	[UNIT_EXT_DATA-1:0]		ext_data_t;

	//	 Bit-Width for External Memory I/O
	typedef logic	[WIDTH_EXT_DATA-1:0]	ext_io_t;

	//	 Port for I/F-Logic
	typedef FTk_t	[NUM_ELMS-1:0]			FTk_iflgc_t;
	typedef BTk_t	[NUM_ELMS-1:0]			BTk_iflgc_t;

	//	 Port for External Memory Unit(s)
	typedef FTk_t	[NUM_EXT_IFS-1:0]		FTk_extif_t;
	typedef BTk_t	[NUM_EXT_IFS-1:0]		BTk_extif_t;

	//	 IF Logic Control (FSM)
	typedef enum logic [3:0] {
		IFLOGIC_ST_INIT			= 4'h0,
		IFLOGIC_ST_ID_T			= 4'h1,
		IFLOGIC_ST_ID_F			= 4'h2,
		IFLOGIC_ST_ATTRIB		= 4'h3,
		IFLOGIC_ST_ROUTE		= 4'h4,
		IFLOGIC_ST_CHECK_ATTRIB	= 4'h5,
		IFLOGIC_ST_CHECK_RCFG	= 4'h6,
		IFLOGIC_ST_SEND_RCFG	= 4'h7,
		IFLOGIC_ST_RETIME_RCFG	= 4'h8,
		IFLOGIC_ST_FRONT_RUN	= 4'h9
	} fsm_iflogic_st_frontend;

	typedef enum logic {
		IFLOGIC_ST_BACK_INIT	= 1'h0,
		IFLOGIC_ST_BACK_RUN		= 1'h1
	} fsm_iflogic_st_backend;

	//	 IF Controller
	typedef enum logic [2:0] {
		IFCTRL_INIT				= 3'h0,
		IFCTRL_ID_T				= 3'h1,
		IFCTRL_ID_F				= 3'h2,
		IFCTRL_ATTRIB			= 3'h3,
		IFCTRL_ROUTE			= 3'h4,
		IFCTRL_RATRIB			= 3'h5,
		IFCTRL_RCFG				= 3'h6,
		IFCTRL_RUN				= 3'h7
	} fsm_ifctrl;

	//
	typedef enum logic [3:0] {
		BRAM_Init				= 4'h0,
		BRAM_ID_T				= 4'h1,
		BRAM_ID_F				= 4'h2,
		BRAM_ATTR				= 4'h3,
		BRAM_BCFG				= 4'h4,
		BRAM_ST_ATTR			= 4'h5,
		BRAM_ST					= 4'h6,
		BRAM_LD_MYID			= 4'h7,
		BRAM_LD_ID_T			= 4'h8,
		BRAM_LD_ID_F			= 4'h9,
		BRAM_RCFG_ATTR			= 4'ha,
		BRAM_RCFG_DATA			= 4'hb,
		BRAM_LENGTH				= 4'hc,
		BRAM_STRIDE				= 4'hd,
		BRAM_BASE				= 4'he,
		BRAM_LD					= 4'hf
	} fsm_bram;

endpackage