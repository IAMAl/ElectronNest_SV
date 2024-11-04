##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.GraphUtils as graphutils


def TranslateNode(r_file_name, CyclicEdges):

    node_list = graphutils.ReadNodeList(r_file_name)
    #print(f"node_list:{node_list}")

    CyclicEdges_ = []
    for cycle_path in CyclicEdges:
        path = []
        for node_no in cycle_path:
            for node in node_list:
                if node[0] == str(node_no):
                    print("  Checked: Node-{}( BBlock-{} ) == Node-{}".format(node[0], node[1], node_no))
                    node_id = node[1]
                    path.append(node_id)
                    break

            #print(path)

        CyclicEdges_.append(path)

    return CyclicEdges_


def Get_Neighbors( my_no, am_size, am, ng_id ):
    if my_no != ng_id or my_no == 0:
        row = am[my_no]
        nnodes = []
        for index in range(am_size):
            if row[index] == 1 and index != ng_id:
                nnodes.append(index)

        if len(nnodes) == 1:
            return [-1]+nnodes
        else:
            return nnodes
    else:
        return []

def is_Loop( ptr, addr, Paths ):
    Find = False
    NNodes = Paths[ptr][2][addr:]
    for check_node_id in NNodes:
        for index in range(len(Paths)-1):
            nnode_id = Paths[index][0]

            if check_node_id == nnode_id:
                return True, index

    return Find, 0


def is_NotTerm( Paths ):
    for path in Paths:
        #print(f">>>> len(path[2]) : {len(path[2]) } > path[1] : {path[1]+1}")
        if len(path[2]) > (path[1]+1):
            return False

    return True


def RollBack(target_id, ptr, prev_ptr, Paths):

    for check_ptr in range(ptr, -1,-1):
        check_id = Paths[check_ptr][0]
        check_addr = Paths[check_ptr][1]
        check_srcs = Paths[check_ptr][2]
        check_len = len(check_srcs)

        if target_id in check_srcs:
            #print(f"    Found target node {target_id}: compare {len(check_srcs)} and {check_addr+1}")
            if len(check_srcs) <= (check_addr+1):
                #print(f"    Already exlpored, go back more")
                target_id = check_id
                back_ptr = RollBack(target_id, check_ptr, ptr, Paths)
                back_node_id = Paths[back_ptr][0]
                #print(f"    This node {back_node_id} is roll back node")
                return back_ptr
            else:
                back_node_id = Paths[check_ptr][0]
                #print(f"    This node {back_node_id} is roll back node")
                return check_ptr

        # roll back more

    return ptr


def GetPtr( node_id, Paths ):
    for index, path in enumerate( Paths ):
        if path[0] == node_id:
            return index

    return -1


def GetPath( node_id1, node_id2, PathStack ):
    #print(f"PathStack:{PathStack}, node_id1:{node_id1}, node_id2:{node_id2}")
    if node_id1 in PathStack:
        if node_id2 in PathStack:
            index1 = PathStack.index( node_id1 )
            index2 = PathStack.index( node_id2 )

            if index1 < index2:
                start_index = index1
                end_index = index2 + 1
            else:
                start_index = index2
                end_index = index1 + 1

            path = PathStack[start_index:end_index]
            print(f"path>>:{path}")
            return path

    return []


def GetNNodes( index, Paths ):
    return Paths[index][2]


def CycleDetector( am_size=0, am=[], nodes=[], edgetab=[] ):

    Loops = []
    Paths = []
    PathStack = []

    nnode_id = 0

    ptr = 0
    index = 0
    addr = 0
    Find = False

    # Get Neighbor Node's ID
    NNodes = Get_Neighbors( ptr, am_size, am, ptr )
    Paths.append([ptr, 0, NNodes])

    while not is_NotTerm(Paths):

        print(f"Paths = {Paths}")
        print(f"  ptr = {ptr}, addr = {addr}, index = {index}")

        nnode_id = Paths[ptr][2][addr]
        print(f"  Check Neighbor Node-{nnode_id} for Node-{Paths[ptr][0]}")

        # Loop-Check
        Find, index = is_Loop( ptr, addr, Paths )

        # Case of Initial Iteration
        if len(Paths) == 1:
            Paths[ptr][1] += 1

        neighbor_id = Paths[index][0]

        if Find:
            print(f"  Cycle Detected from Node-{Paths[ptr][0]} to Neighbor Node-{neighbor_id}")

            Paths[ptr][1] += 1

            # Collecting Path Nodes
            loop = []
            NNodes_ptr = GetNNodes( ptr, Paths )
            NNodes_index = GetNNodes( index, Paths )

            # Get Intermediate Node-IDs on the Loop
            IPaths = []
            smallest_ptr = index
            for nnode_ptr_id in NNodes_ptr:
                ptr_id_ptr = GetPtr( nnode_ptr_id, Paths )

                for nnode_index_id in NNodes_index:
                    index_id_ptr = GetPtr( nnode_index_id, Paths )

                    if index_id_ptr >= ptr_id_ptr and index_id_ptr != ptr and ptr_id_ptr != index:
                        path = GetPath( nnode_ptr_id, nnode_index_id, PathStack )
                        IPaths.append( path )
                        if ptr_id_ptr <= smallest_ptr:
                            smallest_ptr = ptr_id_ptr
                        break

            # Register Loops
            for ipath in IPaths:
                loop = ipath
                #loop.append( Paths[ptr][0] )
                if Paths[index][0] not in loop:
                    loop.append( Paths[index][0] )
                else:
                    offset = loop.index(Paths[index][0] )
                    loop = loop[:offset+1]
                if Paths[ptr][0] not in loop:
                    loop.append( Paths[ptr][0] )
                else:
                    offset = loop.index(Paths[ptr][0] )
                    loop = loop[:offset+1]
                Loops.append(loop)

            # Update address
            addr = 1 + Paths[index][1]
            Paths[index][1] = addr

            index = smallest_ptr

            # Roll-back when the index reaches already explored node
            tmp_ptr = index
            if (1 + Paths[index][1]) >= len(Paths[index][2]):
                target_id = Paths[index][2][-1]
                check_ptr = RollBack(target_id, index, ptr, Paths)
                print(f"    Node-{Paths[check_ptr][0]} is roll back node")
                tmp_ptr = check_ptr

            prev_ptr = ptr
            ptr = tmp_ptr
            index = tmp_ptr
            addr = Paths[tmp_ptr][1]

        else:
            prev_ptr = ptr
            prev_id = Paths[ptr][0]

            # Get Neighbor Node's ID
            NNodes = Get_Neighbors( nnode_id, am_size, am, prev_ptr )
            if (len(NNodes) > 0 and [nnode_id, 0, NNodes] not in Paths) and len(Paths) == 1:
                NNodes[0:0] = [-1]
                NNodes.pop(1)

            # Register Node
            # format: [Node-ID, Pointer, [Neighbor Node-IDs]]
            Paths.append([nnode_id, 0, NNodes])
            ptr = len(Paths) - 1
            
            # Increment Pointer of Explored Node
            Paths[prev_ptr][1] += 1
            
            if (len(Paths[ptr][2]) > 0) and ( prev_id in Paths[ptr][2] or Paths[ptr][2][0] == -1):
                Paths[ptr][1] += 1
                addr = 1
            else:
                addr = 0

            if len(Paths[ptr][2]) == 0:
                ptr = prev_ptr
                addr = Paths[ptr][1]

            # Register Explored Node-ID in Stack
            PathStack.append( prev_id )

    if len(Loops) > 0:
        print(f"loops are detected: {Loops}")
    else:
        print(f"NO loop is detected")
    return Loops