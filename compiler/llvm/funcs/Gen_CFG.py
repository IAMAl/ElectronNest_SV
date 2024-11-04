##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.DrawUtils as drawutils


DEBUG = False

def cfg_extractor( prog, out ):
    """
    Control Graph Extractor
    """
    # Fetch Basic Block Label
    for bb_f_indx in range(prog.num_funcs):
        #print(prog.funcs[bb_f_indx].num_bblocks)
        # Fetch Target BBlock
        for bb_b_indx in range(prog.funcs[bb_f_indx].num_bblocks):
            bb_i_indx = prog.funcs[bb_f_indx].bblocks[bb_b_indx].num_instrs - 1
            target_nemonic = prog.funcs[bb_f_indx].bblocks[bb_b_indx].name
            br_t = prog.funcs[bb_f_indx].bblocks[bb_b_indx].instrs[bb_i_indx].br_t
            br_f = prog.funcs[bb_f_indx].bblocks[bb_b_indx].instrs[bb_i_indx].br_f

            if br_t is not None:
                br_t = br_t.replace(',', '')
            if br_f is not None:
                br_f = br_f.replace(',', '')

            # Fetch Destination Node of BBlock
            for f_indx in range(prog.num_funcs):
                for b_indx in range(prog.funcs[f_indx].num_bblocks):
                    if b_indx != bb_b_indx:
                        # Assign Node label
                        if prog.funcs[f_indx].bblocks[b_indx].name is not None:
                            if "entry" in prog.funcs[f_indx].bblocks[b_indx].name:
                                b_label = "entry"
                            else:
                                b_label = "label:<"+prog.funcs[f_indx].bblocks[b_indx].name+">"
                        else:
                            break

                        # Fetch BBlock Name
                        b_nemonic = prog.funcs[f_indx].bblocks[b_indx].name

                        # Fetch Number of Instrs in the BBlock
                        num_instrs = prog.funcs[f_indx].bblocks[b_indx].num_instrs

                        # Fetch Last Instr
                        instr = prog.funcs[f_indx].bblocks[b_indx].instrs[num_instrs - 1]

                        fro = target_nemonic
                        to = b_nemonic

                        if DEBUG:
                            print(" target :{} [ T[{}]  F[{}] ] with {}".format(target_nemonic, br_t, br_f, b_label))

                        if br_t is not None and b_label == br_t:
                            if DEBUG:
                                print(">>T-Matched:{}".format(br_t))
                            if fro == "entry":
                                attrib = "[color=black dir=black]"
                            elif br_t == br_f:
                                attrib = "[color=red dir=black]"
                            else:
                                attrib = "[color=blue dir=black]"
                            out.write("\"%s\" -> \"%s\"%s\n" % (fro, to, attrib))

                        if br_f is not None and b_label == br_f and br_t != br_f:
                            if DEBUG:
                                print(">>F-Matched:{}".format(br_f))
                            attrib = "[color=green dir=black]"
                            out.write("\"%s\" -> \"%s\"%s\n" % (fro, to, attrib))

            num_instrs = prog.funcs[bb_f_indx].bblocks[bb_b_indx].num_instrs
            instr = prog.funcs[bb_f_indx].bblocks[bb_b_indx].instrs[num_instrs - 1]
            b_nemonic = prog.funcs[bb_f_indx].bblocks[bb_b_indx].name
            to = b_nemonic
            if instr.opcode == "ret" and bb_f_indx == (prog.num_funcs-1) and bb_b_indx == (prog.funcs[bb_f_indx].num_bblocks-1):
                attrib = "[color=black dir=black]"
                out.write("\"%s\" -> \"%s\"%s\n" % (to, "ret", attrib))

    out.write("}")


def dupl_remover_cfg( w_file_path, w_file_name, prog ):
    dot_file_name = w_file_name
    openfile = w_file_path +'/'+ dot_file_name

    present_lines = []
    lines = []
    num_dup = 0

    with open(openfile, "r") as dot_file:
        for present_line in dot_file:
            present_lines.append(present_line)

    # Seek Same Line with Scan-Line Method
    for present_no, present_line in enumerate(present_lines):
        for compare_no, compare_line in enumerate(present_lines):
            if compare_no == 0:
                lines.append(present_line)
            elif compare_line == present_line and compare_no != present_no:
                #print("duplicated.")
                num_dup += 1
                start_no = present_no+compare_no
                for index_no in range(start_no, len(present_lines)-1, 1):
                    present_lines[index_no] = present_lines[index_no+1]

                present_lines[len(present_lines)-1] = ""

    print("Total {} lines removed.".format(num_dup))

    dot_file_name =w_file_path+ "/"+prog.name+"_cfg_r.dot"
    with open(dot_file_name, "w") as dot_file:
        for line_no in range(len(present_lines)):
            dot_file.write(present_lines[line_no])


def Main_Gen_LLVMtoCFG( prog, w_file_path ):

    w_file_name = prog.name + "_cfg.dot"

    with open(w_file_path+"/"+w_file_name, "w") as out:
        # Graph Utilities
        g_cfg = drawutils.GraphUtils(out)

        # Graph Header Description
        g_cfg.start_cf_graph()
        cfg_extractor(prog=prog, out=out)

    # Reform Graph
    dupl_remover_cfg(w_file_path, w_file_name, prog)