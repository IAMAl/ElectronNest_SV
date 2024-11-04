##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.InstrTypeChecker as type
import utils.ProgConstructor as progconst
import copy

DEBUG = False
type_chk = type.Type_Check()

def instr_parser( instr ):
    """
    Instruction Parser
    """

    operands = []
    if type_chk.is_br(instr):
        # Conditional Branch Instruction
        """
        br i1 %6, label %7, label %32
        """
        instr_type = instr[0]
        dst = None
        d_type = None
        src_a = instr[2].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = instr[1]
        br_t = "label:<" + instr[4].replace(",", "").replace("%", "")+">"
        br_f = "label:<" + instr[6].replace(",", "").replace("%", "")+">"
        imm = False
        sw = False

    elif type_chk.is_jmp(instr):
        # Jump Instruction
        """
        br label %31
        """
        instr_type = "jmp"
        dst = None
        d_type = None
        src_a = None
        src_b = None
        func = None
        br_t = "label:<" + instr[2].replace("%", "")+">"
        br_f = "label:<" + instr[2].replace("%", "")+">"
        imm = False
        sw = False

    elif type_chk.is_switch(instr):
        # Switch Instruction
        """
        switch i32 %7, label %38 [
            i32 48, label %8
            i32 43, label %11
            i32 42, label %15
            i32 45, label %19
            i32 47, label %24
            i32 10, label %35
        ]
        """
        instr_type = instr[0]
        dst = instr[2].replace(",", "")
        d_type = instr[1]
        src_a = None
        src_b = None
        func = None
        br_t = None
        br_f = instr[4]
        imm = False
        sw = True

    elif type_chk.is_cmp(instr):
        # Integer Compare Instruction
        """
        %10 = cmp eq i32 %9, i32 %10
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = instr[4] + " " + instr[5].replace(",", "")
        src_b = instr[6] + " " + instr[7].replace(",", "")
        operands.append(src_a)
        operands.append(src_b)
        func = instr[3]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_icmp(instr):
        # Integer Immediate Compare Instruction
        """
        %10 = icmp eq i32 %9, 9
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = instr[5].replace(",", "")
        src_b = instr[6].replace(",", "")
        operands.append(src_a)
        operands.append(src_b)
        func = instr[3]
        br_t = None
        br_f = None
        imm = True
        sw = False

    elif type_chk.is_fcmp(instr):
        # Float Compare Instruction
        """
        %27 = fcmp une double %26, 0.000000e+00
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = instr[4]
        src_a = instr[5].replace(",", "")
        src_b = instr[6].replace(",", "")
        operands.append(src_a)
        operands.append(src_b)
        func = instr[3]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_load(instr):
        # Load Instruction
        """
        %38 = load i32, i32* %2, align 4
        %8 = load i8* %c, align 1
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = instr[3].replace(",", "")
        if len(instr) > 6:
            src_a = instr[5].replace(",", "")
        else:
            src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = instr[5:6]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_store(instr):
        # Store Instruction
        """
        store i32 0, i32* %1
        """
        instr_type = instr[0]
        dst = None
        d_type = instr[3]
        src_a = instr[2].replace(",", "")
        src_b = instr[4].replace(",", "")
        operands.append(src_a)
        operands.append(src_b)
        func = None
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_call(instr):
        # Call Instruction
        if "call" == instr[0]:
            # Return is void
            """
            call void @push(double %10)
            """
            instr_type = instr[0]
            dst = instr[0].replace(",", "")
            d_type = instr[2].split("(")[1]
            src_a = instr[3].replace(")", "")
            src_b = None
            operands.append(src_a)
            func = instr[2].split("(")[0]
            br_t = None
            br_f = None
            imm = False
            sw = False
        else:
            # Return have some Value
            """
            %3  = call i32 @getchar()
            %21 = call double @pop()
            %49 = call i32 @putchar(i32 %48)
            %33 = call i32 (i8*, ...)*..., double %18, double %20)
            %2  = call i32 @squeeze(i8* getelementptr inbounds ([7 x i8]* @test, i32 0, i32 0)
            %75 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([5 x i8]* @.str, i32 0, i32 0), i32 %74)
            """
            instr_type = instr[2]
            dst = instr[0].replace(",", "")
            d_type = instr[3]
            if 18 < len(instr) and "%" in instr[4:]:
                src_a = instr[18].replace(",", "")
                src_b = instr[20].replace(")", "")
                operands.append(src_a)
                operands.append(src_b)

            elif 18 <= len(instr):
                src_a = instr[18].replace(",", "").replace(")", "")
                src_b = None
                operands.append(src_a)

            elif "@squeeze" in instr[4]:
                src_a = instr[12].replace(",", "").replace(")", "")
                src_b = instr[14].replace(",", "").replace(")", "")
                operands.append(src_a)
                operands.append(src_b)

            elif 6 == len(instr):
                src_a = instr[5].replace(",", "").replace(")", "")
                src_b = None
                operands.append(src_a)

            else:
                src_a = None
                src_b = None

            func = instr[4].replace("(", "").replace(",", "")
            br_t = instr[4].replace("(", "").replace(",", "")
            if "@" in instr[4]:
                func = instr[4]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_ret(instr):
        # Return Instruction
        """
        ret i32 0
        ret void
        ret i32 %27
        """
        instr_type = instr[0]
        dst = None
        if (len(instr) == 3):
            d_type = instr[1]
            src_a = instr[2].replace(",", "")
            operands.append(src_a)
        else:
            d_type = instr[1]
            src_a = None
            src_b = None
        func = None
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_trunc(instr):
        # Truncation (Int)
        """
        %4 = trunc i32 %3 to i8
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = instr[6]
        src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = None
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_fptrunc(instr):
        # Truncation (FP)
        """
        %16 = fptrunc double %15 to float
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = instr[6]
        src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = None
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_sext(instr):
        # Sign Extension (Int)
        """
        %27 = sext i8 %26 to i32
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = instr[3].replace(",", "") + " to " + instr[6].replace(",", "")
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_fpext(instr):
        # Precision-Extend
        """
        %13 = fpext float %12 to double
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = instr[3].replace(",", "") + " to " + instr[6].replace(",", "")
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_sitofp(instr):
        # Signed Int to FP
        """
        %3 = sitofp i32 %2 to float
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = instr[4].replace(",", "")
        src_b = None
        operands.append(src_a)
        func = instr[3].replace(",", "") + " to " + instr[6].replace(",", "")
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_alloca(instr):
        # Memory Allocation
        """
        %1 = alloca i32, align 4
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        d_type = None
        src_a = None
        src_b = None
        func = instr[3].replace(",", "") + " " + instr[4] + " " + instr[5]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_getelementptr(instr):
        # Pointer
        """
        %18 = getelementptr inbounds [256 x [256 x i32]], [256 x [256 x i32]]* @A, i64 0, i64 %17
        %30 = getelementptr inbounds [256 x i32], [256 x i32]* @C, i64 0, i64 %29
        %21 = getelementptr inbounds [256 x i32], [256 x i32]* %18, i64 0, i64 %20
        %3 = getelementptr inbounds [100 x i8]* %s, i32 0, i32 0
        %82 = getelementptr inbounds [10 x i32]* %ndigit, i32 0, i64 %81
        %46 = getelementptr inbounds i8* %45, i64 %4
        %7 = getelementptr inbounds i8* %6, i64 0
        """
        instr_type = instr[2]
        dst = instr[0].replace(",", "")
        if len(instr) == 19:
            d_type = instr[8].replace("]", "").replace(",", "")
            src_a = instr[18].replace(",", "")
            src_b = None
            operands.append(src_a)
            func = instr[4] + " " + instr[5] + " " + instr[6]

        elif len(instr) == 15:
            d_type = instr[6].replace("]", "").replace(",", "")
            if "%" in instr[10]:
                src_a = instr[10].replace(",", "")
                src_b = instr[14]
                operands.append(src_a)
                operands.append(src_b)
            else:
                src_a = instr[14].replace(",", "")
                operands.append(src_a)
            func = instr[4] + " " + instr[5] + " " + instr[6]

        elif "[" in instr[4]:
            d_type = instr[6].replace("]", "").replace(",", "")
            src_a = instr[7].replace(",", "")
            operands.append(src_a)
            if "%" in instr[11]:
                src_b = instr[11]
                operands.append(src_b)
            else:
                src_b = None
            func = instr[4] + " " + instr[5] + " " + instr[6] + " " + instr[8] + " " + instr[9].replace(",", "") + " " + instr[10] + " " + instr[11]

        else:
            d_type = instr[4]
            src_a = instr[5].replace(",", "")
            src_b = instr[7].replace(",", "")
            operands.append(src_a)
            operands.append(src_b)
            func = instr[4] + " " + instr[5].replace(",", "") + " " + instr[6] + " " + instr[7]
        br_t = None
        br_f = None
        imm = False
        sw = False

    elif type_chk.is_instr(instr) and not type_chk.is_unreachable(instr):
        # Aux Instruction
        """
        %11 = add nsw i32 %10, 1
        %14 = fadd double %12, %13
        """
        if "i32" == instr[4]:
            instr_type = instr[2]
            dst = instr[0].replace(",", "")
            d_type = instr[4]
            src_a = instr[5].replace(",", "")
            src_b = instr[6]
            operands.append(src_a)
            operands.append(src_b)
            func = instr[3]
        else:
            instr_type = instr[2]
            dst = instr[0].replace(",", "")
            d_type = instr[3]
            src_a = instr[4].replace(",", "")
            src_b = instr[5]
            operands.append(src_a)
            operands.append(src_b)
            func = None
        br_t = None
        br_f = None
        imm = (len(instr) == 6)
        sw = False

    elif type_chk.is_unreachable(instr):
        instr_type = None
        dst = None
        d_type = None
        src_a = None
        src_b = None
        func = None
        br_t = None
        br_f = None
        imm = None
        sw = None
    else:
        return None

    return instr_type, \
        dst, \
        d_type, \
        operands, \
        func, \
        br_t, \
        br_f, \
        imm, \
        sw


def switch_parser( line, dst, d_type, no_br ):
    """
    Switch IR is typically not supported by ISA.
    This method works to generate equivalent set of IRs.
    """
    line = line.split()
    """
    switch i32 %7, label %38 [
        i32 48, label %8
        i32 43, label %11
        i32 42, label %15
        i32 45, label %19
        i32 47, label %24
        i32 10, label %35
    ]

    to

    dst = %7

    %lab_{no_br}
    sw_{no_br} = icmp eq d_type dst, 48
    br sw_{no_br}, label %8 label %lab_{no_br+1}

    %lab_{no_br+1}
    sw_{no_br} = icmp eq d_type dst, 43
    br sw_{no_br+1}, label %8 label %lab_{no_br+2}

    %lab_{no_br+2}
    sw_{no_br} = icmp eq d_type dst, 42
    br sw_{no_br+2}, label %8 label %lab_{no_br+3}

    %lab_{no_br+3}
    sw_{no_br} = icmp eq d_type dst, 45
    br sw_{no_br+3}, label %8 label %lab_{no_br+4}

    %lab_{no_br+4}
    sw_{no_br} = icmp eq d_type dst, 47
    br sw_{no_br+4}, label %8 label %lab_{no_br+5}

    %lab_{no_br+5}
    sw_{no_br} = icmp eq d_type dst, 10
    br sw_{no_br+5}, label %8 label %38
    """
    lines = []
    line_icmp = "  sw_" + str(no_br) + " = icmp eq " + line[0] + " " + dst + ", " + line[1]
    line_br = "  br i1 sw_" + str(no_br) + ", label" + line[3] + " label lab_" + str(no_br + 1)

    lines.append(line_icmp)
    lines.append(line_br)
    return "lab_" + str(no_br), lines


def asm_parser( asm ):
    """
    LLVM-IR Parser
    """
    # Current status flags
    #   True then being entered
    in_func = False
    in_bblock = False
    in_switch = False

    # Switch-IR Label-Handling Variable
    no_br = 0

    # Line Number
    no_line = 0

    # Oblects maintains hierarchical structure
    prog = progconst.program()

    for line_no, line in enumerate(asm):
        # These set-up lines should be ommitted
        if (line.find("ModuleID") < 0 and \
            line.find("target") < 0 and \
            line[0] != "@" and \
            line.find("declare") < 0 and \
            line.find("attributes") < 0):

            # Create Instruction Object
            instr = progconst.instruction()

            # Parse Switch IR
            if in_switch:

                # Parse Multiple Lines
                # Check Ending of Swtich
                sw_end = "]" in line
                if not sw_end:
                    # Inside Switch Line Pseudo Parse
                    lab, lines = switch_parser(line, dst, d_type, no_br)

                    # Branching label-number
                    # Switch does not assign label-number for every statement,
                    # so assignment is necessary
                    no_br += 1

                    # Swtich Lines
                    for cnt in range(2):
                        sw_line = lines[cnt]

                        # Register Instruction
                        if type_chk.is_instr(sw_line):
                            if DEBUG:
                                print(sw_line)
                            ins = sw_line.split()
                            instr.opcode, \
                            instr.dst, \
                            instr.d_type, \
                            instr.operands, \
                            instr.func, \
                            instr.br_t, \
                            instr.br_f, \
                            instr.imm, \
                            instr.sw = instr_parser(ins)
                            instr.nemonic = sw_line
                            bblock.append(instr)
                            bblock.num_instrs += 1
                else:
                    # Last instruction should have switch-IR's
                    #   branch target address, setting this
                    instr.br_f = br_f
                    bblock.append(instr)
                    in_switch = False

            elif type_chk.is_func(line):
                # Create Function Object
                func = progconst.function()

                # Register Function
                in_func = True
                line = line.split()

                # Set Function NaME
                if "define" in line:
                    func.set_name(line[2])
                else:
                    func.set_name("entry")
                func.num_bblocks = 0
                no_br = 0
                if DEBUG:
                    print(f"Enter Func: {func.name}")

            elif type_chk.is_bblock(line) and in_func and not in_bblock:
                # Create Basic-Block Object
                bblock = progconst.basicblock()

                # Register Basic-Block
                in_bblock = True
                line = line.split()
                bblock.set_name(line[0].replace(":", ""))
                bblock.num_instrs = 0
                no_br = 0
                if DEBUG:
                    print(f"Enter BBlock: {bblock.name}")

            elif in_func and not in_bblock:
                # Create "First" Basic-Block Object
                bblock = progconst.basicblock()

                # Register Basic-Block (Entry-Block)
                bblock.set_name("entry")
                in_bblock = True
                bblock.num_instrs = 0
                no_br = 0
                if DEBUG:
                    print("Enter BBlock: entry")
                line = line.replace("\n", "")

                # Parse First Instr
                ins = line.split()
                if not "preds" in ins:
                    instr.opcode, \
                    instr.dst, \
                    instr.d_type, \
                    instr.operands, \
                    instr.func, \
                    instr.br_t, \
                    instr.br_f, \
                    instr.imm, \
                    instr.sw = instr_parser(ins)
                    instr.nemonic = line

                    # Register Switch Info
                    dst = instr.dst
                    br_f = instr.br_f
                    d_type = instr.d_type

                    # Register Instr
                    in_switch = instr.sw
                    if not in_switch:
                        bblock.append(instr)

                no_br = 0

            elif type_chk.is_instr(line) and "\n" != line and in_bblock and not in_switch:
                # Register Instruction
                line = line.replace("\n", "")

                # Parse Instr
                ins = line.split()
                instr.opcode, \
                instr.dst, \
                instr.d_type, \
                instr.operands, \
                instr.func, \
                instr.br_t, \
                instr.br_f, \
                instr.imm, \
                instr.sw = instr_parser(ins)
                instr.nemonic = line

                # Register Switch Info
                dst = instr.dst
                br_f = instr.br_f
                d_type = instr.d_type

                # Register Instr
                in_switch = instr.sw
                if not in_switch:
                    bblock.append(instr)

                no_br = 0

            elif "\n" == line and in_bblock:
                # Exit Basic-Block
                # Common Exiting
                if DEBUG:
                    print("Exit BBlock")
                func.append(bblock)
                bblock.clear()
                del bblock

                if DEBUG:
                    for f_index, bblock_ in enumerate(func.bblocks):
                        print(bblock_.name)
                        for b_index, instr in enumerate(bblock_.instrs):
                            print(f"{f_index}:{b_index}:{instr.nemonic}")

                # Clear Flag
                in_bblock = False
                no_br = 0
                if DEBUG:
                    print("\n")

            elif "}" in line and in_func:
                if in_bblock:
                    # Exit Basic-Block
                    # Exiting function on next line
                    # Preprocessing of exiting current bblock is needed
                    if DEBUG:
                        print("Exit BBlock")
                    func.append(bblock)
                    bblock.clear()
                    del bblock

                if DEBUG:
                    for f_index, bblock_ in enumerate(func.bblocks):
                        print(bblock_.name)
                        for b_index, instr in enumerate(bblock_.instrs):
                            print(f"{f_index}:{b_index}:{instr.nemonic}")

                # Clear Flag
                in_bblock = False
                no_br = 0
                if DEBUG:
                    print("\n")

                # Exit Function
                if DEBUG:
                    print("Exit Func")
                prog.append(func)
                func.clear()
                del func

                #clear Flag
                in_func = False
                no_br = 0
                if DEBUG:
                    print("\n")

    # Check Exiting Correctly
    if in_func:
        print(f"Error: Function {func.name} is broken.")

    if in_bblock:
        print(f"Error: Basic Block {bblock.name} is broken.")

    # Dubug Print
    if DEBUG:
        for p_index, func_ in enumerate(prog.funcs):
            print(func_.name)

            for f_index, bblock_ in enumerate(func_.bblocks):
                print(bblock_.name)

                for b_index, instr in enumerate(bblock_.instrs):
                    print("{}:{}:{}:{}".format(p_index, f_index, b_index, instr.nemonic))

    return prog


def is_Val( src ):
    """
    Check literal is value (val) or not.
    Return
        True:   Literal is Value
        False:  Otherwise
    Common for Source-1 and Source-2.
    """
    return "%" != src[0]


def is_None( src ):
    """
    Check literal is None or not.
    Return
        True:   source is type of None
        False:  Otherwise
    Common for Source-1 and Source-2.
    """
    return None == src


def FetchSrc( src="src2", instr=None ):
    """
    Fetch Src-ID from instr class.
    Return
        Literal:    if operand exists
        None:       otherwise
    """
    if None == instr:
        print("Error: Un-registered Instruction is discovered.")
        return None
    elif "src2" == src and len(instr.operands) > 1:
        # Fetch Source-2
        return instr.operands[1]
    elif "src1" == src and len(instr.operands) > 0:
        # Fetch Source-1
        return instr.operands[0]
    else:
        return None


def SetNextInstr(r=None):
    """
    Move to Next Instr
    """

    # Get program
    prog = r.ReadProg()

    # Get current pointer
    ptr = r.ReadPtr()
    f_ptr, b_ptr, i_ptr = ptr["f_ptr"], ptr["b_ptr"], ptr["i_ptr"]

    # Set current pointer by exploring next pointer
    if f_ptr == 0 and b_ptr == 0 and i_ptr == 0:
        r.next_bb = True
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr == 0 and b_ptr == 0 and i_ptr > 0:
        # Move within this block
        r.next_bb = False
        i_ptr -= 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr == 0 and b_ptr > 0 and i_ptr == 0:
        # Move within this block
        r.next_bb = False
        b_ptr -= 1
        i_ptr = prog.funcs[f_ptr].bblocks[b_ptr].num_instrs - 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr == 0 and b_ptr > 0 and i_ptr > 0:
        # Move within this block
        r.next_bb = False
        i_ptr -= 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr > 0 and b_ptr == 0 and i_ptr == 0:
        # Move next func last block, last instr
        r.next_bb = True
        f_ptr -= 1
        b_ptr = prog.funcs[f_ptr].num_bblocks - 1
        i_ptr = prog.funcs[f_ptr].bblocks[b_ptr].num_instrs - 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr > 0 and b_ptr == 0 and i_ptr > 0:
        # Move within this bblock
        r.next_bb = False
        i_ptr -= 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr > 0 and b_ptr > 0 and i_ptr == 0:
        # Move next block
        r.next_bb = True
        b_ptr -= 1
        i_ptr = prog.funcs[f_ptr].bblocks[b_ptr].num_instrs - 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr > 0 and b_ptr > 0 and i_ptr > 0:
        # Move within this bblock
        r.next_bb = False
        i_ptr -= 1
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    elif f_ptr == 0 and b_ptr == 1 and i_ptr == 0:
        # Terminal (No next instr)
        r.next_bb = True
        ptr = {"f_ptr":f_ptr, "b_ptr":b_ptr, "i_ptr":i_ptr}

    r.SetPtr(ptr)


class RegInstr:
    """
    Registering Utilities
    """
    def __init__(self, prog, ptr):
        self.prog = prog            #program class
        self.ptr = ptr              #tracking pointer
        self.stack_ptr = []         #stack for pointers
        self.hit_ptr = None         #pointer for search-hit
        self.instr = None           #instruction class
        self.next_bb = False        #Moved to Next Basic Block then True

    def ReadProg( self ):
        """
        Read Program
        """
        return self.prog

    def ReadHitPtr( self ):
        """
        Read Hit (Source-Node) Pointer
        """
        return self.hit_ptr

    def ReadPtr( self ):
        """
        Read Current Pointer
        """
        return self.ptr

    def SetPtr( self, ptr=None ):
        """
        Set Pointers
        """
        self.ptr = copy.deepcopy(ptr)

    def PushPtr( self ):
        """
        Push Pointers to Stack
        Used for Record a Path having Source-2 for backing to the instr
        Used when enters to source-2 path
        """
        ptr = self.ptr
        self.stack_ptr.append(copy.deepcopy(ptr))

    def PopPtr( self, SrcNo=None ):
        """
        Pop Pointers from Stack
        Used for reverting Path and entering to Source-1 path
        """
        if len(self.stack_ptr) > 0:
            self.ptr = self.stack_ptr.pop()

    def DepthStack( self ):
        """
        Return Stack-Depth
        """
        return len(self.stack_ptr)

    def CheckInstr( self, ptr=None ):
        """
        Record instruction addressed by current pointer
        Marking discovered flag which indicates source-1 operand is commited.
        """
        if None == ptr:
            f_ptr, b_ptr, i_ptr = self.ptr["f_ptr"], self.ptr["b_ptr"], self.ptr["i_ptr"]
        else:
            f_ptr, b_ptr, i_ptr = ptr["f_ptr"], ptr["b_ptr"], ptr["i_ptr"]
        self.prog.funcs[f_ptr].bblocks[b_ptr].instrs[i_ptr].discovered = True

    def CheckHitInstr( self ):
        """
        Record hit-instruction addressed by hit-pointer
        Marking discovered flag which indicates source-1 operand is commited.
        """
        f_ptr, b_ptr, i_ptr = self.hit_ptr["f_ptr"], self.hit_ptr["b_ptr"], self.hit_ptr["i_ptr"]
        self.prog.funcs[f_ptr].bblocks[b_ptr].instrs[i_ptr].discovered = True

    def ReadInstr( self, ptr=None ):
        """
        Fetch Instruction addessed by current pointer
        """
        f_ptr, b_ptr, i_ptr = ptr["f_ptr"], ptr["b_ptr"], ptr["i_ptr"]
        instr = self.prog.funcs[f_ptr].bblocks[b_ptr].instrs[i_ptr]
        return self.prog.funcs[f_ptr].bblocks[b_ptr].instrs[i_ptr]

    def SetPrevInstr( self, instr=None ):
        """
        Set discovered instruction
        """
        self.instr = instr

    def ReadPrevInstr( self ):
        """
        Read previoiusly discovered instruction
        """
        return self.instr

    def NextInstr( self, prog, r ):
        """
        Set Instruction as a Node
        Update pointers (current and previous) for this loop-cycle.
        """
        SetNextInstr(r)

        # Can Explore Path
        return "next_seq_src2"

    def CheckTerm( self ):
        """
        Check termination
        If all instructions are discovered then does termination.
        This event is at reaching to first instruction (pointer is zero).
        """
        prog = self.ReadProg()
        cont = False
        for func in prog.funcs:
            for bblock in func.bblocks:
                for instr in bblock.instrs:
                    if instr.discovered or len(instr.operands) == 0:
                        cont = cont | False
                    else:
                        cont = True

        if not cont and len(self.stack_ptr) == 0:
            return "term"
        else:
            return "next_reg_dst"

    def CheckBlockTerm( self ):
        return self.ptr == 0

    def SearchDst( self ):
        """
        Search Instruction having Undiscovered
        This module works when seeking pointer reaches to terimial nodes.
        This case needs to resets pointer to un-discovered instruction
            which is closest to end of file.
        """
        prog = self.prog
        f_ptr, b_ptr, i_ptr = self.ptr["f_ptr"], self.ptr["b_ptr"], self.ptr["i_ptr"]
        for f_index in range(f_ptr, -1,-1):
            num_bblocks = prog.funcs[f_index].num_bblocks - 1
            for b_index in range(num_bblocks, -1, -1):
                num_instrs = prog.funcs[f_index].bblocks[b_index].num_instrs - 1
                for i_index in range(num_instrs, -1, -1):
                    instr = prog.funcs[f_index].bblocks[b_index].instrs[i_index]
                    if not instr.discovered:
                        # Find dst node
                        prog.funcs[f_index].bblocks[b_index].instrs[i_index].discovered = True
                        ptr = {"f_ptr":f_index, "b_ptr":b_index, "i_ptr":i_index}
                        self.SetPtr(ptr)

                        self.num_exit += 1

                        return True

        # Could Not Find source node
        return False

    def SearchSrc( self, src=None ):
        """
        Search Instruction having Source Operand
        """
        prog = self.prog
        f_ptr, b_ptr, i_ptr = self.ptr["f_ptr"], self.ptr["b_ptr"], self.ptr["i_ptr"]
        for f_index in range(f_ptr, -1,-1):
            num_bblocks = prog.funcs[f_index].num_bblocks - 1
            for b_index in range(num_bblocks, -1, -1):
                num_instrs = prog.funcs[f_index].bblocks[b_index].num_instrs - 1
                for i_index in range(num_instrs, -1, -1):
                    instr = prog.funcs[f_index].bblocks[b_index].instrs[i_index]
                    if instr.dst == src and src != None:
                        # Found source node
                        ptr = {"f_ptr":f_index, "b_ptr":b_index, "i_ptr":i_index}
                        self.hit_ptr = ptr
                        return True

        # Could Not Find source node
        return False


def IR_Parser( dir_ll, file_name ):
    openfile = dir_ll +"/"+ file_name
    prog = None

    with open(openfile, "r") as llvm_ir:
        """
        LLVM-IR file-open, and parsing the IR file
        """
        prog = asm_parser(llvm_ir)
        prog.name = file_name.split(".")[0]
        print("File: {} parsed.".format(file_name))

        return prog