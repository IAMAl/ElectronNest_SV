///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	ID Rename Unit
//	Module Name:	RenameUnit
//	Function:
//					used for Virtualizing Number of Global Buffers
//					Rename Architectural ID to Physical ID
//					Map between Architectural ID and Physical ID
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module RenameUnit
	import pkg_bram_if::*;
(
	input							clock,
	input							reset,
	input							I_Req,				//Request from Decoder
	input							I_WAR_NEn,			//WAR-Hazard Disable
	input	adst_id_t				I_ADstID,			//Architecture Dst-ID
	input	asrc_id_t				I_ASrcID,			//Architecture Src-ID
	output	pdst_id_t				O_PDstID,			//Physical Dst-ID
	output	psrc_id_t				O_PSrcID,			//Physical Src-ID
	output	logic					O_Req,				//Flag: Request to Port-Map
	input							I_Rls,				//Flag: Release
	input	[NUM_UNITS-1:0]			I_Commit,			//Flag: Commit from Reorder Buffer
	output	logic					O_Full,				//Flag: Fully Used
	output	logic					O_Empty,			//Flag: Not Used
	output	logic					O_Error,			//Flag: Error to Rename SrcID
	output	logic					O_Hazard			//Flag: Hazard (Port-Dependency)
);

	// Weaker Tournament
	parameter int MAX_NO		= {1'b1, 4'hb};


	//// Logic Connect												////
	logic						Issue_Request;

	logic	[NUM_UNITS-1:0]		W_Req;
	logic	[WIDTH_UNITS-1:0]	GrantNo;

	//	 Validation Flag
	logic						Valid;

	//	 Status for Table
	logic						Empty;
	logic						Full;

	//	 Detection of Most Recently Used Table Entry
	logic	[WIDTH_UNITS:0]		Entry		[NUM_UNITS-1:0];
	logic	[NUM_UNITS-1:0]		T_Valid;
	logic	[WIDTH_PID:0]		MaxCount_Val;
	logic	[WIDTH_PID:0]		MR_TabNo;

	//	 Detection of Least Recently Used Table Entry
	logic	[WIDTH_UNITS:0]		WeakEntry	[NUM_UNITS-1:0];

	//	 Physical ID
	pdst_id_t					PDstID;
	psrc_id_t					PSrcID;

	pdst_id_t					Rls_PDStID;
	pdst_id_t					Acq_PDStID;

	//	 Physical ID for BRAM (renaming)
	logic	[NUM_UNITS-1:0]		Avail_BRAM_PDst;
	pdst_id_t					BRAM_PDstID;

	//	 Table Availability for Physical ID
	logic	[WIDTH_UNITS:0]		CNTDiff		[NUM_UNITS-1:0];
	logic	[NUM_UNITS-1:0]		RN_Tab_Full;
	logic	[NUM_UNITS-1:0]		RN_Tab_Empty;

	//	 Commit Number Generation
	logic	[WIDTH_UNITS-1:0]	Commit_No;
	logic	[WIDTH_UNITS:0]		Oldest_No;

	//	 Release Table Number Generation
	logic	[NUM_UNITS-1:0]		Rls_Flags;
	logic	[WIDTH_UNITS-1:0]	Rls_No;

	//	 Hazard (Conflict) Detection
	logic	[NUM_UNITS-1:0]		Check_Hazard;
	logic	[NUM_UNITS-1:0]		Wait_Src;
	logic	[NUM_UNITS-1:0]		Port_Conflict;
	logic	[NUM_UNITS-1:0]		Src_Port_Conflict;
	logic	[NUM_UNITS-1:0]		Dst_Port_Conflict;

	logic						RAR_Hazard;
	logic						RAW_Hazard;
	logic						WAR_Hazard;
	logic						WAW_Hazard;
	logic						Hazard;

	//	 Header Number Generation
	logic	[WIDTH_UNITS-1:0]	Header_Val;
	logic	[WIDTH_UNITS-1:0]	Header;

	//	 Enable to REname for BRAM
	logic						EnRenameDst;
	logic						EnRenameSrc;

	//	 Wait until Available GrantNo Entry in Table
	logic						Recover_Wait;

	//	 Write-Enable for Table
	logic						WeTab;

	//	 LRU Number
	logic	[WIDTH_UNITS-1:0]	MaxCount_TabNo;

	//
	logic						Wait_Term;

	logic						NotAvail_BRAM;

	logic						Clr_Entry;


	//// Capture Signal												////
	//	 Request to PortMap Unit
	logic						R_Req;

	logic	[WIDTH_UNITS-1:0]	R_WCNTPtr	[NUM_UNITS-1:0];
	logic	[WIDTH_UNITS-1:0]	R_RCNTPtr	[NUM_UNITS-1:0];

	//	 Validation of Rename Table Entry
	logic	[NUM_UNITS-1:0]		R_Valid;

	//	 Rename Table
	logic	[NUM_UNITS-1:0]		RNameVld;
	RenameTab_t					RNameTab;

	//	 Grant Number
	logic	[WIDTH_UNITS-1:0]	R_GrantNo;

	//	 Architecture ID
	adst_id_t					R_ADstID;

	//	 Physical ID
	pdst_id_t					R_PDstID;
	psrc_id_t					R_PSrcID;

	//	 BRAM Flags in Use
	pdst_id_t					R_BRAM_Use;

	//	 Validation for Physical Source ID
	logic						R_PSrcVld;

	//	 Hazard
	logic						R_RAR_Hazard;
	logic						R_RAW_Hazard;
	logic						R_WAR_Hazard;
	logic						R_WAW_Hazard;

	logic						R_RAR_HazardD1;
	logic						R_RAW_HazardD1;
	logic						R_WAR_HazardD1;
	logic						R_WAW_HazardD1;

	//	 Recovery from Hazard
	logic						R_Recover_Wait;
	logic	[WIDTH_UNITS-1:0]	R_Wait_PDstID;
	logic	[WIDTH_UNITS-1:0]	R_Wait_PSrcID;

	//	 LRU Number
	logic	[WIDTH_UNITS-1:0]	R_MaxCount_TabNo;

	//
	logic						R_Wait_Term;
	logic						R_GrantNo_Stored;

	//	 Not-Enable WAR Harzard Assertion
	logic						R_WAR_NEn;


	//// Check Request to PortMap Unit								////
	//	 Issue Request
	assign Issue_Request	= I_Req | Recover_Wait;

	//	 Enable Rename Dst-ID
	assign EnRenameDst		= ( I_ADstID > ID_OFFSET_CTRL ) & ( I_ADstID < ID_OFFSET_IFLOGIC );

	//	 Enable Rename Src-ID
	assign EnRenameSrc		= ( I_ASrcID > ID_OFFSET_CTRL ) & ( I_ASrcID < ID_OFFSET_IFLOGIC );

	//	 Recovering from Hazard
	//		Used for Issueing Request
	assign Recover_Wait		= ( ~R_RAR_Hazard & R_RAR_HazardD1 ) |
								( ~R_RAW_Hazard & R_RAW_HazardD1 ) |
								( ~R_WAR_Hazard & R_WAR_HazardD1 ) |
								( ~R_WAW_Hazard & R_WAW_HazardD1 );


    //// Output                                                     ////
	//	 Physical Dst-ID
    assign O_PDstID			= ( R_Recover_Wait ) ?	R_Wait_PDstID :
								( EnRenameDst ) ?	R_PDstID :
													R_ADstID;

	//	 Physical Src-ID
    assign O_PSrcID         = ( R_Recover_Wait ) ?	R_Wait_PSrcID :
													R_PSrcID;

	//	 Request to PortMap Unit
	assign O_Req			= R_Req & ~Hazard & R_PSrcVld;

	//	 Status
	//		Full Use of MapTab
	assign O_Full			= Full;

	//		Full Empty of MapTab
	assign O_Empty			= Empty;

	//		Error for Reanaming of Src-ID
	assign O_Error			= R_Recover_Wait & ~R_PSrcVld;

	//		Hazard
	assign O_Hazard			= Hazard;

	//	 Priority Encoder
	//		Select One Empty Entry
	assign W_Req			= ( Issue_Request ) ? ~R_Valid : '0;
	assign WeTab			= Valid & ~RNameVld[ GrantNo ] & ( EnRenameDst | ~RN_Tab_Full[ GrantNo ] ) & ~R_Recover_Wait;

	assign Rls_PDStID		= RNameTab[ Rls_No ].PDstID - 1'b1;
	assign Acq_PDStID		= PDstID - 1'b1;


	//// Physical Destination ID									////
	assign PDstID			= ( Recover_Wait ) ?					R_Wait_PDstID :
								( EnRenameDst & NotAvail_BRAM) ?	BRAM_PDstID + 1'b1 :
																	I_ADstID;


	//// Physical Source ID											////
	assign PSrcID			= ( |T_Valid ) ? (
									( RNameTab[ MaxCount_TabNo ].PDstID < ID_OFFSET_IFLOGIC ) ?	RNameTab[ MaxCount_TabNo ].PDstID :
																								I_ASrcID
											) : I_ASrcID;

	assign NotAvail_BRAM		= R_BRAM_Use[ I_ADstID-1 ];


	//// Header (Most Recentry Used Entry for I_ASrcID)				////
	//	 Clear Header in RNameTab[GrantNo]
	assign Clr_Entry		= Valid & ( I_ASrcID != RNameTab[ GrantNo ].ADstID );

	//	 How Many Entries are Busy for PDstID
    assign Header_Val		= ( CNTDiff[ PDstID ] ) ?	CNTDiff[ PDstID ] + NUM_UNITS :
														CNTDiff[ PDstID ];

	assign Header			= ( Clr_Entry ) ?						'0 :
								( Header_Val == (NUM_UNITS-1) ) ?	'0 :
																	Header_Val + 1'b1;
	assign Avail_BRAM_PDst	= ( EnRenameDst ) ? ~R_BRAM_Use : '0;

	assign RAR_Hazard		= ( |Port_Conflict ) & ~Empty & I_Req;
	assign RAW_Hazard		= ( |Wait_Src ) & ~Empty & I_Req;
	assign WAR_Hazard		= ( |Src_Port_Conflict ) & ~Empty & I_Req;
	assign WAW_Hazard		= ( |Dst_Port_Conflict ) & ~Empty & I_Req;

	//	 Hazard Detection
	assign Hazard		= R_RAR_Hazard | R_RAW_Hazard | R_WAR_Hazard | R_WAW_Hazard;


	//// Disable WAR-Hazard										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_WAR_NEn		<= 1'b0;
		end
		else if ( I_Rls | ( WAR_Hazard & ~EnRenameDst ) ) begin
			R_WAR_NEn		<= 1'b0;
		end
		else if ( I_WAR_NEn ) begin
			R_WAR_NEn		<= 1'b1;
		end
	end


	//// Recovery from Hazard									////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Recover_Wait	<= 1'b0;
		end
		else if ( Recover_Wait ) begin
			R_Recover_Wait	<= 1'b0;
		end
		else if ( I_Req & ( RAR_Hazard | ( ( RAW_Hazard | WAR_Hazard ) & ~I_WAR_NEn ) | WAW_Hazard ) ) begin
			R_Recover_Wait	<= 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Wait_PDstID	<= '0;
			R_Wait_PSrcID	<= '0;
		end
		else if ( I_Req ) begin
			R_Wait_PDstID	<= PDstID;
			R_Wait_PSrcID	<= PSrcID;
		end
	end


	//// Hazard Detection											////
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Check_Hazard[ i ]		= I_Req & ~RNameTab[ i ].Dirty;
		end
	end

	//	 RAR Hazard Detection
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Port_Conflict[ i ]		= ( I_ASrcID == RNameTab[ i ].ASrcID ) & Check_Hazard[ i ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RAR_Hazard	<= 1'b0;
		end
		else if ( I_Rls ) begin
			R_RAR_Hazard	<= 1'b0;
		end
		else if ( RAR_Hazard ) begin
			R_RAR_Hazard	<= 1'b1;
		end
	end

	//	 RAW Hazard Detection
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Wait_Src[ i ]			= ( I_ASrcID == RNameTab[ i ].ADstID ) & Check_Hazard[ i ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RAW_Hazard	<= 1'b0;
		end
		else if ( I_Rls ) begin
			R_RAW_Hazard	<= 1'b0;
		end
		else if ( RAW_Hazard & ~R_WAR_NEn ) begin
			R_RAW_Hazard	<= 1'b1;
		end
	end

	//	 WAR Hazard Detection
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Src_Port_Conflict[ i ]	= ( I_ADstID == RNameTab[ i ].ASrcID ) & Check_Hazard[ i ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_WAR_Hazard	<= 1'b0;
		end
		else if ( I_Rls ) begin
			R_WAR_Hazard	<= 1'b0;
		end
		else if ( WAR_Hazard & ~EnRenameDst & ~R_WAR_NEn ) begin
			R_WAR_Hazard	<= 1'b1;
		end
	end

	//	 WAW Hazard Detection
	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Dst_Port_Conflict[ i ]	= ( I_ADstID == RNameTab[ i ].ADstID ) & Check_Hazard[ i ];
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_WAW_Hazard	<= 1'b0;
		end
		else if ( I_Rls ) begin
			R_WAW_Hazard	<= 1'b0;
		end
		else if ( WAW_Hazard & ~EnRenameDst ) begin
			R_WAW_Hazard	<= 1'b1;
		end
	end

	//	 Delay for Pulse Generation
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_RAR_HazardD1	<= 1'b0;
			R_RAW_HazardD1	<= 1'b0;
			R_WAR_HazardD1	<= 1'b0;
			R_WAW_HazardD1	<= 1'b0;
		end
		else begin
			R_RAR_HazardD1	<= R_RAR_Hazard;
			R_RAW_HazardD1	<= R_RAW_Hazard;
			R_WAR_HazardD1	<= R_WAR_Hazard;
			R_WAW_HazardD1	<= R_WAW_Hazard;
		end
	end


	//// Retiming Req Signal										////
	//	 Capture Request Signal
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Req			<= 1'b0;
		end
		else begin
			R_Req			<= Valid;
		end
	end


	//// Capture Grant No											////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_GrantNo		<= '0;
		end
		else if ( Valid ) begin
			R_GrantNo		<= GrantNo;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_GrantNo_Stored<= 1'b0;
		end
		else if ( Valid ) begin
			R_GrantNo_Stored<= 1'b1;
		end
		else if ( ~Wait_Term & ~R_Wait_Term ) begin
			R_GrantNo_Stored<= 1'b0;
		end
	end


	//// Capture Physical ID										////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_PSrcVld		<= 1'b0;
			R_ADstID		<= '0;
			R_PDstID		<= '0;
			R_PSrcID		<= '0;
		end
		else if ( Valid ) begin
			R_PSrcVld		<= 1'b1;
			R_ADstID		<= I_ADstID;
			R_PDstID		<= ( EnRenameDst ) ? PDstID : I_ADstID;
			R_PSrcID		<= ( EnRenameSrc ) ? PSrcID : I_ASrcID;
		end
		else if ( I_Rls ) begin
			R_PSrcVld		<= 1'b0;
			R_ADstID		<= '0;
			R_PDstID		<= '0;
			R_PSrcID		<= '0;
		end
	end


	//// Priority Encode											////
	//	 In-Use State Register
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Valid	<= '0;
		end
		else if ( I_Rls | Valid ) begin
			//	 Clear by Commit-signal from Reorder Buffer
			if ( I_Rls ) begin
				R_Valid[ Rls_No ]	<= 1'b0;
			end

			if ( Valid ) begin
				R_Valid[ GrantNo ]	<= 1'b1;
			end
		end
	end


	PriorityEnc #(
		.NUM_ENTRY(			NUM_UNITS					)
	) IDAlloc
	(
		.I_Req(				W_Req						),
		.O_Grt(				GrantNo						),
		.O_Vld(				Valid						)
	);

	//	 Rename Table Status
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			Full			<= 1'b0;
			Empty			<= 1'b0;
		end
		else begin
			Full			<=  ( &R_Valid );
			Empty			<= ~( |R_Valid );
		end
	end


    //// Rename Table RAM                                           ////
	always_ff @( posedge clock ) begin: ff_maptab
		if ( reset ) begin
			RNameTab		<= '0;
		end
		else begin
			if ( WeTab | I_Rls ) begin
				if ( WeTab & ~I_Rls ) begin
					// Request then Validate Table Entry
					RNameTab[ GrantNo ].PDstID	<= PDstID;
					RNameTab[ GrantNo ].PSrcID	<= PSrcID;
					RNameTab[ GrantNo ].ADstID	<= I_ADstID;
					RNameTab[ GrantNo ].ASrcID	<= I_ASrcID;
					RNameTab[ GrantNo ].Header	<= Header;
					RNameTab[ GrantNo ].Dirty	<= 1'b0;
				end
				else if ( WeTab & ( Rls_No == GrantNo ) & I_Rls ) begin
					// Request then Validate Table Entry
					RNameTab[ GrantNo ].PDstID	<= PDstID;
					RNameTab[ GrantNo ].PSrcID	<= PSrcID;
					RNameTab[ GrantNo ].ADstID	<= I_ADstID;
					RNameTab[ GrantNo ].ASrcID	<= I_ASrcID;
					RNameTab[ GrantNo ].Header	<= Header;
					RNameTab[ GrantNo ].Dirty	<= 1'b0;
				end
				else if ( I_Rls ) begin
					// Commit then Invalidate Table Entry
					RNameTab[ Rls_No ].Dirty	<= 1'b1;
				end
			end
		end
	end

	always_ff @( posedge clock ) begin: ff_maptabv
		if ( reset ) begin
			RNameVld		<= '0;
		end
		else begin
			if ( WeTab | I_Rls ) begin
				if ( WeTab & ~I_Rls ) begin
					// Request then Validate Table Entry
					RNameVld[ GrantNo ]			<= 1'b1;
				end
				else if ( WeTab & I_Rls ) begin
					// Request then Validate Table Entry
					RNameVld[ GrantNo ]			<= 1'b1;
				end
				else if ( ~Wait_Term & ~R_Wait_Term & R_GrantNo_Stored ) begin
					// After Wait for Termination of Grant Tab Entry
					RNameVld[ R_GrantNo ]		<= 1'b1;
				end
				else if ( I_Rls ) begin
					// Commit then Invalidate
					RNameVld[ Rls_No ]			<= 1'b0;
				end
			end
		end
	end


	//// Selection for Least Recentry Stored Entry                  ////
	//	 Generate Commit Entry Number
	Encoder #(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_CommitNo
	(
		.I_Data(			I_Commit					),
		.O_Enc(				Commit_No					)
	);

	//	 Least-Recently Stored Entry is released
	//		This is because the frontend supports an in-order execution
	//	 Packing for Tournament Source
	//		Least-significant bit makes a priority
	always_comb begin: c_comparator_array_weak
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			WeakEntry[ i ]	= ( I_Rls & ( Commit_No == RNameTab[ i ].PSrcID )) ? { 1'b0, RNameTab[ i ].Header } : MAX_NO;
		end
	end

    //   Tournament Unit
	TournamentW TournamentW (
		.I_Entry(			WeakEntry					),
		.O_Entry(			Oldest_No 					),
		.O_Valid(			Rls_Flags					)
	);


	//// Release Entry Number Encoder								////
	Encoder #(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_ReleaseNo
	(
		.I_Data(			Rls_Flags					),
		.O_Enc(				Rls_No						)
	);


	//// Selection for Most Recentry Stored Entry                   ////
	//	 Most-Recently Stored Entry is connected as a Source
	//		This is because the frontend supports an in-order execution
    //   Packing for Tournament Source
	//		Most-significant bit makes a priority
	always_comb begin: c_comparator_array_entry
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			Entry[ i ]		= { Valid & ( I_ASrcID == RNameTab[ i ].ADstID ) & RNameVld[ i ], RNameTab[ i ].Header };
		end
	end

    //   Tournament Unit
	TournamentL Tournament
	(
		.I_Entry(			Entry						),
		.O_Entry(			MaxCount_Val				),
		.O_Valid(			T_Valid						)
	);

	//	 Generate Least Recentry Used Tab Number for I_ASrcID
	Encoder #(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_MaxCounnt_TabNo
	(
		.I_Data(			T_Valid						),
		.O_Enc(				MaxCount_TabNo				)
	);

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_MaxCount_TabNo	<= '0;
		end
		else if ( Wait_Term ) begin
			R_MaxCount_TabNo	<= MaxCount_TabNo;
		end
	end


	//// Physical Destination ID									////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_BRAM_Use					<= '0;
		end
		else if ( Valid & EnRenameDst & ~Hazard ) begin
			R_BRAM_Use[ Acq_PDStID ]	<= 1'b1;
		end
		else if ( I_Rls & ~RNameTab[ Rls_No ].Dirty ) begin
			R_BRAM_Use[ Rls_PDStID ]	<= 1'b0;
		end
	end


	//// Wait for Terminating the RNameTab[MaxCount_TabNo]			////
	assign Wait_Term		= RNameVld[ MaxCount_TabNo ] & ~RNameTab[ MaxCount_TabNo ].Dirty;

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Wait_Term			<= 1'b0;
		end
		else if ( RNameVld[ R_MaxCount_TabNo ] & RNameTab[ R_MaxCount_TabNo ].Dirty ) begin
			R_Wait_Term			<= 1'b0;
		end
		else if ( Wait_Term ) begin
			R_Wait_Term			<= 1'b1;
		end
	end


	//// Pysical Source ID's Postfix Generation						////
	//	 Rename Map Status
	//		This is based on Ring-Buffer Implementation (Power of Two Entries)
    always_comb begin: c_stat_ring_ptr
        for ( int i=0; i<NUM_UNITS; ++i ) begin
			CNTDiff[ i ]		= R_WCNTPtr[ i ] - R_RCNTPtr[ i ];
        end
    end

	always_comb begin
		for ( int i=0; i<NUM_UNITS; ++i ) begin
			RN_Tab_Full[ i ]	= CNTDiff[ i ][WIDTH_UNITS];
			RN_Tab_Empty[ i ]	= CNTDiff[ i ] == '0;
		end
	end

	//	 Counters for Ring-Buffer Control
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<NUM_UNITS; ++i ) begin
				R_WCNTPtr[ i ]	<= '0;
			end
		end
		if ( Valid & ( R_WCNTPtr[ PDstID ] == (NUM_UNITS-1) ) ) begin
			R_WCNTPtr[ PDstID ] <= '0;
		end
		else if ( Valid ) begin
			R_WCNTPtr[ PDstID ]	<= R_WCNTPtr[ PDstID ] + 1'b1;
		end
	end

	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int i=0; i<NUM_UNITS; ++i ) begin
				R_RCNTPtr[ i ]	<= '0;
			end
		end
		else begin
			for ( int i=0; i<NUM_UNITS; ++i ) begin
				if ( I_Rls & ( R_RCNTPtr[ RNameTab[ Rls_No ].PDstID ] == (NUM_UNITS-1) ) ) begin
					R_RCNTPtr[ RNameTab[ Rls_No ].PDstID ]  <= '0;
				end
				else if  ( I_Rls ) begin
					R_RCNTPtr[ RNameTab[ Rls_No ].PDstID ]	<= R_RCNTPtr[ RNameTab[ Rls_No ].PDstID ] + 1'b1;
				end
			end
		end
	end


	PriorityEnc #(
		.NUM_ENTRY(			NUM_UNITS					)
	) Enc_BRAM_PDstID
	(
		.I_Req(				Avail_BRAM_PDst				),
		.O_Grt(				BRAM_PDstID					),
		.O_Vld(											)
	);

endmodule
