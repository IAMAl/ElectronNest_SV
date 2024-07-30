///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Load Server Unit (Back-End)
//		Module Name:	Ld_BackEnd_CTRL_Load
//		Function:
//						Serves Loading Data on secondary context.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module LoadCTRL
	import	pkg_mem::*;
(
	input							clock,
	input							reset,
	input							I_Event_Load,		//Event of Loading Detected
	input							I_Valid,			//Valid Token for Loaded Data
	input							I_Stall,			//Stall
	input							I_End_RConfig,		//Flag: End of Setting R-Config
	input							I_Term_AddrGen,		//Flag: Termination of AGU
	input							I_End_Block,		//Flag: End of Block
	input							is_Bypass,			//Flag: Bypass
	input							is_End_Rename,		//Flag: End of Reanme
	output	logic					O_Sleep,			//Flag: State in Init
	output	logic					O_Run,				//Flag: State in Runing
	output	logic					O_Set_RConfig,		//Set R-Config Daata Block
	output	logic					O_Set_AttribWord,	//Set Attribute Word for Loaded Data Block
	output	logic					O_Tail_Load,		//Flag: Loading for Tail Part
	output	logic					O_End_Load			//Flag: End of Loading
);

	fsm_ldbe_load					R_FSM_Load;

	assign O_Sleep				= R_FSM_Load == lD_LOAD_INIT;
	assign O_Run				= R_FSM_Load  > lD_LOAD_SET_RCFG;
	assign O_Set_RConfig		= R_FSM_Load == lD_LOAD_SET_RCFG;
	assign O_Set_AttribWord		= R_FSM_Load == lD_LOAD_SET_ATTRIB;
	assign O_Tail_Load			= R_FSM_Load == lD_LOAD_TAIL;
	assign O_End_Load			= ( R_FSM_Load == lD_LOAD_TAIL ) & I_End_Block;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FSM_Load		<= lD_LOAD_INIT;
		end
		else case ( R_FSM_Load )
			lD_LOAD_INIT: begin
				if ( I_Event_Load & ~is_Bypass ) begin
					R_FSM_Load		<= lD_LOAD_SET_RCFG;
				end
				else if ( I_Event_Load & is_Bypass ) begin
					R_FSM_Load		<= lD_LOAD_SET_ATTRIB;
				end
				else begin
					R_FSM_Load		<= lD_LOAD_INIT;
				end
			end
			lD_LOAD_SET_RCFG: begin
				if ( I_End_RConfig ) begin
					R_FSM_Load		<= lD_LOAD_SET_ATTRIB;
				end
				else begin
					R_FSM_Load		<= lD_LOAD_SET_RCFG;
				end
			end
			lD_LOAD_SET_ATTRIB: begin
				if ( ~I_Stall ) begin
					R_FSM_Load		<= lD_LOAD_LOAD;
				end
				else begin
					R_FSM_Load		<= lD_LOAD_SET_ATTRIB;
				end
			end
			lD_LOAD_LOAD: begin
				if ( I_Term_AddrGen ) begin
					R_FSM_Load		<= lD_LOAD_TAIL;
				end
				else if ( is_End_Rename ) begin
					R_FSM_Load		<= lD_LOAD_INIT;
				end
				else begin
					R_FSM_Load		<= lD_LOAD_LOAD;
				end
			end
			lD_LOAD_TAIL: begin
				if ( I_End_Block ) begin
					R_FSM_Load		<= lD_LOAD_END;
				end
				else begin
					R_FSM_Load		<= lD_LOAD_TAIL;
				end
			end
			lD_LOAD_END: begin
				R_FSM_Load		<= lD_LOAD_INIT;
			end
			default: begin
				R_FSM_Load		<= lD_LOAD_INIT;
			end
		endcase
	end

endmodule
