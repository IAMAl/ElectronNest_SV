///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Control for Most Frequently Appeared (MFA) Unit
//	Module Name:	MFA_CTRL
//	Function:
//					used for Index Compression
//					Controller for MFA Unit in CRAM
//					This unit is used for extension; Index-Compression.
//					The extension find most frequently appeared value.
//					The value is removed from the data block,
//						and treated as a shared data.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module MFA_CTRL
	import	pkg_en::*;
	import	pkg_extend_index::*;
(
	input							clock,
	input							reset,
	input	FTk_t					I_Cfg_FTk,			//Config Data from CfgGen
	input	FTk_t					I_Ld_FTk,			//from StLdCRAM
	output	FTk_t					O_Ld_FTk,			//to Ld_CRAM
	input	BTk_t					I_Ld_BTk,			//from Ld_CRAM to Load Path
	output	BTk_t					O_Ld_BTk,			//from Ld_CRAM to Memory
	input	FTk_t					I_St_FTk,			//from StLDCRAM
	output	FTk_t					O_St_FTk,			//to St_CRAM
	input	BTk_t					I_St_BTk,			//from Memory to ST_CRAM
	output	BTk_t					O_St_BTk,			//to St_CRAM
	output	logic					O_Snoop_AttribRCfg,	//Flag: Snoop Attribute Word for R-Config
	output	logic					O_Str_Snoop,		//Flag: Start Snooping Config Data
	input							I_End_Snoop,		//Flag: End of Snooping Config Data
	output	logic					O_Snoop_AttribData,	//Flag: Snoop Attribute Word for Data Block
	input							is_SharedConfig,	//Flag: Share Flag in Config Word
	input							is_SharedAttrib,	//Flag: Share Flag in Attrib Word
	output	logic					O_Str_Rd,			//Flag: Start Read Config. Data
	input							I_End_Rd,			//Flag: End of Read Config. Data
	output	logic					O_En_MFA,			//Flag: Enable Working MFA-Unit
	output	logic					O_Sel_St,			//Select Store
	output	logic					O_Rd_MFA,			//Read MFA Val after the work
	input							I_Ld_End,			//Flag: End of Loading
	input							I_St_End,			//Flag: End of Storing
	output	logic					O_Set_SData,		//Flag: Capture Shared Data Word
	output	logic					O_Busy_MFA,			//Flag: in MFA Detection  State
	output	logic					O_Str_Restore,		//Flag: Start Restoring
	output	logic					O_NeLoad,			//Flag: DIsable Loading
	output	logic					O_Run_Restore,		//Flag: State in Restoring
	output	logic					O_Next_Restore,		//Flag: Next is Restore
	output	logic					O_End_MFA,			//Flag: End of MFA Sequence
	output	logic					O_End_MFACfgGen		//Flag: End of MFA Config Gen
);


	//// Finite State Machine										////
	fsm_mfa						FSM_MFA;


	//// Logic Connect												////
	//		Toklen Decode for Decode
	logic						Ld_acq_message;
	logic						Ld_rls_message;
	logic						Ld_acq_flagmsg;
	logic						Ld_rls_flagmsg;

	//		Token Decode for Store
	logic						is_St_Acq;
	logic						is_St_Rls;
	logic						St_acq_message;
	logic						St_rls_message;
	logic						St_acq_flagmsg;
	logic						St_rls_flagmsg;

	//		Read Header ID
	logic						Rd_Header_Ld;
	logic						Rd_Header_St;

	//		Header ID
	FTk_t						ID_Ld;
	FTk_t						ID_St;

	//		Stop Receiving Message
	logic						Stop_Ld;

	//		Store Termination
	logic						is_Term_St;

	//
	FTk_t						W_Ld_FTk;
	BTk_t						W_Ld_BTk;

	//		Storing IDs for Snooping
	logic						is_StoreIDs;
	logic						Str_StoreIDs;
	logic						End_StoreIDs;

	logic						Str_LoadIDs_St;
	logic						Str_LoadIDs_Ld;

	logic						Str_LoadIDs;
	logic						End_LoadIDs;

	logic						is_LoadIDs_St;
	logic						is_LoadIDs_Ld;
	logic						is_LoadIDs;

	logic						Store_IDs;

	logic						One;

	logic						Nack_Follower;

	FTk_t						Cfg_FTk;


	//// Capture Signal												////
	logic [1:0]					R_CNT_IDs;

	logic						R_End_Ld;
	logic						R_End_St;

	logic						R_En_MFA;
	FTk_t						R_Cfg_FTk;
	logic [WIDTH_DATA-1:0]		R_IDs [2:0];


	//// End Of Snooping											////
	assign O_End_MFACfgGen		= ( FSM_MFA == MFA_INIT );


	//// Snoop Attribute Word for Store-Configuration				////
	assign O_Snoop_AttribRCfg	= ( FSM_MFA == MFA_ATTRIBST );


	//// Start Snooping Store-Configuration Data					////
	assign O_Str_Snoop		= ( FSM_MFA == MFA_ATTRIBST ) & I_St_FTk.v;


	//// Snoop Attribute Word for Data Block						////
	assign O_Snoop_AttribData	= ( FSM_MFA == MFA_ATTRIBDAT );


	//// Enable working on MFA Unit									////
	assign O_En_MFA			= (( FSM_MFA == MFA_ATTRIBST ) & I_St_FTk.v ) |
								(( FSM_MFA > MFA_ATTRIBST ) & ( FSM_MFA < MFA_SETHEADST ));


	//// Start Load/Store for Restoring								////
	assign O_Str_Rd			= ( FSM_MFA == MFA_SETATTRIBST ) | ( FSM_MFA == MFA_SETATTRIBLD );


	//// Start Restoring											////
	//	 Enable to bypass from I_Ld_Bps to O_St_FTk in MFA_CRAM
	assign O_Sel_St			= ( FSM_MFA == MFA_RESTORE );


	//// Flag Busy State on MFA unit								////
	assign O_Busy_MFA		= R_En_MFA;


	//// in State of Restoring										////
	assign O_Str_Restore	= ( FSM_MFA == MFA_SETCFGLD ) & I_End_Rd;
	assign O_NeLoad			= ( FSM_MFA > MFA_SETCFGST );
	assign O_Run_Restore	= ( FSM_MFA == MFA_RESTORE );


	//// Flag End of Restoring Work									////
	assign O_End_MFA		= ( FSM_MFA == MFA_RESTORE ) & is_Term_St;


	//// Avoid Unnecessary End of Storing							////
	assign O_Next_Restore	= ( FSM_MFA == MFA_SETCFGLD );


	//// Capture Shared Data Word in Data Block						////
	assign O_Set_SData		= ( FSM_MFA == MFA_SHAREDDAT );


	//// Read-out MFA Data											////
	assign O_Rd_MFA			= ( FSM_MFA == MFA_SETHEADST ) & ~End_LoadIDs;


	//// Capture MFA-Enable (1 clock cycle delayed)					////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_En_MFA	<= 1'b0;
		end
		else if ( FSM_MFA == MFA_ENDSTORE ) begin
			R_En_MFA	<= 1'b0;
		end
		else begin
			R_En_MFA	<= ( FSM_MFA > MFA_SNOOPCFG ) & ( FSM_MFA < MFA_ENDSTORE );
		end
	end


	//// Termination Detection										////
	assign is_Term_St		= ( R_End_Ld | ( I_Ld_End & ( FSM_MFA > MFA_SETCFGLD ))) &
								( R_End_St | ( I_St_End & ( FSM_MFA > MFA_SETCFGLD )));

	//	 Termination on Loading
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_Ld	<= 1'b0;
		end
		else if ( is_Term_St ) begin
			R_End_Ld	<= 1'b0;
		end
		else if ( I_Ld_End & ( FSM_MFA > MFA_SETCFGLD ) ) begin
			R_End_Ld	<= 1'b1;
		end
		else begin
			R_End_Ld	<= R_End_Ld;
		end
	end

	//	 Termination on Storing
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_End_St	<= 1'b0;
		end
		else if ( is_Term_St ) begin
			R_End_St	<= 1'b0;
		end
		else if ( I_St_End & ( FSM_MFA > MFA_SETCFGLD ) ) begin
			R_End_St	<= 1'b1;
		end
		else begin
			R_End_St	<= R_End_St;
		end
	end


	assign is_St_Acq		= St_acq_message | St_acq_flagmsg;
	assign is_St_Rls		= St_rls_message | St_rls_flagmsg;


	//// ID Handling												////
	assign Str_StoreIDs		= ( FSM_MFA == MFA_INIT ) & is_St_Acq;
	assign End_StoreIDs		= ( FSM_MFA == MFA_STOREREQ ) & ( R_CNT_IDs == 2'h2 ) & I_St_FTk.v;
	assign is_StoreIDs		= ( FSM_MFA == MFA_STOREREQ ) | Str_StoreIDs;

	assign Str_LoadIDs_St	= ( FSM_MFA == MFA_ENDSTORE );
	assign Str_LoadIDs_Ld	= ( FSM_MFA == MFA_SETCFGST ) & I_End_Rd;
	assign Str_LoadIDs		= Str_LoadIDs_St | Str_LoadIDs_Ld;

	//	 Loading IDs for Restoring
	assign is_LoadIDs_St	= Str_LoadIDs_St |  ( FSM_MFA == MFA_SETHEADST );
	assign is_LoadIDs_Ld	= Str_LoadIDs_Ld | (( FSM_MFA == MFA_SETHEADLD ) & ~I_End_Rd );
	assign is_LoadIDs		= is_LoadIDs_Ld | is_LoadIDs_St;

	assign End_LoadIDs		= One & is_LoadIDs & ( R_CNT_IDs == 2'h2 );

	//	 Count IDs
	assign One				= ( is_LoadIDs ) ? 1'b1 : I_St_FTk.v;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_CNT_IDs	<= 2'h0;
		end
		else if ( End_StoreIDs ) begin
			R_CNT_IDs	<= 2'h0;
		end
		else if ( End_LoadIDs ) begin
			R_CNT_IDs	<= 2'h0;
		end
		else if ( is_StoreIDs | is_LoadIDs ) begin
			R_CNT_IDs	<= R_CNT_IDs + One;
		end
		else begin
			R_CNT_IDs	<= R_CNT_IDs;
		end
	end


	//// To Ld_CRAM													////
	assign Rd_Header_Ld		= is_LoadIDs_Ld;
	assign ID_Ld.v			= Rd_Header_Ld;
	assign ID_Ld.a			= Str_LoadIDs_Ld;
	assign ID_Ld.r			= 1'b0;
	assign ID_Ld.c			= 1'b0;
	`ifdef EXTEND
	assign ID_Ld.i			= '0;
	`endif
	assign ID_Ld.d			= ( Rd_Header_Ld ) ? R_IDs[ R_CNT_IDs ] : '0;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Cfg_FTk	<= '0;
		end
		else begin
			R_Cfg_FTk	<= I_Cfg_FTk;
		end
	end

	assign O_Ld_FTk			= ( Rd_Header_Ld ) ?					ID_Ld :
								( FSM_MFA == MFA_SETATTRIBLD ) ?	R_Cfg_FTk :
								( FSM_MFA == MFA_SETCFGLD ) ?		R_Cfg_FTk :
								( FSM_MFA  > MFA_SETHEADST ) ?		'0 :
																	I_Ld_FTk;


	//// Send Back Prop Tokens to LdStCRAM							////
	//	 Stop to Recive Message when Restoring
	assign Stop_Ld			= FSM_MFA != MFA_INIT;

	//	 Assert Nack Token to Block Follower Access-Request
	assign O_Ld_BTk.n		= I_Ld_BTk.n | Stop_Ld;
	assign O_Ld_BTk.t		= I_Ld_BTk.t;
	assign O_Ld_BTk.v		= I_Ld_BTk.v;
	assign O_Ld_BTk.c		= I_Ld_BTk.c;


	//// To St_CRAM													////
	assign Rd_Header_St		= is_LoadIDs_St;
	assign ID_St.v			= Rd_Header_St;
	assign ID_St.a			= Str_LoadIDs_St;
	assign ID_St.r			= 1'b0;
	assign ID_St.c			= 1'b0;
	`ifdef EXTEND
	assign ID_St.i			= '0;
	`endif
	assign ID_St.d			= ( Rd_Header_St ) ? R_IDs[ R_CNT_IDs ] : '0;

	assign Cfg_FTk.v		= R_Cfg_FTk.v;
	assign Cfg_FTk.a		= R_Cfg_FTk.a;
	assign Cfg_FTk.r		= ( FSM_MFA == MFA_SETCFGST ) ? 1'b0 : R_Cfg_FTk.r;
	assign Cfg_FTk.c		= R_Cfg_FTk.c;
	`ifdef EXTEND
	assign Cfg_FTk.i		= R_Cfg_FTk.i;
	`endif
	assign Cfg_FTk.d		= R_Cfg_FTk.d;

	assign O_St_FTk			= ( Rd_Header_St ) ?											ID_St :
								(( FSM_MFA == MFA_SETHEADST ) & End_LoadIDs ) ?				Cfg_FTk :
								(  FSM_MFA == MFA_SETATTRIBST ) ?							Cfg_FTk :
								(  FSM_MFA == MFA_SETCFGST ) ?								Cfg_FTk :
								(( FSM_MFA  > MFA_SETCFGST ) & ( FSM_MFA < MFA_RESTORE )) ?	'0 :
								(  FSM_MFA == MFA_RESTORE ) ?								I_Ld_FTk :
																							I_St_FTk;

	//	 Assert Nack Token to Follower's Access-Request
	assign Nack_Follower	= ( FSM_MFA > MFA_STORE );
	assign O_St_BTk.n		= I_St_BTk.n | Nack_Follower;
	assign O_St_BTk.t		= I_St_BTk.t;
	assign O_St_BTk.v		= I_St_BTk.v;
	assign O_St_BTk.c		= I_St_BTk.c;


	//// Capture IDs at Storing										////
	assign Store_IDs		= ( ( FSM_MFA == MFA_INIT ) & is_St_Acq ) | is_StoreIDs;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_IDs[0]			<= '0;
			R_IDs[1]			<= '0;
			R_IDs[2]			<= '0;
		end
		else if ( Store_IDs ) begin
			R_IDs[ R_CNT_IDs ]	<= I_St_FTk.d;
		end
	end


	//// Control FSM												////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			FSM_MFA		<= MFA_INIT;
		end
		else case ( FSM_MFA )
			MFA_INIT: begin			// Store Req Detected
				if ( is_St_Acq ) begin
					FSM_MFA		<= MFA_STOREREQ;
				end
				else begin
					FSM_MFA		<= MFA_INIT;
				end
			end
			MFA_STOREREQ: begin		// Storing IDs
				if ( End_StoreIDs ) begin
					FSM_MFA		<= MFA_ATTRIBST;
				end
			end
			MFA_ATTRIBST: begin		// Attribute Word (for RConfig)
				if ( I_St_FTk.v ) begin
					FSM_MFA		<= MFA_SNOOPCFG;
				end
			end
			MFA_SNOOPCFG: begin		// End of Snooping Store Config Data
				if ( is_SharedConfig & I_End_Snoop ) begin
					FSM_MFA		<= MFA_ATTRIBDAT;
				end
				else if ( ~is_SharedConfig & I_End_Snoop ) begin
					FSM_MFA		<= MFA_INIT;
				end
			end
			MFA_ATTRIBDAT: begin	// Attribute Word (Data Block)
				if ( I_St_FTk.v &  is_SharedAttrib ) begin
					FSM_MFA		<= MFA_SHAREDDAT;
				end
				if ( I_St_FTk.v & ~is_SharedAttrib ) begin
					FSM_MFA		<= MFA_STORE;
				end
			end
			MFA_SHAREDDAT: begin	// Capture Shared Data Word
				if ( I_St_FTk.v ) begin
					FSM_MFA		<= MFA_STORE;
				end
			end
			MFA_STORE: begin		// End of Store Detected
				if ( is_St_Rls ) begin
					FSM_MFA		<= MFA_ENDSTORE;
				end
			end
			MFA_ENDSTORE: begin		// End of Store Detected
				FSM_MFA		<= MFA_SETHEADST;
			end
			MFA_SETHEADST: begin	// Send Header
				if ( End_LoadIDs ) begin
					FSM_MFA		<= MFA_SETATTRIBST;
				end
			end
			MFA_SETATTRIBST: begin	// Attribute Word for Store Config
				FSM_MFA		<= MFA_SETCFGST;
			end
			MFA_SETCFGST: begin		// Restore-Seq: Set Store Config
				if ( I_End_Rd ) begin
					// NOTE This State includes Setting Attrib Word for Data Block
					FSM_MFA		<= MFA_SETHEADLD;
				end
			end
			MFA_SETHEADLD: begin	// Send Header
				if ( End_LoadIDs ) begin
					FSM_MFA		<= MFA_SETATTRIBLD;
				end
			end
			MFA_SETATTRIBLD: begin	// Attrib for Load Config
				FSM_MFA		<= MFA_SETCFGLD;
			end
			MFA_SETCFGLD: begin		// Restore-Seq: Set Load Config
				if ( I_End_Rd ) begin
					// NOTE This State includes Setting Attrib Word for Data Block
					FSM_MFA		<= MFA_RESTORE;
				end
			end
			MFA_RESTORE: begin		// End of Restoring
				if ( is_Term_St ) begin
					FSM_MFA		<= MFA_TERM;
				end
			end
			MFA_TERM: begin			// Read MFA
				FSM_MFA		<= MFA_INIT;
			end
			default: begin
				FSM_MFA		<= MFA_INIT;
			end
		endcase
	end


	//// Capture Loaded Data										////
	DReg R_Ld(
		.clock(				clock						),
		.reset(				reset						),
		.I_We(				1'b1						),
		.I_FTk(				I_Ld_FTk					),
		.O_FTk(				W_Ld_FTk					),
		.O_BTk(				W_Ld_BTk					),
		.I_BTk(				I_Ld_BTk					)
	);


	//// Token Decoder												////
	TokenDec Ld_TokenDec (
		.I_FTk(				I_Ld_FTk					),
		.O_acq_message(		Ld_acq_message				),
		.O_rls_message( 	Ld_rls_message				),
		.O_acq_flagmsg(		Ld_acq_flagmsg				),
		.O_rls_flagmsg(		Ld_rls_flagmsg				)
	);

	TokenDec St_TokenDec (
		.I_FTk(				I_St_FTk					),
		.O_acq_message(		St_acq_message				),
		.O_rls_message( 	St_rls_message				),
		.O_acq_flagmsg(		St_acq_flagmsg				),
		.O_rls_flagmsg(		St_rls_flagmsg				)
	);

endmodule