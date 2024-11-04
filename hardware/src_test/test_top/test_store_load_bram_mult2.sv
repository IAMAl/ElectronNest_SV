/*
    ElectronNest
    Copyright (C) 2023  Shigeyuki TAKANO

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module test_store_load_bram
import pkg_en::*;
;
	//// Testbench													////
	//		X-Y Routing
	//		Program File:	test_mem_routing_base.txt
	//
	//		Testing a Routing for Routing Data Compression.
	//		Baseline LinkOut router always feeds single routing data word.
	//		This makes redundant routing data block.
	//		The Routing Data Compression aims to compress routing data for
	//		contiguous same routing directinos.
	//		Attribute Word for routing includes a length (counter) to
	//		take following direction.
	//		This feature can make X-Y routing based on a hop-count.


	//// Base Time Ticks											////
	parameter HALF_CYCLE 		= 5;
	parameter SINGLE_CYCLE		= HALF_CYCLE*2;
	parameter START_CYCLE		= SINGLE_CYCLE*10;
	parameter BOOT_CYCLE		= SINGLE_CYCLE*10;
	parameter END_CYCLE			= SINGLE_CYCLE*10000;


	//// Base Object												////
	logic						clock;
	logic						reset;
	logic						Boot;
	logic [3:0]					BootCnt;


	//// External Memory											////
	logic	[WIDTH_DATA-1:0]	mem	[1024:0];


	//// Load														////
	wire						Ld_Req;
	wire	[WIDTH_EXADDR-1:0]	Ld_Addr;
            FTk_t				Ld_FTk;
            BTk_t				Ld_BTk;


	//// Store														////
	wire						St_Req;
	wire	[WIDTH_EXADDR-1:0]	St_Addr;
	        FTk_t				St_FTk;
	        BTk_t				St_BTk;


	//// Running Program (Hexadecimal 32-bit Format)				////
	initial $readmemh( "path_to_test/test_memory/test_mem_store_load_bram_mult2.txt", mem );


	//// Simulation Timeline Control								////
	initial begin
		// Init Control Signals
		clock	= 1'b1;
		reset	= 1'b0;
		Boot	= 1'b0;
		BootCnt	= 0;

		// Reset
		#START_CYCLE;
		reset	= 1'b1;

		#SINGLE_CYCLE;
		reset	= 1'b0;

		// System Boot
		#BOOT_CYCLE;
		Boot	= 1'b1;

		// End of Simulation
		#END_CYCLE $finish;
	end


	//// Run Body													////
	always @( posedge clock ) begin
		// Boot Sequence
		if ( Boot == 1 ) begin
			`ifdef EXTEND_MEM
			// Case of with Index-Compression
			if ( BootCnt < 3 ) begin
				Ld_FTk.v	<= 1'b1;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= '0;
			end
			else if ( BootCnt < 8 ) begin
				Ld_FTk.v	<= 1'b1;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= mem[	BootCnt - 3	];
			end
			else begin
				Ld_FTk.v	<= 1'b0;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= mem[	BootCnt - 3	];
			end
			`else
			// Case of without Index-Compression
			if ( BootCnt < 3 ) begin
				Ld_FTk.v	<= 1'b1;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= '0;
			end
			else if ( BootCnt < 8 ) begin
				Ld_FTk.v	<= 1'b1;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= mem[	BootCnt - 3	];
			end
			else begin
				Ld_FTk.v	<= 1'b0;
				Ld_FTk.i	<= '0;
				Ld_FTk.d	<= mem[	BootCnt - 3	];
			end
			`endif

			// First Word needs to assert "Acq" token
			if ( BootCnt == 0 ) begin
				Ld_FTk.a	<= 1'b1;
			end
			else begin
				Ld_FTk.a	<= 1'b0;
			end

			if ( BootCnt > 8 ) begin
				Boot		<= 1'b0;
			end
			Ld_FTk.r	<= 1'b0;
			Ld_FTk.c	<= 1'b0;

			// Counter for Boot Signal Assertion
			BootCnt		<= BootCnt + 1;
		end
		`ifdef EXTEND_MEM
		// Case of with Index-Compression
		else if ( Ld_Req ) begin
			Ld_FTk.v	<= 1'b1;
			Ld_FTk.a	<= 1'b0;
			Ld_FTk.r	<= 1'b0;
			Ld_FTk.c	<= 1'b0;
			Ld_FTk.i	<= Ld_Addr;
			Ld_FTk.d	<= mem[	Ld_Addr	];
		end
		else begin
			Ld_FTk.v	<= 1'b0;
			Ld_FTk.a	<= 1'b0;
			Ld_FTk.r	<= 1'b0;
			Ld_FTk.c	<= 1'b0;
			Ld_FTk.i	<= Ld_Addr;
			Ld_FTk.d	<= mem[	Ld_Addr	];
		end
		`else
		// Case of without Index-Compression
		else if ( Ld_Req ) begin
			Ld_FTk.v	<= 1'b1;
			Ld_FTk.a	<= 1'b0;
			Ld_FTk.r	<= 1'b0;
			Ld_FTk.c	<= 1'b0;
			Ld_FTk.d	<= mem[	Ld_Addr	];
		end
		else begin
			Ld_FTk.v	<= 1'b0;
			Ld_FTk.a	<= 1'b0;
			Ld_FTk.r	<= 1'b0;
			Ld_FTk.c	<= 1'b0;
			Ld_FTk.d	<= mem[	Ld_Addr	];
		end
		`endif

		// Store in External Memory
		if ( St_Req & St_FTk.v & ~St_BTk.n ) begin
			// Store Result
			mem[ St_Addr ]	= St_FTk.d;
		end

		assign St_BTk		= '0;
	end


	//// Clock Generation											////
	always #HALF_CYCLE	clock = ~clock;


	//// Test Module												////
	ElectronNest EN
	(
		.clock(				clock		),
		.reset(				reset		),
		.I_Boot(			Boot		),
		.O_Ld_Req(			Ld_Req		),
		.O_Ld_Addr(			Ld_Addr		),
		.I_Ld_FTk(			Ld_FTk		),
		.O_Ld_BTk(			Ld_BTk		),
		.O_St_Req(			St_Req		),
		.O_St_Addr(			St_Addr		),
		.O_St_FTk(			St_FTk		),
		.I_St_BTk(			St_BTk		)
	);

endmodule