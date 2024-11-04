///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Base Package
//	Package Name:	pkg_en
//
///////////////////////////////////////////////////////////////////////////////////////////////////

package pkg_en;
import	pkg_extend_index::*;

	//// Number of Interfaces (Load/Store Unit)						////
	//	Interface Configuration
	//	0: No ME_IF
	//	1: South ME_IF
	//	2: South and North ME_IFs
	//	3: South, East, West ME_IFs
	//	4: on All edges
	parameter int NUM_IF                        = 1;
	parameter int EnIF_North					= 0;
	parameter int EnIF_East                     = 0;
	parameter int EnIF_West                     = 0;
	parameter int EnIF_South                    = 1;


	//// Address Space for External Memory							////
	parameter int WIDTH_EXADDR					= 20;


	//// Base Data Width used in Operations							////
	parameter int WIDTH_DATA					= 32;


	//// Address Space for On-Chip Memory							////
	parameter int WIDTH_LENGTH					= 10;


	//// Page Parameters											////
	//	Number of Rows in page
	parameter int NUM_ROW						= 2;

	//	Number of Columns in page
	parameter int NUM_CLM						= 4;

	//	Size Array-Edge
	//		ToDo: make row and column edge each
	parameter int NUM_COMP						= NUM_CLM;


	//// Link Element												////
	//	Number of Links
	parameter int NUM_LINK						= 4;

	// Number of Channels per Link
	parameter int NUM_CHANNEL					= 1;

	// Depth of FIFO used in LinkOut
	parameter int DEPTH_FIFO					= 16;

	// Depth of FIFO used in LinkOut
	parameter int DEPTH_L_FIFO					= 8;


	//// Compute Element											////
	//	 Number of ALUs in PE
	parameter int NUM_ALU						= 1;

	//	Number of DataPath in ALU
	//	  At least this must be greater than 2
	parameter int NUM_WORKER					= 4;

	//
	parameter int WIDTH_CONSTANT				= 4;


	//// Retiming Element											////
	//	 Number of RAM Units in RE
	parameter int NUM_CRAM						= 1;

	//	 Accessing Unit Width
	//		currently set to 1-Byte
	parameter int WIDTH_UNIT					= 8;

	//	 Number of Subsets in RAM
	parameter int NUM_MEMUNIT					= WIDTH_DATA/WIDTH_UNIT;


	//// Bit-Range for Decoding Attribution Word					////
	parameter int POSIT_ATTRIB_PULL				= 31;
	parameter int POSIT_ATTRIB_PUSH				= 30;
	parameter int POSIT_ATTRIB_MODE_MSB			= 29;
	parameter int POSIT_ATTRIB_MODE_LSB			= 28;
	parameter int POSIT_ATTRIB_SHARED			= 27;
	parameter int POSIT_ATTRIB_NONZERO			= 26;
	parameter int POSIT_ATTRIB_DENSE			= 25;
	parameter int POSIT_ATTRIB_MY_ATTRIB_BLOCK	= 24;
	parameter int POSIT_ATTRIB_TERM_BLOCK		= 23;
	parameter int POSIT_ATTRIB_INPUT_COND		= 22;
	parameter int POSIT_ATTRIB_LENGTH_MSB		= 8+WIDTH_LENGTH-1;
	parameter int POSIT_ATTRIB_LENGTH_LSB		= 8;


	//// Bit-Range for Decoding Configuration Word for RE			////
	parameter int POSIT_MEM_CONFIG_MODE_MSB		= WIDTH_DATA -  2 - 1;
	parameter int POSIT_MEM_CONFIG_MODE_LSB		= WIDTH_DATA -  4;
	parameter int POSIT_MEM_CONFIG_INDIRECT		= WIDTH_DATA -  5;
	parameter int POSIT_MEM_CONFIG_LENGTH_MSB	= WIDTH_DATA -  8 - 1;
	parameter int POSIT_MEM_CONFIG_LENGTH_LSB	= WIDTH_DATA - 16;
	parameter int POSIT_MEM_CONFIG_STRIDE_MSB	= WIDTH_DATA - 16 - 1;
	parameter int POSIT_MEM_CONFIG_STRIDE_LSB	= WIDTH_DATA - 24;
	parameter int POSIT_MEM_CONFIG_BASE_MSB		= WIDTH_DATA - 24 - 1;
	parameter int POSIT_MEM_CONFIG_BASE_LSB		= WIDTH_DATA - 32;

	localparam int NUM_F	= NUM_LINK*NUM_CHANNEL;
	localparam int NUM_M	= NUM_LINK+NUM_CRAM;
	localparam int NUM_T	= NUM_CHANNEL*NUM_COMP;

	localparam int NUM_A1	= NUM_LINK*NUM_CHANNEL+NUM_ALU;
	localparam int NUM_A	= NUM_LINK+NUM_ALU*1;
	localparam int NUM_A2	= NUM_LINK+NUM_ALU*2;
	localparam int NUM_A3	= NUM_LINK+NUM_ALU*3;


	//// Base Types													////
	//	 Token Primitives
	typedef logic							valid_t;
	typedef logic							request_t;
	typedef logic							condition_t;
	typedef logic							release_t;
	typedef logic		[WIDTH_DATA-1:0]	data_t;
	typedef logic		[WIDTH_INDEX-1:0]	index_t;
	typedef logic							nack_t;
	typedef logic							terminate_t;

	//	Data Primitive
	typedef data_t		[1:0]				data_2_t;
	typedef data_t		[0:0]				data_1_t;
	typedef data_1_t	[1:0]				data_12_t;
	typedef data_t		[NUM_CHANNEL-1:0]	data_c_t;
	typedef data_t		[NUM_F-1:0]			data_f_t;

	//		used in RE
	typedef data_t		[NUM_M-1:0]			data_fm_t;
	typedef data_fm_t	[NUM_CHANNEL-1:0]	data_fmc_t;

	//		used in RE_IF
	typedef logic		[WIDTH_UNIT-1:0]	data_u_t;
	typedef data_u_t	[NUM_MEMUNIT-1:0]	data_m_t;

	//		used in PE
	typedef data_t		[NUM_A2-1:0]		data_fa2_t;
	typedef data_t		[NUM_A3-1:0]		data_fa3_t;
	typedef data_fa2_t	[NUM_CHANNEL-1:0]	data_fa2c_t;
	typedef data_fa3_t	[NUM_CHANNEL-1:0]	data_fa3c_t;

	typedef data_f_t	[0:0]				data_f1_t;

	//		used in Page
	typedef data_t		[NUM_COMP-1:0]		data_t_t;
	typedef data_t		[NUM_LINK-1:0]		data_l_t;
	typedef data_l_t	[NUM_CHANNEL-1:0]	data_lc_t;
	typedef data_t_t	[0:0]				data_t1_t;

	typedef data_t		[NUM_A-1:0]			data_fa1_t;
	typedef data_fa1_t	[NUM_CHANNEL-1:0]	data_fa1c_t;


	//// Base Bundles												////
	//	 Bundle for Forward Token
	`ifdef  EXTEND
		//Extended Version
		typedef struct packed {
			valid_t		v;
			request_t	a;
			condition_t c;
			release_t	r;
			data_t		d;
			index_t		i;
		} FTk_t;
	`else
		//Baseline Version
		typedef struct packed {
			valid_t		v;
			request_t	a;
			condition_t c;
			release_t	r;
			data_t		d;
		} FTk_t;
	`endif

	//	Bundle for Backward Token
	typedef struct packed {
		nack_t		n;
		terminate_t	t;
		valid_t		v;
		condition_t	c;
	} BTk_t;


	//// Multi-Dimension Bundles									////
	//	 Bundle for Forward Token
	//		Base Bundles
	typedef FTk_t		[0:0]				FTk_1_t;
	typedef FTk_t		[1:0]				FTk_2_t;
	typedef FTk_t		[NUM_CHANNEL-1:0]	FTk_c_t;
	typedef FTk_t		[NUM_F-1:0]			FTk_f_t;
	typedef FTk_t		[NUM_IF-1:0]		FTk_if_t;

	//	 Mainly used for Link
	typedef FTk_1_t		[NUM_F-1:0]			FTk_1f_t;
	typedef FTk_c_t		[NUM_LINK-1:0]		FTk_cl_t;

	//	 Mainly used for LinkOut selecting
	//		load/store path (Fan-out:2)
	typedef FTk_1_t		[1:0]				FTk_12_t;
	typedef FTk_2_t		[2:0]				FTk_21_t;

	//	 DEPTH_FIFO size FIFO used in LinkOut
	typedef FTk_t							FTk_d_t [DEPTH_FIFO-1:0];
	typedef FTk_t							FTk_l_t [DEPTH_L_FIFO-1:0];
	typedef FTk_t							FTk_d1_t [DEPTH_L_FIFO:0];

	//	 Bundle for Backward Token
	//		Base Bundles
	typedef BTk_t		[0:0]				BTk_1_t;
	typedef BTk_t		[1:0]				BTk_2_t;
	typedef BTk_t		[NUM_CHANNEL-1:0]	BTk_c_t;
	typedef BTk_t		[NUM_F-1:0]			BTk_f_t;
	typedef BTk_t		[NUM_IF-1:0]		BTk_if_t;

	//	 Mainly used for Link
	typedef BTk_1_t		[NUM_F-1:0]			BTk_1f_t;
	typedef BTk_c_t		[NUM_LINK-1:0]		BTk_cl_t;

	//	 Mainly used for LinkOut selecting
	//		load/store path (Fan-out:2)
	typedef BTk_1_t		[1:0]				BTk_12_t;
	typedef BTk_2_t		[0:0]				BTk_21_t;


	//// Bundles for Retiming Element (RE)							////
	//	 Forward Token
	typedef FTk_t		[NUM_CRAM-1:0]		FTk_re_t;

	typedef FTk_c_t		[NUM_M-1:0]			FTk_cfm_t;
	typedef FTk_cfm_t	[NUM_LINK-1:0]		FTk_cfml_t;
	typedef FTk_f_t		[NUM_CRAM-1:0]		FTk_fm_t;

	//	 Backward Token
	typedef BTk_t		[NUM_CRAM-1:0]		BTk_re_t;

	typedef BTk_c_t		[NUM_M-1:0]			BTk_cfm_t;
	typedef BTk_cfm_t	[NUM_LINK-1:0]		BTk_cfml_t;
	typedef BTk_f_t		[NUM_CRAM-1:0]		BTk_fm_t;


	//// Bundles for Compute Element (PE)					 		////
	//	 Forward Token
	typedef FTk_t		[NUM_ALU-1:0]		FTk_a_t;
	typedef FTk_a_t		[NUM_CHANNEL-1:0]	FTk_ac_t;
	typedef FTk_c_t		[NUM_A-1:0]			FTk_cfa1_t;
	typedef FTk_c_t		[NUM_A2-1:0]		FTk_cfa2_t;
	typedef FTk_cfa1_t	[NUM_LINK-1:0]		FTk_cfa1l_t;
	typedef FTk_cfa2_t	[NUM_LINK-1:0]		FTk_cfa2l_t;
	typedef FTk_f_t		[NUM_ALU*2-1:0]		FTk_fa2_t;
	typedef FTk_c_t		[NUM_A3-1:0]		FTk_cfa3_t;
	typedef FTk_cfa3_t	[NUM_LINK-1:0]		FTk_cfa3l_t;
	typedef FTk_f_t		[NUM_A-1:0]			FTk_fa1_t;
	typedef FTk_f_t		[NUM_ALU*3-1:0]		FTk_fa3_t;
	typedef FTk_f_t		[NUM_ALU-1:0]		FTk_a1f_t;

	//	 Backward Token
	typedef BTk_t		[NUM_ALU-1:0]		BTk_a_t;
	typedef BTk_a_t		[NUM_CHANNEL-1:0]	BTk_ac_t;
	typedef BTk_c_t		[NUM_A-1:0]			BTk_cfa1_t;
	typedef BTk_c_t		[NUM_A2-1:0]		BTk_cfa2_t;
	typedef BTk_cfa1_t	[NUM_LINK-1:0]		BTk_cfa1l_t;
	typedef BTk_cfa2_t	[NUM_LINK-1:0]		BTk_cfa2l_t;
	typedef BTk_f_t		[NUM_ALU*2-1:0]		BTk_fa2_t;
	typedef BTk_c_t		[NUM_A3-1:0]		BTk_cfa3_t;
	typedef BTk_cfa3_t	[NUM_LINK-1:0]		BTk_cfa3l_t;
	typedef BTk_f_t		[NUM_A-1:0]			BTk_fa1_t;
	typedef BTk_f_t		[NUM_ALU*3-1:0]		BTk_fa3_t;
	typedef BTk_f_t		[NUM_ALU-1:0]		BTk_a1f_t;

	//	 Types for Working-Set
	typedef FTk_t		[NUM_WORKER-1:0]	FTk_W_t;
	typedef BTk_t		[NUM_WORKER-1:0]	BTk_W_t;


	//// Configurations for Link Element (LE)						////
	//	 Baseline
	typedef logic		[0:0]				bit1_t;
	typedef logic		[1:0]				bit2_t;
	typedef bit2_t		[NUM_CHANNEL-1:0]	bit2_c_t;
	typedef logic		[NUM_CHANNEL-1:0]	bit_c_t;
	typedef logic		[NUM_F-1:0]			bit_f_t;
	typedef bit_c_t		[NUM_LINK-1:0]		bit_cl_t;
	typedef bit2_c_t	[NUM_LINK-1:0]		bit2_cl_t;
	typedef bit2_t		[0:0]				bit2_1_t;
	typedef bit2_t		[1:0]				bit2_2_t;
	typedef bit2_1_t	[1:0]				bit2_12_t;
	typedef bit2_1_t	[NUM_CHANNEL-1:0]	bit2_1c_t;
	typedef bit2_1_t	[NUM_T-1:0]			bit2_1t_t;

	//	 used in LinkIn for Grant generation
	typedef logic		[0:0]				sbit_t;
	typedef sbit_t		[1:0]				bit_12_t;
	typedef bit2_t		[0:0]				bit_21_t;

	typedef logic		[$clog2(NUM_F)-1:0]	log_f_t;
	typedef log_f_t		[0:0]				log_f1_t;


	//// Configurations for Page									////
	typedef sbit_t		[NUM_T-1:0]			bit_1t_t;
	typedef sbit_t		[NUM_T-1:0]			bit_1if_t;
	typedef logic		[NUM_T-1:0]			bit_if_t;
	typedef bit_if_t	[0:0]				bit_t1_t;
	typedef sbit_t		[$clog2(NUM_T)-1:0]	log_cif_t;

	//	 used in PE
	typedef bit2_t		[NUM_F-1:0]			bit2_f_t;
	typedef bit2_f_t	[NUM_ALU-1:0]		bit2_fa_t;
	typedef bit2_2_t	[NUM_ALU-1:0]		bit2_2a_t;
	typedef bit2_t		[NUM_ALU-1:0]		bit2_a_t;
	typedef bit2_c_t	[NUM_ALU-1:0]		bit2_ca_t;
	typedef logic		[NUM_ALU-1:0]		bit_a_t;
	typedef bit_c_t		[NUM_A1-1:0]		bit_cla_t;
	typedef bit_c_t		[NUM_A2-1:0]		bit_cla2_t;
	typedef bit_c_t		[NUM_A3-1:0]		bit_cla3_t;

	typedef logic		[NUM_A-1:0]			bit_fa1_t;
	typedef logic		[NUM_A2-1:0]		bit_fa2_t;
	typedef logic		[NUM_A3-1:0]		bit_fa3_t;
	typedef bit_fa1_t	[NUM_CHANNEL-1:0]	bit_fa1c_t;
	typedef bit_fa2_t	[NUM_CHANNEL-1:0]	bit_fa2c_t;
	typedef bit_fa3_t	[NUM_CHANNEL-1:0]	bit_fa3c_t;

	typedef bit_f_t		[0:0]				bit_f1_t;

	typedef logic		[$clog2(NUM_A2)-1:0]log_pe_;
	typedef logic		[$clog2(NUM_A3)-1:0]log_pe__;
	typedef log_pe_		[NUM_CHANNEL-1:0]	log_pe_t;
	typedef log_pe__	[NUM_CHANNEL-1:0]	log_pe__t;

	//	 used in RE
	typedef logic		[NUM_CRAM-1:0]		bit_mem_t;
	typedef bit2_2_t	[NUM_CRAM-1:0]		bit2_2mem_t;
	typedef bit2_c_t	[NUM_CRAM-1:0]		bit2_cmem_t;
	typedef bit_c_t		[NUM_M-1:0]			bit_cfm_t;
	typedef bit2_c_t	[NUM_M-1:0]			bit2_cfm_t;

	typedef logic		[NUM_M-1:0]			bit_fm_t;
	typedef bit_fm_t	[NUM_CHANNEL-1:0]	bit_fmc_t;

	typedef logic		[$clog2(NUM_M)-1:0]	log_re_;
	typedef log_re_		[NUM_CHANNEL-1:0]	log_re_t;

	//	 used in Page
	typedef logic		[$clog2(NUM_T)-1:0]	log_t_t;
	typedef log_t_t		[0:0]				log_t1_t;

	//
	typedef logic		[NUM_LINK-1:0]		bit_l_t;
	typedef bit_l_t		[NUM_CHANNEL-1:0]	bit_lc_t;

	//typedef logic	[$clog2(NUM_LINK)-1:0]	bit_nl_t;
	typedef logic		[2-1:0]				bit_nl_t;
	typedef bit_nl_t	[NUM_CHANNEL-1:0]	log_nlc_t;

	//	 PE <-> RE Connection
	typedef bit2_cl_t	[(NUM_CLM+1)/2-1:0]	bit2_clclm_t;
	typedef bit2_clclm_t[NUM_ROW-1:0]		bit2_clclmrow_t;

	//	 Forward Token
	typedef FTk_1_t		[NUM_COMP-1:0]		FTk_1t_t;
	typedef FTk_1_t		[NUM_LINK-1:0]		FTk_1l_t;
	typedef FTk_c_t		[NUM_COMP-1:0]		FTk_ccomp_t;
	typedef FTk_c_t		[NUM_CLM-1:0]		FTk_cclm_t;
	typedef FTk_c_t		[NUM_ROW-1:0]		FTk_crow_t;

	typedef FTk_cl_t	[(NUM_CLM+1)/2-1:0]	FTk_clclm_t;
	typedef FTk_cl_t	[NUM_ROW-1:0]		FTk_clrow_t;

	typedef FTk_clrow_t	[NUM_CLM-1:0]		FTk_clrowclm_t;
	typedef FTk_clclm_t	[NUM_ROW-1:0]		FTk_clclmrow_t;

	typedef FTk_cclm_t	[NUM_IF-1:0]		FTk_cclm_if_t;
	typedef FTk_crow_t	[NUM_IF-1:0]		FTk_crow_if_t;

	//	 Backward Token
	typedef BTk_1_t		[NUM_T-1:0]			BTk_1t_t;
	typedef BTk_1_t		[NUM_LINK-1:0]		BTk_1l_t;
	typedef BTk_c_t		[NUM_COMP-1:0]		BTk_ccomp_t;
	typedef BTk_c_t		[NUM_CLM-1:0]		BTk_cclm_t;
	typedef BTk_c_t		[NUM_ROW-1:0]		BTk_crow_t;

	typedef BTk_cl_t	[(NUM_CLM+1)/2-1:0]	BTk_clclm_t;
	typedef BTk_cl_t	[NUM_ROW-1:0]		BTk_clrow_t;

	typedef BTk_clrow_t	[NUM_CLM-1:0]		BTk_clrowclm_t;
	typedef BTk_clclm_t [NUM_ROW-1:0]		BTk_clclmrow_t;

	typedef BTk_cclm_t  [NUM_IF-1:0]		BTk_cclm_if_t;
	typedef BTk_crow_t  [NUM_IF-1:0]		BTk_crow_if_t;


	typedef FTk_1_t		[NUM_T-1:0]			FTk_1ct_t;
	typedef BTk_1_t		[NUM_T-1:0]			BTk_1ct_t;


	typedef logic		[WIDTH_EXADDR-1:0]	ExAddr_t;


	//// FSM State for Token Unit									////
	typedef enum logic [1:0] {
		eMPTY			= 2'b00,
		fILL			= 2'b01,
		wAIT			= 2'b10,
		rEVERT			= 2'b11
	} fsm_token;

endpackage