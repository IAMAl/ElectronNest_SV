///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	FanIn-Tree
//	Module Name:	FanInTree
//	Function:
//					Tournament for Memory Access Requests
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module FanInTree
	import pkg_en::*;
	import pkg_bram_if::*;
(
	input							clock,
	input							reset,
	input	FTk_iflgc_t				I_FTk,
	output	BTk_iflgc_t				O_BTk,
	output	FTk_t					O_FTk,
	input	BTk_t					I_BTk,
	input	FTk_extif_t				I_LdSt_FTk,
	output	BTk_extif_t				O_LdSt_BTk
);

	// Number of Inputs on a FanIn Link
	localparam int NUM_BASE			= 4;

	// Total Number of Inputs on This module
	localparam int NUM_ENTRY		= NUM_ELMS+NUM_EXT_IFS;

	// Number of FanIn Units at First-Level
	localparam int NUM_UNIT			= (NUM_ENTRY+NUM_BASE)/NUM_BASE;

	// Maximum Number of Ports on First-Level
	localparam int NUM_LOGIC		= NUM_BASE*NUM_UNIT;

	// Number of Levels
	localparam int NUM_LEVEL		= $clog2($clog2(NUM_LOGIC));

	// Maximum Number of Ports at first level
	localparam int NUM_MAX_PORT		= NUM_BASE**NUM_LEVEL;

	// Maximum Number of FanIn Units
	localparam int NUM_MAX_UNIT		= $rtoi($ceil((NUM_MAX_PORT-1)/(NUM_BASE-1)));

	// level = max_level - $clog2($clog2(units))
	function int num_max_units_level (
		input int base,
		input int level,
		input int max_level
	);
		// max_level > 0
		// max_level > level >=0
		num_max_units_level	= base**(max_level-level-1);
	endfunction

	function int num_units_level (
		input int base,
		input int level
	);
		// max_level > level >=0
		num_units_level	= (NUM_ENTRY+(base**(level+1)))/(base**(level+1));
	endfunction

	function int num_wasted_unit_level (
		input int base,
		input int level,
		input int max_level
	);
		// max_level > 0
		// max_level > level >= 0
		num_wasted_unit_level	= (num_max_units_level( base, level, max_level ) < num_units_level( base, level )) ? 0 : num_max_units_level( base, level, max_level )-num_units_level( base, level );
	endfunction

	function int num_wasted_units_fact (
		input int base,
		input int max_level
	);
		// max_level > 0
		automatic int units = 0;
		for ( int i=0; i<max_level; ++i ) begin
			units	+= num_wasted_unit_level( base, i, max_level );
		end
		num_wasted_units_fact = units;
	endfunction

	function int num_units_fact_level (
		input int base,
		input int level,
		input int max_level
	);
		// max_level > 0
		// max_level > level >= 0
		automatic int total_units = 0;
		for ( int i=0; i<(level+1); ++i ) begin
			total_units = total_units + num_units_level( base, i );
		end
		num_units_fact_level = total_units;
	endfunction

	function automatic int num_units_fact (
		input int base,
		input int max_level
	);
		// max_level > 0
		// max_level > level >= 0
		automatic int total_units = 0;
		for ( int i=0; i<max_level; ++i ) begin
			total_units += num_units_level( base, i );
		end
		num_units_fact = total_units;
	endfunction

	function int level (
		input int base,
		input int num_entry,
		input int unit_no
	);
		automatic int num_units = 0;
		for ( int i=0; i<NUM_LEVEL; ++i ) begin
			num_units = num_units + num_units_level( NUM_BASE, i );
			if ( unit_no < num_units ) begin
				return i;
			end
		end
		//num_entry=5, unit_no=0 < 2 -> i=0
		//num_entry=5, unit_no=1 < 2 -> i=0
		//num_entry=5, unit_no=2 < 3 -> i=1

		//num_entry=17,unit_no=0 < 5 -> i=0
		//num_entry=17,unit_no=1 < 5 -> i=0
		//num_entry=17,unit_no=2 < 5 -> i=0
		//num_entry=17,unit_no=3 < 5 -> i=0
		//num_entry=17,unit_no=4 < 5 -> i=0
		//num_entry=17,unit_no=5 < 7 -> i=1
		//num_entry=17,unit_no=6 < 7 -> i=1
		//num_entry=17,unit_no=7 < 8 -> i=2

		//num_entry=20,unit_no=0 < 6 -> i=0
		//num_entry=20,unit_no=1 < 6 -> i=0
		//num_entry=20,unit_no=2 < 6 -> i=0
		//num_entry=20,unit_no=3 < 6 -> i=0
		//num_entry=20,unit_no=4 < 6 -> i=0
		//num_entry=20,unit_no=5 < 6 -> i=0
		//num_entry=20,unit_no=6 < 8 -> i=1
		//num_entry=20,unit_no=7 < 8 -> i=1
		//num_entry=20,unit_no=8 < 9 -> i=2
		return 0;
	endfunction

	function int this_unit_no (
		input int base,
		input int port_no
	);
		this_unit_no = port_no / base;
	endfunction

	function int bottom_bound (
		input int base,
		input int num_entry,
		input int max_level,
		input int port_no
	);
		bottom_bound = base*(num_units_fact_level( base, level( base, num_entry, this_unit_no( base, port_no ) ), max_level )-1)-1;
	endfunction

	function int up_bound (
		input int base,
		input int num_entry,
		input int max_level,
		input int port_no
	);
		up_bound =  base*(num_units_fact_level( base, level( base, num_entry, this_unit_no( base, port_no ) ), max_level ));
	endfunction

	localparam int total_num_wasted_units	= num_wasted_units_fact( NUM_BASE, NUM_LEVEL );
	localparam int total_num_units			= num_units_fact( NUM_BASE, NUM_LEVEL );
	//OK: localparam int test1 = num_units_level( NUM_BASE, 0 );
	//OK: localparam int test2 = bottom_bound( NUM_BASE, NUM_ENTRY, NUM_LEVEL, 8 );
	//OK: localparam int test3 = up_bound( NUM_BASE, NUM_ENTRY, NUM_LEVEL, 8 );
	//OK: localparam int test4 = num_max_units_level( NUM_BASE, 0, NUM_LEVEL );
	//OK: localparam int test5 = level( NUM_BASE, NUM_ENTRY, 1 );
	//OK: localparam int test6 = this_unit_no( NUM_BASE, 6 );
	//OK: localparam int test7 = num_units_fact_level(NUM_BASE, level( NUM_BASE, NUM_ENTRY, 2 ), NUM_LEVEL);

	// Tornament Interconnect (logic)
	FTk_t	[NUM_BASE*total_num_units:0]	Tounament_FTk;
	BTk_t	[NUM_BASE*total_num_units:0]	Tounament_BTk;

	// I/O
	for ( genvar port_no=0; port_no<(NUM_BASE*total_num_units); ++port_no ) begin
		if ( port_no < NUM_ELMS ) begin
			assign Tounament_FTk[ port_no ]			= I_FTk[ port_no ];
			assign O_BTk[ port_no ]					= Tounament_BTk[ port_no ];
		end
		else if ( port_no < (NUM_ELMS+NUM_EXT_IFS) ) begin
			assign Tounament_FTk[ port_no ]			= I_LdSt_FTk[ port_no - NUM_ELMS ];
			assign O_LdSt_BTk[ port_no - NUM_ELMS ]	= Tounament_BTk[ port_no ];
		end
		else if (( port_no > (bottom_bound( NUM_BASE, NUM_ENTRY, NUM_LEVEL, port_no )+this_unit_no( NUM_BASE, port_no ))) & ( port_no < up_bound( NUM_BASE, NUM_ENTRY, NUM_LEVEL, port_no ) )) begin
			assign Tounament_FTk[ port_no ]			= '0;
			assign Tounament_BTk[ port_no ]			= '0;
		end
	end

	assign O_FTk	= Tounament_FTk[NUM_BASE*total_num_units];
	assign Tounament_BTk[NUM_BASE*total_num_units]	= I_BTk;


	//// Tree of FanIn Link											////
	for ( genvar unit_no=0; unit_no<total_num_units; ++unit_no ) begin
		FanIn_Link #(
			.WIDTH_DATA(	WIDTH_DATA					),
			.NUM_LINK(		NUM_LINK					),
			.NUM_CHANNEL(	1							),
			.MEM_IF(		0							),
			.TYPE_FTK(		FTk_cl_t					),
			.TYPE_BTK(		BTk_cl_t					),
			.TYPE_FTKM(		FTk_cl_t					),
			.TYPE_BTKM(		BTk_cl_t					),
			.TYPE_DATA(		data_lc_t					),
			.TYPE_LOGN(		log_nlc_t					),
			.TYPE_BITS(		bit_lc_t					),
			.TYPE_O_FTK(	FTk_c_t						),
			.TYPE_I_BTK(	BTk_c_t						),
			.EN_CLR_DIRTY(	1							)
		) FanInTreeNode
		(
			.clock(		clock											),
			.reset(		reset											),
			.I_FTk(		Tounament_FTk[(unit_no+1)*NUM_BASE-1:unit_no*NUM_BASE]		),
			.O_BTk(		Tounament_BTk[(unit_no+1)*NUM_BASE-1:unit_no*NUM_BASE]		),
			.O_FTk(		Tounament_FTk[NUM_BASE*num_units_fact_level(NUM_BASE, level( NUM_BASE, NUM_ENTRY, unit_no ), NUM_LEVEL)+(unit_no%num_units_level(NUM_BASE, level( NUM_BASE, NUM_ENTRY, unit_no )))] ),
			.I_BTk(		Tounament_BTk[NUM_BASE*num_units_fact_level(NUM_BASE, level( NUM_BASE, NUM_ENTRY, unit_no ), NUM_LEVEL)+(unit_no%num_units_level(NUM_BASE, level( NUM_BASE, NUM_ENTRY, unit_no )))] ),
			.I_InC(		'0												)
		);
	end

endmodule