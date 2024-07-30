///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Block Managemer
//		Module Name:	Ld_BackEnd_CTRL_Block
//		Function:
//						Contorl Service Loading Data Word
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module BlockCTRL
	import	pkg_mem::*;
#(
	parameter int EXTERNAL			= 1
)(
	input							clock,
	input							reset,
	input							I_Event_Load,		//Flag: Event of Loading
	input							I_Indirect,			//Flag: Indirec-Access Mode
	input							I_Valid,			//Valid Token from loaded data
	input							is_Bypass,			//Flag: Bypass
	input							is_Term,			//Flag: Terminal Block
    input   [7:0]                   I_Length,			//Block Length
	input							I_Term_AddrGen,		//Termination on AGU
	input							I_Set_RConfig,		//Set R-Configuration Data
	input							I_Run,				//Flag: State in Loading
	input							is_RoutingData,		//Flag: Routing Data Block
	input							is_End_Rename,		//Flag: End of Rename
	output	logic					O_is_MyID,			//Flag: My-ID
	output	logic					O_is_AttributeWord,	//Flag: Attribute Word
	output	logic					O_is_End_Block,		//End of Block (One-Cycle Delayed)
	output	logic					O_is_End_Term_Block	//End of Terminal Block
);


	logic							Ext;
	assign Ext = EXTERNAL;


	//// Connecting Logic											////
	logic							End_LoadIDs;
	logic							End_Block;
	logic							End_Term_Block;


	//// Capturing Logic											////
	fsm_ldbe_block					R_FSM_Block;
	logic   [1:0]					R_CntID;
	logic	[8:0]					R_Length;
	logic							R_is_Term;
	logic							R_is_Term_AGU;

	assign O_is_MyID			= R_FSM_Block == lD_BLOCK_MYID;
	assign O_is_AttributeWord	= R_FSM_Block == lD_BLOCK_ATTRIB;
	assign O_is_End_Block		= End_Block;
	assign O_is_End_Term_Block	= End_Term_Block;

	assign End_LoadIDs			= ( R_CntID == 2'h3 ) & I_Valid;
	assign End_Term_Block		= ( R_Length == 1 ) & R_is_Term;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			End_Block		<= 1'b0;
		end
		else if (
					( ( R_FSM_Block == lD_BLOCK_BLOCK ) & I_Set_RConfig & End_Term_Block ) |
					( R_Length == '0 )
				) begin
			End_Block		<= 1'b0;
		end
		else if ( R_Length == 1 ) begin
			End_Block		<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
        if ( reset ) begin
			R_CntID			<= '0;
        end
        else if ( End_LoadIDs ) begin
			R_CntID			<= '0;
        end
        else if ( ( R_CntID > 0 ) & I_Valid ) begin
			R_CntID			<= R_CntID + 1'b1;
        end
        else if (
					I_Event_Load |
					( ( R_FSM_Block == lD_BLOCK_INIT )  & I_Event_Load & ~is_Bypass ) |
					( ( R_FSM_Block == lD_BLOCK_BLOCK ) & End_Term_Block & I_Valid & ~is_Bypass ) |
					( ( R_FSM_Block == lD_BLOCK_TAIL )  & End_Term_Block )
				) begin
			R_CntID			<= 2'h1;
        end
    end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_FSM_Block		<= lD_BLOCK_INIT;
		end
		else case ( R_FSM_Block )
			lD_BLOCK_INIT: begin
				//Idling
				if ( I_Event_Load & ~is_Bypass  ) begin
					//Start Loading IDs
					R_FSM_Block		<= lD_BLOCK_MYID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= ( R_Length > 0 ) ? R_Length : I_Length + 1'b1;
				end
				else if ( I_Event_Load & is_Bypass ) begin
					//Block Body
					R_FSM_Block		<= lD_BLOCK_BLOCK;
					R_is_Term		<= R_is_Term | is_Term;
					R_is_Term_AGU	<= I_Term_AddrGen;
					R_Length		<= ( I_Indirect ) ? I_Length : I_Length + 1'b1;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
			end
			lD_BLOCK_MYID: begin
				//Loading IDs
				if ( I_Term_AddrGen ) begin
					R_FSM_Block		<= lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else if ( I_Valid ) begin
					//Start Block
					R_FSM_Block		<= lD_BLOCK_ID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= R_Length;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_MYID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= R_Length;
				end
			end
			lD_BLOCK_ID: begin
				//Loading IDs
				if ( End_LoadIDs ) begin
					//Start Block
					R_FSM_Block		<= lD_BLOCK_ATTRIB;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= R_Length - I_Valid;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_ID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= R_Length - I_Valid;
				end
			end
			lD_BLOCK_ATTRIB: begin
				//Attribute Block
				if ( I_Valid ) begin
					//Block Body
					R_FSM_Block		<= lD_BLOCK_BLOCK;
					R_is_Term		<= R_is_Term | is_Term;
					R_is_Term_AGU	<= I_Term_AddrGen;
					R_Length		<= ( is_RoutingData ) ? 1 : ( R_Length > 0 ) ? R_Length - I_Valid : I_Length + 1'b1;
				end
				else if ( I_Term_AddrGen ) begin
					R_FSM_Block		<= lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b1;
					R_Length		<= '0;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_ATTRIB;
					R_is_Term		<= R_is_Term | is_Term;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
			end
			lD_BLOCK_BLOCK: begin
				//Block Body
				if ( is_End_Rename ) begin
					R_FSM_Block		<= lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else if ( R_is_Term_AGU & End_Term_Block & I_Valid ) begin
					R_FSM_Block		<= lD_BLOCK_TAIL;
					R_is_Term		<= R_is_Term;
					R_is_Term_AGU	<= R_is_Term_AGU;
					R_Length		<=( is_RoutingData ) ? 1 : I_Length + 1'b1;
				end
				else if ( I_Set_RConfig & End_Term_Block & I_Valid ) begin
					R_FSM_Block		<= lD_BLOCK_TAIL;
					R_is_Term		<= R_is_Term;
					R_Length		<=( is_RoutingData ) ? 1 : I_Length + 1'b1;
				end
				else if ( End_Term_Block & I_Valid & ~is_Bypass ) begin
					R_FSM_Block		<= lD_BLOCK_MYID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else if ( ( R_Length == 1 ) & I_Valid ) begin
					R_FSM_Block		<= ( is_Bypass ) ? lD_BLOCK_INIT : (EXTERNAL) ? lD_BLOCK_ATTRIB : lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_BLOCK;
					R_is_Term		<= R_is_Term;
					R_is_Term_AGU	<= R_is_Term_AGU | I_Term_AddrGen;
					R_Length		<= R_Length - I_Valid;
				end
			end
			lD_BLOCK_TAIL: begin
				//Block Body (Tail)
				if ( I_Term_AddrGen & ~R_is_Term ) begin
					R_FSM_Block		<= lD_BLOCK_BLOCK;
					R_is_Term		<= R_is_Term;
					R_is_Term_AGU	<= 1'b1;
					R_Length		<= R_Length;
				end
				else if ( Ext & End_Term_Block ) begin
					R_FSM_Block		<= lD_BLOCK_MYID;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else if ( ( R_Length == 1 ) & R_is_Term ) begin
					R_FSM_Block		<= lD_BLOCK_INIT;
					R_is_Term		<= 1'b0;
					R_is_Term_AGU	<= 1'b0;
					R_Length		<= '0;
				end
				else begin
					R_FSM_Block		<= lD_BLOCK_TAIL;
					R_is_Term		<= R_is_Term;
					R_is_Term_AGU	<= I_Term_AddrGen;
					R_Length		<= R_Length - I_Valid;
				end
			end
			default: begin
				R_FSM_Block		<= lD_BLOCK_INIT;
				R_is_Term		<= 1'b0;
				R_is_Term_AGU	<= 1'b0;
				R_Length		<= '0;
			end
		endcase
	end

endmodule
