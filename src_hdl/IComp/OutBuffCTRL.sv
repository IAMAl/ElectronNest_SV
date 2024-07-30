///////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ElectronNest
//	Copyright (C) 2024  Shigeyuki TAKANO
//
//  GNU AFFERO GENERAL PUBLIC LICENSE
//	version 3.0
//
//	Control for Output Buffer
//	Module Name:	OutBuffCTRL
//	Function:
//					Control for Output Buffer in Datapath
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module OutBuffCTRL
import pkg_en::*;
import pkg_extend_index::*;
#(
parameter int SIZE_OUT_BUFF		= 5,
parameter int LOG_SIZE_BUFF		= $clog2(SIZE_OUT_BUFF)
)(
input							clock,
input							reset,
input							I_Active,			//Activate Module
input							I_Clr,				//Flag: Clear Buffer Control
input							I_Nack,				//Nack Token
input							I_Re,				//Read Enable
input							I_We,				//Write Enable
output	[LOG_SIZE_BUFF-1:0]		O_PtrHead,			//Pointer of Head
output	[LOG_SIZE_BUFF-1:0]		O_PtrTail,			//Pointer of Tail
output	logic					O_Full,				//Flag: Full
output	logic					O_Empty,			//Flag: Empty
output	logic					O_Ready				//Flag: Ready
);


//// Pointers													////
logic [LOG_SIZE_BUFF-1:0]	PtrHead;
logic [LOG_SIZE_BUFF-1:0]	PtrTail;


//// State Flag													////
logic						Full;
logic						Empty;
logic						Ready;

//// Read-Enable												////
logic						Re;


//// Output														////
//	 Pointers
assign O_PtrHead		= PtrHead;
assign O_PtrTail		= PtrTail;

//	 Buffer State Flags
//	 Full State
assign O_Full			= Full;

//	 Empty
assign O_Empty			= Empty;

//	 Ready
assign Ready			= ~Empty & ~Full;
assign O_Ready			= Ready | ( Empty & I_Active );


//// Ring Buffer Controller										////
//	 Read-Enable
//		NOTE: I_Nack should NOT a retimed signal
assign Re				= I_Re & ~I_Nack & I_Active;

OutputBuffCTRL #(
	.NUM_ENTRY(				SIZE_OUT_BUFF				)
) OutputBuffCTRL
(
	.clock(					clock						),
	.reset(					reset						),
	.I_Clr(					I_Clr						),
	.I_We(					I_We						),
	.I_Re(					Re							),
	.O_WAddr(				PtrHead						),
	.O_RAddr(				PtrTail						),
	.O_Full(				Full						),
	.O_Empty(				Empty						)
);

endmodule
