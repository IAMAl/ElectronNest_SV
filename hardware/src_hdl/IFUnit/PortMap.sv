///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Port Allocation Unit
//	Module Name:	PortMap
//	Function:
//					used for Interconnection Network connecting between
//					Compute Tile or External Memory and Global Buffer
//					PortMap Allocate one Interconection for Connecting Them
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module PortMap
	import pkg_bram_if::*;
(
	input							clock,
	input							reset,
	input							I_Req,				//Request from Rename Unit
	input	[WIDTH_PID-1:0]			I_PDstID,			//Physical Dst-ID from Rename Unit
	input	[WIDTH_PID-1:0]			I_PSrcID,			//Physical Src-ID from Rename Unit
	output	nbit_t					O_VldPort,			//Validation for Port-Connection
	output	port_pdst_id_t			O_DstPort,			//Port-No. for Destination
	output	port_psrc_id_t			O_SrcPort,			//Port-No. for Source
	input	[NUM_UNITS-1:0]			I_Commit,			//Flag: Releasing Port-Connection
	output	logic					O_Req,				//Flag: Output Request (Valid)
	output	nbit_t					O_Commit,			//Flag: Commit to Release Rename-Entry
	input	[NUM_UNITS-1:0]			I_Ack,				//Ack from Reorder Buffer
	output	nbit_t					O_DstVld,			//Flag: Valid for Destination Port
	output	nbit_t					O_SrcVld,			//Flag: Valid for Source Port
	output	logic					O_Valid,			//Flag: Validation for Port-Connection
	output	logic					O_Empty_BRAM,		//Flag: All BRAMs are not used
	output	logic					O_Full_BRAM,		//Flag: All BRAMs are used
	output	logic					O_Empty_IFLogic,	//Flag: All IFLogics are not used
	output	logic					O_Full_IFLogic,		//Flag: All IFLogics are used
	output	logic					O_Empty,			//Flag: No Port-Connection
	output	logic					O_Full				//Flag: Fully Ports are Used
);


	//// Map Table													////
	//	 Row:		Source Index
	//	 Column:	Destination Index
	logic	[NUM_UNITS-1:0]		MapTab		[NUM_UNITS-1:0];
	logic	[NUM_UNITS-1:0]		CommitTab	[NUM_UNITS-1:0];
	logic	[NUM_UNITS-1:0]		EnOut		[NUM_UNITS-1:0];

	portmap_t					PortMap;

	nbit_t						Commit;
	logic	[WIDTH_UNITS-1:0]	CommitNo;


	//// Logic Connect												////
	//		Valiadtion Flag
	logic	[NUM_UNITS-1:0]		Valid;

	//		Status Flag
	logic	[NUM_BRAMS-1:0]		Empty_BRAM;
	logic	[NUM_BRAMS-1:0]		Full_BRAM;

	logic	[NUM_ELMS-1:0]		Empty_IFLogic;
	logic	[NUM_ELMS-1:0]		Full_IFLogic;

	logic	[NUM_UNITS-1:0]		Reset_PortValid;
	logic	[WIDTH_UNITS-1:0]	Reset_PortValidNo;

	logic						Empty;
	logic						Full;

	logic						R_Req;

	logic						R_Empty_BRAM;
	logic						R_Full_BRAM;
	logic						R_Empty_IFLogic;
	logic						R_Full_IFLogic;

	nbit_t						R_Commit;


	//// Port-Validation											////
	//	 Destinatino Validation
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			O_DstVld[ i ]	= |EnOut[ i ];
		end
	end

	//	 Source Validation
	assign O_SrcVld			= Valid;


	//// Request (Mapping Done)										////
	assign O_Req			= R_Req;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Req			<= 1'b0;
		end
		else begin
			R_Req			<= I_Req;
		end
	end


	//// Commit Request												////
	assign O_Commit			= R_Commit;


	//// Status on IFLogic											////
	assign O_Empty_IFLogic	= R_Empty_IFLogic;
	assign O_Full_IFLogic	= R_Full_IFLogic;


	//// Status on BRAM												////
	assign O_Empty_BRAM		= R_Empty_BRAM;
	assign O_Full_BRAM		= R_Full_BRAM;


	//// Status Flag Generations									////
	always_comb begin
		for ( int i=0; i<NUM_BRAMS; ++i ) begin
			Empty_BRAM[ i ]	= |MapTab[ i + ID_OFFSET_BRAM ];
			Full_BRAM[ i ]	= |MapTab[ i + ID_OFFSET_BRAM ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Empty_BRAM	<= 1'b0;
			R_Full_BRAM		<= 1'b0;
		end
		else begin
			R_Empty_BRAM	<= ~( |Empty_BRAM );;
			R_Full_BRAM		<= &Full_BRAM;
		end
	end

	always_comb begin
		for ( int i=0; i<NUM_ELMS; ++i ) begin
			Empty_IFLogic[ i ]	= |MapTab[ i + ID_OFFSET_IFLOGIC ];
			Full_IFLogic[ i ]	= |MapTab[ i + ID_OFFSET_IFLOGIC ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Empty_IFLogic	<= 1'b0;
			R_Full_IFLogic	<= 1'b0;
		end
		else begin
			R_Empty_IFLogic	<= ~( |Empty_IFLogic );;
			R_Full_IFLogic	<= &Full_IFLogic;
		end
	end


	//// Preprocessing for Mapping									////
	//	 Validation
	//		Bit-wire OR for Evey Row in MapTab indicating "connected Port" on the row
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Valid[ i ]		= |MapTab[ i ];
		end
	end

	//	 There is one or more Ports-used
	assign O_Valid			= |Valid;

	//	 All Ports are NOT used
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Empty			<= 1'b0;
		end
		else begin
			Empty			<= ~( |Valid );
		end
	end
	assign O_Empty			= Empty;

	//	 All Ports are used
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Full			<= 1'b0;
		end
		else begin
			Full			<= &Valid;
		end
	end
	assign O_Full			= Full;


	//// Map Table													////
	//	 Generate Commit Signal
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int r=0; r<NUM_UNITS; ++r ) begin
				for ( int c=0; c<NUM_UNITS; ++c ) begin
					CommitTab[ r ][ c ]	<= 1'b0;
				end
			end
		end
		else begin
			// Set by reciever (destination) unit
			for ( int r=0; r<NUM_UNITS; ++r ) begin
				for ( int c=0; c<NUM_UNITS; ++c ) begin
					if ( MapTab[ r ][ c ] & I_Commit[ c ] ) begin
						CommitTab[ r ][ c ]	<= 1'b1;
					end
				end
			end

			// Ack from Reorder Buffer releases the entry
			for ( int r=0; r<NUM_UNITS; ++r ) begin
				if ( I_Ack[ r ] ) begin
					CommitTab[ r ]	<= '0;
				end
			end
		end
	end

	//	 Send Commit Requests to Reorder Buffer
	always_comb begin
		for ( int r=0; r<NUM_UNITS; ++r ) begin
			Commit[ r ]		= |CommitTab[ r ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Commit	<= '0;
		end
		else begin
			R_Commit	<= I_Commit;
		end
	end

	//	 Update Map-Table
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<NUM_UNITS; ++i) begin
				for ( int j=0; j<NUM_UNITS; ++j ) begin
					MapTab[ i ][ j ]	<= 1'b0;
				end
			end
		end
		else begin
			if ( I_Req ) begin
				MapTab[ I_PSrcID ][ I_PDstID ]	<= 1'b1;
			end

			// Ack from Reorder Buffer releases the entry
			for ( int r=0; r<NUM_UNITS; ++r ) begin
				if ( I_Ack[ r ] ) begin
					for ( int j=0; j<NUM_UNITS; ++j ) begin
						MapTab[ r ][ j ]	<= 1'b0;
					end
				end
			end
		end
	end


	//// Port Map Table												////
	//	 Output-Enable
	//		Transposing to make Output-Enable Vector
	always_comb begin
		for ( int r=0; r<NUM_UNITS; ++r ) begin
			for ( int c=0; c<NUM_UNITS; ++c ) begin
				EnOut[ c ][ r ]	= MapTab[ r ][ c ];
			end
		end
	end

	//	 Output Port-Map
	always_comb begin: c_port
		for ( int c=0; c<NUM_UNITS; ++c ) begin
			O_VldPort[ c ]	= ( |EnOut[ c ] ) & PortMap[ c ].Valid;
			if (  |MapTab[ c ] ) begin
				O_DstPort[ c ]	= PortMap[ c ].PDstID;
			end
			else begin
				O_DstPort[ c ]	= '0;
			end

			if ( |EnOut[ c ] ) begin
				O_SrcPort[ c ]	= PortMap[ c ].PSrcID;
			end
			else begin
				O_SrcPort[ c ]	= '0;
			end
		end
	end

	//	 Port-Map Table
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Reset_PortValid[ i ]	= PortMap[ i ].Valid & ( PortMap[ i ].PSrcID == CommitNo );
		end
	end

	Encoder	#(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_ResetNo
	(
		.I_Data(			Reset_PortValid				),
		.O_Enc(				Reset_PortValidNo			)
	);

	Encoder	#(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_CommitNo
	(
		.I_Data(			I_Commit					),
		.O_Enc(				CommitNo					)
	);

	always_ff @( posedge clock ) begin: ff_portmap
		if ( reset ) begin
			PortMap			<= '0;
		end
		else begin
			if ( |I_Commit ) begin
				// Commit then Invalidate the Entry
				PortMap[ Reset_PortValidNo ].Valid	<= 1'b0;
				PortMap[ Reset_PortValidNo ].PDstID	<= PortMap[ Reset_PortValidNo ].PDstID;
				PortMap[ Reset_PortValidNo ].PSrcID	<= PortMap[ Reset_PortValidNo ].PSrcID;
			end

			if ( I_Req ) begin
				// Request then Validate the Entry
				PortMap[ I_PDstID ].Valid	<= 1'b1;
				PortMap[ I_PSrcID ].PDstID	<= I_PDstID;
				PortMap[ I_PDstID ].PSrcID	<= I_PSrcID;
			end
		end
	end

endmodule