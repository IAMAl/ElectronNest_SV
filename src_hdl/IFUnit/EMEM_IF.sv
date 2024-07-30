///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load/Store Unit for External Memory
//	Module Name:	EMEM_IF
//	Function:
//					Control Load and Store for External Memory
//					Load and Store units are independent each otrher
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module EMEM_IF
    import pkg_en::*;
	import pkg_mem::*;
	import pkg_bram_if::*;
(
	input								clock,
	input								reset,
	input								I_Boot,
	output	logic						O_Ld_Req,			//Load Request
	output	ext_word_addr_t				O_Ld_Addr,			//Load Address
	input								I_Ld_Ack,			//Load Ack
	input	ext_data_t					I_Ld_Data,			//Load Data
	output	BTk_t						O_Ld_BTk,			//Load Back-Token
	input	FTk_t						I_FTk,	    		//Load-Command from BRAM/CT
	output	BTk_t						O_BTk,	    		//to BRAM/CT
	output	FTk_t						O_FTk,	    		//to BRAM/CT
	input	BTk_t						I_BTk,  			//From BRAM/CT
	output	logic						O_St_Req,			//Store Request
	output	ext_word_addr_t				O_St_Addr,			//Store Address
	input								I_St_Ack,			//Store Ack
	output	ext_data_t					O_St_Data,			//Store Data
	input	BTk_t						I_St_BTk,			//Store Back-Token
	input	FTk_t						I_St_FTk,			//Store-Command from BRAM/CT
	output	BTk_t						O_St_BTk			//to BRAM/CT
);


	LdStUnit #(
		.WIDTH_DATA(		WIDTH_DATA					),
		.WIDTH_ADDR(		WIDTH_EXT_ADDR				),
		.WIDTH_LENGTH(		WIDTH_EXT_ADDR				),
		.WIDTH_UNIT(		WIDTH_UNIT					),
		.NUM_MEMUNIT(		NUM_MEMUNIT					),
		.SIZE_CRAM(			256							)
	) ERAM_LdStUnit
	(
		.clock(				clock						),
		.reset(				reset						),
		.I_Boot(			I_Boot						),
		.I_FTk(				I_FTk						),
		.O_BTk(				O_BTk						),
		.O_FTk(				O_FTk						),
		.I_BTk(				I_BTk						),
		.O_Ld_Req(			O_Ld_Req					),
		.O_Ld_Mode(										),
		.O_Ld_Address(		O_Ld_Addr					),
		.I_Ld_Data(			I_Ld_Data					),
		.O_Ld_BTk(			O_Ld_BTk					),
		.O_St_Req(			O_St_Req					),
		.O_St_Mode(										),
		.O_St_Address(		O_St_Addr					),
		.O_St_Data(			O_St_Data					),
		.I_St_FTk(			I_St_FTk					),
		.I_St_BTk(			I_St_BTk					),
		.O_St_BTk(			O_St_BTk					)
	);

endmodule
