///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Network-on-Chip Router
//	Module Name:	FanIn_Link
//	Function:
//					Router to Output
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanIn_Link
	import	pkg_en::*;
#(
	parameter int WIDTH_DATA		= 32,
	parameter int NUM_LINK			= 4,
	parameter int NUM_CHANNEL		= 1,
	parameter int MEM_IF			= 0,
	parameter type TYPE_FTK			= FTk_cl_t,
	parameter type TYPE_BTK			= BTk_cl_t,
	parameter type TYPE_FTKM		= FTk_cl_t,
	parameter type TYPE_BTKM		= BTk_cl_t,
	parameter type TYPE_DATA		= data_lc_t,
	parameter type TYPE_LOGN		= log_nlc_t,
	parameter type TYPE_BITS		= bit_lc_t,
	parameter type TYPE_O_FTK		= FTk_c_t,
	parameter type TYPE_I_BTK		= BTk_c_t,
	parameter int EN_CLR_DIRTY		= 1
)(
	input							clock,
	input							reset,
	input	TYPE_FTK				I_FTk,				//Forward Tokens
	output	TYPE_BTK				O_BTk,				//Back-Prop Tokens
	output	TYPE_O_FTK				O_FTk,				//Forward Tokens
	input	TYPE_I_BTK				I_BTk,				//Back-Prop Tokens
	input	bit2_c_t				I_InC				//Condition-Code Path
);

	TYPE_LOGN					FIFOs_GrtNo;
	TYPE_BITS					FIFOs_Req;
	TYPE_BITS					FIFOs_Trm;
	TYPE_BITS					FIFOs_Grt;
	TYPE_DATA					FIFOs_Next;

	TYPE_DATA					FIFOs_NextID;

	TYPE_BITS					FIFOs_WeId;
	TYPE_BITS					FIFOs_Cond;

	TYPE_FTKM					FIFOs_F_FTk;
	TYPE_BTKM					FIFOs_F_BTk;
	TYPE_FTKM					FIFOs_B_FTk;
	TYPE_BTKM					FIFOs_B_BTk;

	data_c_t					R_NextID_t;
	data_c_t					R_NextID_f;
	TYPE_DATA					FIFOs_NextID_t;
	TYPE_DATA					FIFOs_NextID_f;

	logic		[NUM_LINK-1:0]	Rls [NUM_CHANNEL-1:0];

	bit_c_t						DirtyBit;

	FTk_c_t						W_FTk;
	BTk_c_t						W_BTk;


	//// Dirty Bits													////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				if ( EN_CLR_DIRTY ) begin
					DirtyBit[ c ]	<= 1'b0;
				end
				else begin
					DirtyBit[ c ]	<= 1'b1;
				end
			end
		end
		else begin
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				if ( |Rls[ c ] & EN_CLR_DIRTY ) begin
					DirtyBit[ c ]	<= 1'b0;
				end
				else if ( FIFOs_Grt[ c ] & EN_CLR_DIRTY ) begin
					DirtyBit[ c ]	<= 1'b1;
				end
			end
		end
	end


	//// Collect Release Tokens										////
	always_comb begin
		for ( int l=0; l< NUM_LINK; ++l ) begin
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				Rls[ c ][ l ]		= FIFOs_Grt[ c ][ l ] & O_FTk[ c ].a & O_FTk[ c ].r;
			end
		end
	end


	//// Arbiter for Selectig One FIFO								////
	for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin : g_linkin_arbit
		Arbiter #(
			.NUM_ENTRY(		NUM_LINK					)
		) Arbiter
		(
			.clock(			clock						),
			.reset(			reset						),
			.I_Req(			FIFOs_Req[ c ]				),
			.I_Rls(			FIFOs_Trm[ c ]				),
			.O_Grt(			FIFOs_GrtNo[ c ]			),
			.O_Vld(			FIFOs_Grt[ c ]				)
		);
	end


	//// Select ID by Condition Signal								////
	always_comb begin: c_sel_nex_id
		for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
			for ( int l = 0; l < NUM_LINK; ++l ) begin
				FIFOs_NextID[ c ][ l ] = ( FIFOs_Cond[ c ][ l ] ) ? R_NextID_t[ c ] : R_NextID_f[ c ];
			end
		end
	end


	//// Interconection												////
	for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin: g_net
		for ( genvar l = 0; l < NUM_LINK; ++l ) begin
			assign FIFOs_F_FTk[ l ][ c ]	= I_FTk[ l ][ c ];
			assign O_BTk[ l ][ c ]			= FIFOs_F_BTk[ l ][ c ];
		end
	end


	//// Capture IDs												////
	always_ff @( posedge clock ) begin: ff_next_id
		if ( reset ) begin
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				for ( int l = 0; l < NUM_LINK; ++l ) begin
					R_NextID_t[ c ]	<= '0;
					R_NextID_f[ c ]	<= '0;
				end
			end
		end
		else begin
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				for ( int l = 0; l < NUM_LINK; ++l ) begin
					if ( FIFOs_WeId[ c ][ l ] ) begin
						R_NextID_t[ c ]	<= FIFOs_NextID_t[ c ][ l ];
						R_NextID_f[ c ]	<= FIFOs_NextID_f[ c ][ l ];
					end
				end
			end
		end
	end


	//// Input FIFOs												////
	for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin : g_channel_in
		for ( genvar l = 0; l < NUM_LINK; ++l ) begin : g_link_in
			FanIn_FIFO #(
				.WIDTH_DATA(WIDTH_DATA					)
			) FIFOs
			(
				.clock(		clock						),
				.reset(		reset						),
				.I_FTk(		FIFOs_F_FTk[ l ][ c ]		),
				.O_BTk(		FIFOs_F_BTk[ l ][ c ]		),
				.O_FTk(		FIFOs_B_FTk[ l ][ c ]		),
				.I_BTk(		FIFOs_B_BTk[ l ][ c ]		),
				.O_Req(		FIFOs_Req[ c ][ l ]			),
				.O_Trm(		FIFOs_Trm[ c ][ l ]			),
				.I_Rls(		Rls[ c ][ l ]				),
				.I_Grt(		FIFOs_Grt[ c ][ l ]			),
				.I_Next(	FIFOs_NextID[ c ][ l ]		),
				.O_WeId(	FIFOs_WeId[ c ][ l ]		),
				.O_NextID_t(FIFOs_NextID_t[ c ][ l ]	),
				.O_NextID_f(FIFOs_NextID_f[ c ][ l ]	),
				.I_InC(		I_InC[ c ]					),
				.O_Cond(	FIFOs_Cond[ c ][ l ]		),
				.I_DirtyBit(DirtyBit[ c ]				)
			);
		end
	end


	//// Interconnect												////
	always_comb begin
		for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
			W_FTk[ c ]	= FIFOs_B_FTk[ FIFOs_GrtNo[ c ] ][ c ];
		end
	end

	always_comb begin
		for ( int l = 0; l < NUM_LINK; ++l ) begin : g_condlink
			for ( int c = 0; c < NUM_CHANNEL; ++c ) begin
				if ( l == FIFOs_GrtNo[ c ] ) begin
					FIFOs_B_BTk[ l ][ c ]	= W_BTk[ c ];
				end
				else begin
					FIFOs_B_BTk[ l ][ c ]	= '0;
				end
			end
		end
	end


	//// Output Register											////
	for ( genvar c = 0; c < NUM_CHANNEL; ++c ) begin : g_link_in_reg
		DReg FanInReg (
			.clock(			clock						),
			.reset(			reset						),
			.I_FTk(			W_FTk[ c ]					),
			.O_BTk(			W_BTk[ c ]					),
			.I_We(			1'b1						),
			.O_FTk(			O_FTk[ c ] 					),
			.I_BTk(			I_BTk[ c ]					)
		);
	end

endmodule
