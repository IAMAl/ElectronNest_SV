##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

def ExtractBBs( file_path, file_name ):
    """
    Basic Block Extractor
    """
    basic_blocks = []
    current_label = None
    branch_instruction = None

    bblocks = []
    instrs = []

    with open(file_path+"/"+file_name+".ll", 'r') as file:
        instrs = []
        bblocks = []
        count = 0
        for index, line in enumerate(file):

            if not line.isspace():
                count += 1

                instrs.append(line)

                # Check for a label
                if ('%' not in line or ('%' in line and 'preds' in line )) and ':' in line:
                    line = line.split()
                    current_label = line[0].strip().replace(':', '')
                    branch_instruction = None

                # Check for a branch instruction
                elif 'br' in line:
                    branch_instruction = line.strip()
                    bblocks.append(instrs)

                # Save the previous basic block
                if current_label is not None and branch_instruction is not None:
                    basic_blocks.append([current_label, branch_instruction, count])
                    current_label = None
                    branch_instruction = None
                    instrs = []
                    count = 0

    if current_label is not None:
        basic_blocks.append([current_label, '', count])
        bblocks.append(instrs)

    return bblocks, basic_blocks


def ReadLabel( branch_instr ):
    """
    Label Reader
    """
    tokens = branch_instr.split(' ')
    labels = []
    for token in tokens:
        if '%' in token:
            token = token.replace(' ', '').replace(',', '').replace('%', '')
            labels.append(token)

    return labels


def GetLabelInfo( basic_blocks ):
    """
    Get Label Information
    """
    label_info = []

    for basic_block in enumerate(basic_blocks):
        #print(f"basic_block:{basic_block}")
        label = basic_block[1][0]
        branch_instr = basic_block[1][1]

        labels = ReadLabel(branch_instr)
        #print(f"labels:{labels}")
        label_info.append([label, labels])

    return label_info


def CFGNodeMerger( r_file_path, r_file_name ):
    """
    Node Merger for Control-Flow Graph
    """
    bblocks, basic_blocks = ExtractBBs(r_file_path, r_file_name)

    label_info = GetLabelInfo(basic_blocks)
    #print(f"label_info:{label_info}")

    hit_count = 0
    for bb_index, basic_block in enumerate(basic_blocks):
        #print(f"basic_block:{basic_block}")
        num_instrs = basic_block[2]
        find = False
        if num_instrs == 2 and len(label_info[bb_index][1]) < 2:
            find = True
            bb_label = label_info[bb_index][0]
            print(f"br only basic block label:{bb_label} bblock-no:{bb_index}")

            for bb_chk_index, bblock in enumerate(bblocks):
                label = label_info[bb_chk_index][0]
                if label == bb_label:
                    target_labels = label_info[bb_chk_index][1]
                    label_t = None
                    label_f = None
                    if len(target_labels)>2:
                        label_t = target_labels[1]
                        label_f = target_labels[2]
                    elif len(target_labels)>1:
                        label_t = target_labels[0]
                        label_f = target_labels[1]
                    elif len(target_labels)>0:
                        label_t = target_labels[0]

                    print(f"target_labels:{target_labels} at bblock-no:{bb_chk_index} label_t:{label_t} label_f:{label_f}")

                    if label_t is not None:
                        t_index_t = 0
                        t_label = ""
                        for index, chk_label in enumerate(label_info):
                            if label_t in chk_label[0]:
                                t_label = chk_label[1]
                                t_index_t = index
                                #print(f"t_index_t:{t_index_t}")
                                break

                        index_t = 0
                        pred_label = ""
                        for index, chk_label in enumerate(label_info):
                            if bb_label in chk_label[1]:
                                pred_label = chk_label[0]
                                if pred_label != 'entry':
                                    pred_label = '%'+pred_label
                                index_t = index
                                #print(f"index_t:{index_t} pred_label:{pred_label}")
                                break

                        bblocks[t_index_t-hit_count][0] = bblocks[t_index_t-hit_count][0].replace('%', '').replace(bb_label, " "+pred_label).replace('\n', '')
                        #print(f"bblocks[t_index_t][0]:{bblocks[t_index_t][0]}")

                        target_label = '%'+label_t
                        label = '%'+bb_label
                        print(f"replace label:{label} with target_label:{target_label} at bblock-no:{index}")
                        for index, labels in enumerate(label_info):
                            chk_label = labels[1]
                            if bb_label in chk_label:
                                bblocks[index][len(bblocks[index])-2] = bblocks[index][len(bblocks[index])-2].replace(label, target_label)
                                #print(f"bblock:{bblocks[index]}  label:{label}  target_label:{target_label}")
                                bblocks.pop(bb_chk_index-hit_count)
                                hit_count += 1

                    if label_f is not None:
                        f_index_t = 0
                        f_label = ""
                        for index, chk_label in enumerate(label_info):
                            if label_t in chk_label[0]:
                                f_label = chk_label[1]
                                f_index_t = index
                                #print(f"f_index_t:{f_index_t}")
                                break

                        index_t = 0
                        pred_label = ""
                        for index, chk_label in enumerate(label_info):
                            if bb_label in chk_label[1]:
                                pred_label = chk_label[0]
                                if pred_label != 'entry':
                                    pred_label = '%'+pred_label
                                index_t = index
                                #print(f"index_t:{index_t} pred_label:{pred_label}")
                                break

                        bblocks[f_index_t][0] = bblocks[f_index_t][0].replace('%', '').replace(bb_label, " "+pred_label)
                        #print(f"bblocks[f_index_t][0]:{bblocks[f_index_t][0]}")

                        target_label = '%'+label_f
                        label = '%'+bb_label
                        print(f"replace label:{label} with target_label:{target_label} at bblock-no:{index}")
                        for index, labels in enumerate(label_info):
                            chk_label = labels[1]
                            if bb_label in chk_label:
                                bblocks[index][len(bblocks[index])-2] = bblocks[index][len(bblocks[index])-2].replace(label, target_label)
                                #print(f"bblock:{bblocks[index]}  label:{label}  target_label:{target_label}")
                                bblocks.pop(bb_chk_index-hit_count)
                                hit_count += 1

                    print("\n")
        if not find and bb_index < len(bblocks):
            bblocks[bb_index].append('\n')

    bblocks_ = []
    for bblock in bblocks:
        if len(bblock[-1]) > 2:
            bblock.append('\n')
        bblocks_.append(bblock)

    return bblocks_


def ExtractCFGNodeMerger( r_file_path, r_file_name, w_file_path ):
    w_file_name = r_file_name+"_merged.ll"

    bblocks = CFGNodeMerger(r_file_path, r_file_name)
    with open(w_file_path+"/"+w_file_name, 'w') as file:
        for index, bblock in enumerate(bblocks):
            #print(index)
            for idx, instr in enumerate(bblock):
                #print(idx)
                file.write(instr)