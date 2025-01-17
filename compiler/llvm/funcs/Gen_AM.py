##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################
import numpy as np


def ZeroRemover( am ):
    """
    Zero Row/Column Remover
    """
    am_ = []
    zero_rows = []
    for row_index, row in enumerate(am):
        find = False
        row_ = []
        for clm_index, clm_elm in enumerate(row):
            if clm_elm == 1:
                find = True

            row_.append(clm_elm)

        if find:
            am_.append(row_)
        else:
            zero_rows.append(row_index)

    am = am_

    if isinstance(am, list):
        if len(am) > 0 and len(am[0]) > 0:
            am_ = []
            for row in am:
                clm = []
                for clm_index, clm_elm in enumerate(row):
                    if not clm_index in zero_rows:
                        clm.append(clm_elm)

                am_.append(clm)

            am = am_

    return am


def Get_Dst(dot_lines, opcode):
    for line in dot_lines:
        chk_opcode = line[1]
        if chk_opcode == opcode:
            if len(line) > 2:
                return line[2]
            else:
                return "None"
    return "None"


def AMComposer( ZERO_REMOVE=False, mode="dst_append", zero_remove=False, r_file_path=".", r_file_name="", w_file_path=".", w_file_name="" ):
    """
    Adjacency Matrix Composer

    Arguments:
        r_file_path:  path for input flle
        r_file_name:  input file name
        w_file_path:  path for output flle
        w_file_name:  output file name

    Function
        - Generates File representing Adacency Matrix
        - Generates File representing Node List
        - Files having Postfix "_inv" is an Inverse AM and is Node List
    """

    # Parsing
    # Feeding dot file, and split with "->"
    dot_lines = []

    openfile = r_file_path +"/"+ r_file_name+".dot"
    with open(openfile, "r") as dot_file:
        for present_line in dot_file:

            present_line = present_line.split(' -> ')

            tmp_line = []
            if len(present_line) > 1:
                present_line[1] = present_line[1].split('[')
                if len(present_line[1]) > 1:
                    tmp = present_line[1][1].split(' label=')
                    if len(tmp) > 1:
                        dst =  Get_Dst(dot_lines, present_line[1][0])
                        tmp_line.append(present_line[1][0])
                        tmp_line.append(present_line[0])
                        tmp = tmp[1][1:len(tmp)-4]
                        tmp_line.append(tmp)
                        tmp_line.append(dst)
                        present_line = tmp_line
                    else:
                        dst =  Get_Dst(dot_lines, present_line[1][0])
                        tmp_line.append(present_line[1][0])
                        tmp_line.append(present_line[0])
                        tmp_line.append(dst)
                        present_line = tmp_line
                else:
                    dst =  Get_Dst(dot_lines, present_line[0])
                    tmp_line.append(present_line[0])
                    tmp_line.append(present_line[1][0])
                    tmp_line.append(dst)
                    present_line = tmp_line
            elif len(present_line) > 0:
                present_line[0] = present_line[0].split('[')[0]

            # Remove Unnecessary Chars
            present_line[0].replace('" ', '')
            present_line[0].replace('"', '')

            if len(present_line) > 1:
                dot_lines.append(present_line)


    #print(dot_lines)


    # Node-ID Composition
    leaf_node_list = []
    node_list = []
    dst_found_list = []
    src_found_list = []
    for no, nodes in enumerate(dot_lines):
        # Check Node in Destination
        find = False
        dst_node = nodes[0].replace('"', '')
        src_node = nodes[1].replace('"', '')

        if len(nodes) > 3:
            src_index = nodes[2].replace('"', '')
            dst_index = nodes[-1].replace('"', '')
        elif len(nodes) > 2:
            src_index = nodes[1].replace('"', '')
            dst_index = nodes[-1].replace('"', '')
        elif len(nodes) > 1:
            src_index = nodes[1].replace('"', '')
            dst_index = "SINK"
        else:
            src_index = "LEAF"


        # Register Node to List
        find_dst = False
        index = 0
        for index, node in enumerate(node_list):
            if node[1] == dst_node:
                find_dst = True
                break

        find_src = False
        if not find_dst:
            if not no in src_found_list:
                dst_found_list.append(no)
                node_list.append([no, dst_node, src_index, dst_index])
                find_src = True


        # Check 2nd Source, add 2nd Source to List-entry if available
        if find_dst:# and not no in src_found_list and not find_src:
            if len(nodes) > 1:
                if len(node_list[index]) > 3:
                    node_list[index] = node_list[index][:len(node_list[index])-1]+[src_index]+[node_list[index][len(node_list[index])-1]]
                elif len(node_list[index]) > 2:
                    node_list[index] = node_list[index]+[" "+src_index]

        # Check Node in Source
        find = False
        src_node = nodes[1]
        for index, dst_nodes in enumerate(dot_lines[no+1:len(dot_lines)-1]):
            if dst_nodes[0] == src_node:
                find = True
                break

        # Register
        if not find:
            for no_ in src_found_list:
                if no == no_:
                    find = True
            for no_ in leaf_node_list:
                if src_node == no_[1]:
                    find = True
            if not find and not "load" in src_node:
                src_found_list.append(no)
                leaf_node_list.append([ no, src_node, "LEAF" ])


    # Node-ID Sorting
    for no, node in enumerate(node_list):
        node_list[no][0] = no

    # Append Leaf-Node to Node-List
    node_list_ = node_list
    len_entry = len(node_list)
    count = 0
    for index, leaf_node in enumerate(leaf_node_list):
        find = False
        for node in node_list_:
            if node[0] is leaf_node[1]:
                find = True

        if not find and "load" not in leaf_node[1]:
            node_list.append([len_entry+count, leaf_node[1], leaf_node[2]])
            count += 1

    #print(node_list)

    # Inverse-AM Composition
    #   Output Node List for Inverse-AM
    openfile = w_file_path +"/"+ w_file_name+"_node_list_inv.txt"
    with open(openfile, "w") as node_list_file:
        for index, node in enumerate(node_list):
            # Write dst Node
            node[1] = node[1].replace('\"','')
            node_list_file.write(str(node[0])+" "+node[1])
            #print(node)

            # Write src Edge
            if len(node) > 4 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[4]+" "+node[2]+" "+node[3]+"\n")
            elif len(node) > 3 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[3]+" "+node[2]+"\n")
            elif len(node) > 2 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" None "+node[2]+"\n")
            else:
                node_list_file.write(" "+node[2]+"\n")


    # Compose Inverse-AM
    iam = np.zeros((len(node_list), len(node_list)), dtype=int)
    for line in dot_lines:
        src_node = line[0].replace('"', "")
        dst_node = line[1].replace('"', "")

        src_find = False
        for no, node in enumerate(node_list):
            if src_node == node[1]:
                src_no = no
                src_find = True
                break

        dst_find = False
        for no, node in enumerate(node_list):
            if dst_node == node[1]:
                dst_no = no
                dst_find = True
                break

        if src_find and dst_find:
            iam[src_no][dst_no] = 1
            iam[dst_no][src_no] = 1


    # Remove Zero-Row and Zero-Column
    if ZERO_REMOVE:
        zero_rows = []
        iam_ = []
        for index, irow in enumerate(iam):
            if not 1 in irow:
                zero_rows.append(index)
            else:
                iam_.append(irow.tolist())

        iam = []
        for index, irow in enumerate(iam_):
            cnt = 0
            for zero_index in zero_rows:
                irow.pop(zero_index-cnt)
                cnt += 1

            iam.append(irow)

    iam = np.array(iam)

    # Output The Inverse-AM
    openfile = w_file_path +"/"+ w_file_name+"_am_inv.txt"
    with open(openfile, "w") as am_file:
        am_file.writelines(str(iam))


    # AM Composition
    #   Output for Node List for AM
    openfile = w_file_path +"/"+ w_file_name+"_node_list.txt"
    with open(openfile, "w") as node_list_file:
        for index, node in enumerate(node_list):
            # Write dst Node
            node[1] = node[1].replace('\"','')
            print(f"{node[0]} dst:{node[1]}")
            node_list_file.write(str(len(node_list) - node[0])+" "+node[1])

            # Write src Edge
            if len(node) > 4 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[4]+" "+node[2]+" "+node[3]+"\n")
            elif len(node) > 3 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[3]+" "+node[2]+"\n")
            elif len(node) > 2 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" None "+node[2]+"\n")
            else:
                node_list_file.write(" "+node[2]+"\n")


    with open(openfile, "w") as node_list_file:
        for index, node in enumerate(node_list):
            # Write dst Node
            node[1] = node[1].replace('\"','')
            node_list_file.write(str(node[0])+" "+node[1])

            # Write src Edge
            if len(node) > 4 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[4]+" "+node[2]+" "+node[3]+"\n")
            elif len(node) > 3 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" "+node[3]+" "+node[2]+"\n")
            elif len(node) > 2 and mode == "dst_append":
                node[2] = node[2].replace('\"','')
                node_list_file.write(" None "+node[2]+"\n")
            else:
                node_list_file.write(" "+node[2]+"\n")

    # Compose AM
    am = np.zeros((len(node_list), len(node_list)), dtype=int)
    for line in dot_lines:
        src_node = line[0].replace('"', "")
        dst_node = line[1].replace('"', "")
        src_find = False
        for no, node in enumerate(node_list):
            if src_node == node[1]:
                src_find = True
                src_no = len(node_list) - no - 1
                break

        dst_find = False
        for no, node in enumerate(node_list):
            if dst_node == node[1]:
                dst_no = len(node_list) - no - 1
                dst_find = True
                break

        if src_find and dst_find:
            am[src_no][dst_no] = 1
            am[dst_no][src_no] = 1

    # Remove Zero-Row and Zero-Column
    if ZERO_REMOVE:
        zero_rows = []
        am_ = []
        for index, irow in enumerate(am):
            if not 1 in irow:
                zero_rows.append(index)
            else:
                am_.append(irow.tolist())

        am = []
        for index, irow in enumerate(am_):
            cnt = 0
            for zero_index in zero_rows:
                irow.pop(zero_index-cnt)
                cnt += 1


            am.append(irow)

    am = np.array(am)

    #   Output AM
    openfile = w_file_path +"/"+ w_file_name+"_am.txt"
    with open(openfile, "w") as am_file:
        am_file.writelines(str(am))