##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

class Type_Check:
    """
    type checker
    "line":     read one line
    "instr":    one instruction(instr) parsed from line
    """
    def is_func( self, line ):
        """
        Check This is Function
        """
        if line.find("define") >= 0:
            return True
        if line.find("entry") >= 0:
            return True
        return False

    def is_bblock( self, line ):
        """
        Check This is Basic-Block
        """
        if line.find(":") >= 0:
            return True
        return False

    def is_instr( self, instr ):
        """
        Check This is Instruction
        """
        return len(instr) > 1 and "}" not in instr

    def is_br( self, instr ):
        """
        Check This is Branch Instr
        """
        return "br" in instr and not "label" in instr[1]

    def is_jmp( self, instr ):
        """
        Check This is Jump Instr
        """
        return "br" in instr and "label" in instr[1]

    def is_switch( self, instr ):
        """
        Check This is Switch Instr
        """
        return "switch" in instr

    def is_cmp( self, instr ):
        """
        Check This is Compare Instr
        """
        return "icmp" not in instr and "fcmp" not in instr and "cmp" in instr

    def is_icmp( self, instr ):
        """
        Check This is Int-Compare Instr
        """
        return "icmp" in instr

    def is_fcmp( self, instr ):
        """
        Check This is Float-Compare Instr
        """
        return "fcmp" in instr

    def is_load( self, instr ):
        """
        Check This is Load Instr
        """
        return "load" in instr

    def is_store( self, instr ):
        """
        Check This is Store Instr
        """
        return "store" in instr

    def is_call( self, instr ):
        """
        Check This is Call Instr
        """
        return "call" in instr

    def is_ret( self, instr ):
        """
        Check This is Return Instr
        """
        return "ret" in instr

    def is_trunc( self, instr ):
        """
        Check This is Int Trunc Instr
        """
        return "trunc" in instr

    def is_fptrunc( self, instr ):
        """
        Check This is Float Trunc Instr
        """
        return "fptrunc" in instr

    def is_sext( self, instr ):
        """
        Check This is Sign-Extension Instr
        """
        return "sext" in instr

    def is_fpext( self, instr ):
        """
        Check This is Float to Double Instr
        """
        return "fpext" in instr

    def is_sitofp( self, instr ):
        """
        Check This is Signed Int to Float Instr
        """
        return "sitofp" in instr

    def is_ptr( self, instr ):
        """
        Check Arg have Pointer
        """
        for a in instr:
            if "*" in a:
                return True
        return False

    def is_alloca( self, instr ):
        """
        Check This is Allocator
        """
        return "alloca" in instr

    def is_getelementptr( self, instr ):
        """
        Check This is Array Pointer
        """
        return "getelementptr" in instr

    def is_unreachable( self, instr ):
        """
        Check This is Unreachable Instr
        """
        return "unreachable" in instr
