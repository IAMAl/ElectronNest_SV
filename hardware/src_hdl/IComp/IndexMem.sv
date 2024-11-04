///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Index Memory
//	Module Name:	IndexMem
//	Function:
//					Memory Unit for Index Compression
//					The unit is used for extension; Index-Compression.
//					The unit stores indices when shared flag in Config Data is asseted.
//					The unit also runs at a retoring.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module IndexMem
	import	pkg_en::*;
	import	pkg_extend_index::*;
#(
	parameter int WIDTH_ADDR		= 8,
	parameter int WIDTH_INDEX		= 8
)(
	input							clock,
	input							reset,
	input							I_We,				//WriteEnable
	input							I_Re,				//Read-Enable
	input							I_Restore,			//Working in Restore-Phase
	input							is_Share,			//Flag: Sharing in Attrib Word
	input	[WIDTH_INDEX-1:0]		I_Index,			//Input Index
	input							I_St_End,			//Flag: End of Storing
	input							I_Ld_End,			//Flag: End of Loading
	output	[WIDTH_INDEX-1:0]		O_Index,			//Output Index
	output							O_Ld_End			//Flag: End of Loading
);


	//// Index Memory												////
	logic   [WIDTH_INDEX-1:0]	IndexMem [2**WIDTH_ADDR-1:0];


	//// Logic Connection											////
	logic						We;


	//// Capture Signal												////
	logic						R_Ld_End;
	logic						R_Rd_End;
	logic	[WIDTH_INDEX-1:0]	R_Index;

	//		Address
	logic   [WIDTH_ADDR-1:0]    R_AddrRead;
	logic   [WIDTH_ADDR-1:0]    R_AddrWrite;
	logic   [WIDTH_ADDR:0]    	R_AddrLast;


	//// Write Enable												////
	//	 If is_Share flag in R-Config Data is asserted then work
	assign We				= I_We & is_Share;


	//// Output														////
	assign O_Index			= R_Index;
	assign O_Ld_End			= R_Ld_End;


	//// End of Load												////
	//	 used for After Compression
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Ld_End		<= 1'b0;
		end
		else begin
			R_Ld_End		<= I_Re & ( R_AddrRead == R_AddrLast ) & ( R_AddrLast != '0 );
		end
	end


	//// End of Load used for Common Case							////
	always_ff @( posedge clock ) begin
		if ( reset ) begin
			R_Rd_End		<= 1'b0;
		end
		else begin
			R_Rd_End		<= 	I_Ld_End & I_Restore;
		end
	end


	//// Store Indices												////
	always_ff @( posedge clock ) begin
		if ( We ) begin
			IndexMem[ R_AddrWrite ]	<= I_Index;
		end
		else if ( I_We & ~is_Share ) begin
			IndexMem[ R_AddrWrite ]	<= R_AddrWrite;
		end
	end


	//// Read Index													////
	always_ff @( posedge clock ) begin: ff_index
		if ( reset ) begin
			R_Index			<= '0;
		end
		else if ( R_Ld_End & ~I_Restore ) begin
			R_Index			<= '0;
		end
		else if ( I_Re ) begin
			R_Index			<= IndexMem[ R_AddrRead ];
		end
	end


	//// Capture Last Write-Address									////
	//	 AddrLast is used to detect last reading
	//	 RConfig Data has acturel (non-compressed) length,
	//	 so we need to capture length for compression
	always_ff @( posedge clock ) begin: ff_last
		if ( reset ) begin
			R_AddrLast	<= '0;
		end
		else if ( I_Ld_End & I_Restore ) begin
			R_AddrLast		<= R_AddrWrite;
		end
	end


	//// Addresses													////
	//	 Restoring needs both of reading and writing in same time
	//	 Read Address
	always_ff @( posedge clock ) begin: ff_read
		if ( reset ) begin
			R_AddrRead		<= '0;
		end
		else if ( R_Rd_End ) begin
			R_AddrRead		<= '0;
		end
		else if ( I_Re ) begin
			R_AddrRead		<= R_AddrRead + 1'b1;
		end
		else if ( R_Ld_End & ~I_Restore ) begin
			R_AddrRead		<= '0;
		end
	end

	//	 Write Address
	always_ff @( posedge clock ) begin: ff_write
		if ( reset ) begin
			R_AddrWrite		<= '0;
		end
		else if ( I_St_End & I_Restore ) begin
			R_AddrWrite		<= '0;
		end
		else if ( I_We ) begin
			R_AddrWrite		<= R_AddrWrite + 1'b1;
		end
	end

endmodule