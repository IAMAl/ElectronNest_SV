///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Token Decoder
//		Module Name:	TokenDec
//		Function:
//						Decoder for Tokens,
//						Generates
//							- Acquireent Token
//							- Release Token
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module TokenDec
		import	pkg_en::*;
(
	input	FTk_t					I_FTk,				//Data
	output	logic					O_acq_message,		//Acq Toen for Message
	output	logic					O_rls_message,		//Release Token for Message
	output	logic					O_acq_flagmsg,		//Acq Token for Flagment
	output	logic					O_rls_flagmsg		//Release Token for Flagment
);


	//// NOTE														////
	//	 Tokens for Flagment Message are not yet supported,
	//		all modules using the token assume that
	//		message token is valid

	//	 Message Acquirement
	assign O_acq_message	= I_FTk.v &  I_FTk.a & ~I_FTk.r;

	//	 Block Acquirement
	assign O_acq_flagmsg	= I_FTk.v &  I_FTk.a & ~I_FTk.r;

	//	 Message Release
	assign O_rls_message	= I_FTk.v &  I_FTk.a &  I_FTk.r;

	//	 Block Release
	assign O_rls_flagmsg	= I_FTk.v & ~I_FTk.a &  I_FTk.r;

endmodule
