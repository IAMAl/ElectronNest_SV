///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Arbiter
//		Module Name:	Arbiter
//		Function:
//						Select One Grant from Multiple Requests
//						invalid is object having NUM_ENTRY x NUM_ENTRY primitives.
//						A half of primitives, triable region in the box is used.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module Arbiter
#(
	parameter int NUM_ENTRY			= 4
)(
	input							clock,
	input							reset,
	input	[NUM_ENTRY-1:0]			I_Req,							//Request
	input	[NUM_ENTRY-1:0]			I_Rls,							//Release (End of Work)
	output	[$clog2(NUM_ENTRY)-1:0]	O_Grt,							//Grant No.
	output	[NUM_ENTRY-1:0]		 	O_Vld							//Validation
);


	//// Grant Flag, Exclusive Assertion							////
	logic [NUM_ENTRY-1:0]		valid;


	//// Grant Detection											////
	//	 False-Active (so this has name of "in"-valid)
	logic [NUM_ENTRY-1:0]		invalid [NUM_ENTRY-1:0];


	//// Validation Detection										////
	//	 Checking that Grant does Already exist
	logic 						v_exist;


	//// Tournament Assignment										////
	//	 Priority: Youngest Number
	//	 Example (NUM_ENTRY = 5)
	//	 in_no	cn_no
	//		-	0	1	2	3	4
	//		0	f	f	f	f	f
	//		1	f	f	f	f	r0
	//		2	f	f	f	r1	f0
	//		3	f	f	r2	r1	f0
	//		4	f	r3	r2	r1	f0
	always_comb begin
		for ( int in_no = 0; in_no < NUM_ENTRY; ++in_no ) begin
			if ((NUM_ENTRY-1) != 0) begin
				for ( int cn_no = 0; cn_no < NUM_ENTRY; ++cn_no ) begin
					if ( in_no == 0 ) begin
						invalid[0][ cn_no ]			= 1'b0;
					end
					else begin
						if ( in_no < (NUM_ENTRY-cn_no) ) begin
							invalid[ in_no ][ cn_no ]	 = 1'b0;
						end
						else begin
							invalid[ in_no ][ cn_no ]	 = I_Req[ NUM_ENTRY-cn_no-1 ] & ~I_Rls[ NUM_ENTRY-cn_no-1 ];
						end
					end
				end
			end
			else begin
				invalid[ in_no ][0]	= 1'b0;
			end
		end
	end


	//// Validation													////
	//	 valid is one-hot encoded value
	assign v_exist			= ( valid != '0 );
	assign O_Vld			= valid;
	always_ff @( posedge clock ) begin
		if ( reset ) begin
				valid <= 0;
		end
		else begin
			for ( int in_no = 0; in_no < NUM_ENTRY; ++in_no ) begin
				if  ( v_exist &  I_Rls[ in_no ] ) begin
					valid[ in_no ]	<= 1'b0;
				end
				else if  ( ~v_exist & I_Req[ in_no ] & ~I_Rls[ in_no ] & ( invalid[ in_no ] == '0 ) ) begin
					valid[ in_no ]	<= 1'b1;
				end
			end
		end
	end


	//// Output Grant												////
	//	 valid is one-hot encoded but we use encoder for
	//	 safely generating a number
	Encoder #(
		.NUM_ENTRY(			NUM_ENTRY					)
	) Arbit_Enc
	(
		.I_Data(			valid						),
		.O_Enc(				O_Grt						)
	);

endmodule
