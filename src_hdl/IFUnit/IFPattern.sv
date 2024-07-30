///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Interface Access Patter Detection
//	Module Name:	IFPattern
//	Function:
//					Detecting Connection Pattern to decide;
//						- Destination or source unit can get configuration data
//						- if SelDst is high then destination unit gets
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IFPattern
	import pkg_bram_if::*;
(
	input	[WIDTH_PID-1:0]			I_PDstID,			//Physical Destination-Index
	input	[WIDTH_PID-1:0]			I_PSrcID,			//Physical Source-Index
	output	logic					O_SelDst			//Destination-Select
);

	//// Logic Connect												////
	logic						is_DstFrontend;
	logic						is_DstBuffer;
	logic						is_DstIFLogic;
	logic						is_DstExtMemIF;
	logic						is_SrcFrontend;
	logic						is_SrcBuffer;
	logic						is_SrcIFLogic;
	logic						is_SrcExtMemIF;

	assign is_DstFrontend	= ( I_PDstID >= ID_OFFSET_CTRL )	& ( I_PDstID < ID_OFFSET_BRAM );
	assign is_DstBuffer		= ( I_PDstID >= ID_OFFSET_BRAM )	& ( I_PDstID < ID_OFFSET_IFLOGIC );
	assign is_DstIFLogic	= ( I_PDstID >= ID_OFFSET_IFLOGIC )	& ( I_PDstID < ID_OFFSET_IFEXTRN );
	assign is_DstExtMemIF	= ( I_PDstID >= ID_OFFSET_IFEXTRN )	& ( I_PDstID < NUM_UNITS );
	assign is_SrcFrontend	= ( I_PSrcID >= ID_OFFSET_CTRL )	& ( I_PSrcID < ID_OFFSET_BRAM );
	assign is_SrcBuffer		= ( I_PSrcID >= ID_OFFSET_BRAM )	& ( I_PSrcID < ID_OFFSET_IFLOGIC );
	assign is_SrcIFLogic	= ( I_PSrcID >= ID_OFFSET_IFLOGIC )	& ( I_PSrcID < ID_OFFSET_IFEXTRN );
	assign is_SrcExtMemIF	= ( I_PSrcID >= ID_OFFSET_IFEXTRN )	& ( I_PSrcID < NUM_UNITS );

	assign O_SelDst			= ( is_DstFrontend & is_SrcBuffer ) |
								( is_DstFrontend & is_SrcIFLogic ) |
								( is_DstFrontend & is_SrcExtMemIF ) |
								( is_DstBuffer & is_SrcBuffer ) |
								( is_DstBuffer & is_SrcIFLogic ) |
								( is_DstBuffer & is_SrcExtMemIF ) |
								( is_DstExtMemIF & is_SrcBuffer ) |
								( is_DstExtMemIF & is_SrcIFLogic ) |
								( is_DstIFLogic & is_SrcBuffer ) |
								( is_DstIFLogic & is_SrcExtMemIF );

endmodule