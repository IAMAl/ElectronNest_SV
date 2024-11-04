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


class Path:
    def __init__( self ):
        self.st_route_path = []
        self.st_ld_path = []
        self.st_leaf_path = []
        self.ld_ld_path = []
        self.ld_leaf_path = []

        self.Branch_St = []
        self.Branch_Ld = []

        self.Branch = []

    def Register( self, path_select, path ):
        if path_select == 'st_route_path':
            self.st_route_path.append( path )

        elif path_select == 'st_ld_path':
            self.st_ld_path.append( path )

        elif path_select == 'st_leaf_path':
            self.st_leaf_path.append( path )

        elif path_select == 'ld_ld_path':
            self.ld_ld_path.append( path )

        elif path_select == 'ld_leaf_path':
            self.ld_leaf_path.append( path )

    def Get( self, path_select ):
        if path_select == 'st_route_path':
            return self.st_route_path

        elif path_select == 'st_ld_path':
            return self.st_ld_path

        elif path_select == 'st_leaf_path':
            return self.st_leaf_path

        elif path_select == 'ld_ld_path':
            return self.ld_ld_path

        elif path_select == 'ld_leaf_path':
            return self.ld_leaf_path

    def Set_BranchStNode( self, index ):
        self.Branch_St.append( index )

    def Set_BranchLdNode( self, index ):
        self.Branch_Ld.append( index )

    def Push( self, index ):
        self.Branch.append( index )

    def Pop( self ):
        return self.Branch.pop( -1 )

    def StPush( self, index ):
        self.Branch_St.append( index )

    def LdPush( self, index ):
        self.Branch_Ld.append( index )

    def StPop( self ):
        return self.Branch_St.pop( -1 )

    def LdPop( self ):
        return self.Branch_Ld.pop( -1 )


def is_StNode( mnemonic ):
    return 'store' in mnemonic[1]


def is_LdNode( mnemonic ):
    return 'load' in mnemonic[1]


def is_LeafNode( mnemonic, index ):
    return 'LEAF' in mnemonic[2]


def GetNeighborNodea( row ):
    NNodes = []
    for index, elm in enumerate( row ):
        if elm == 1:
            NNodes.append( index )
    return NNodes


def GetMnemonic( NodeList, index ):
    return NodeList[ index ]


def SetExplored( em, src_idx, dst_idx ):
    if dst_idx != src_idx:
        em[ src_idx ][ dst_idx ] = 1
        em[ dst_idx ][ src_idx ] = 1
    return em


def GetNonExploredNodes( am, em ):
    cm = am ^ em

    NodeList = []
    for idx, row in enumerate(cm):
        if 1 in row:
            NodeList.append(idx)
    return NodeList


def is_ParentNodeExist( NNodes, index ):
    count = 0
    for node in NNodes:
        if node < index:
            count += 1
    return count


def Explore_Path( am, NodeList ):

    path = Path()

    TotalNumNodes = len( am[0] )
    PtrList = np.zeros( TotalNumNodes, dtype=int )
    em = np.zeros(( TotalNumNodes, TotalNumNodes), dtype=int )

    # Counter
    #   count number of nodes arrived
    CountNodes = 0

    Discon = False

    # Store instruction related path lists
    st_ld_path = []
    st_route_path = []
    st_leaf_path = []

    # Load instruction related path lists
    ld_ld_path = []
    ld_leaf_path = []

    # Path event flags
    start_st = False
    start_ld = False

    # Branch node stack
    Branch = []

    # Node ID (index of Adjacency Matrix)
    index = 0
    tmp_index = 0
    nlist = []

    while CountNodes <= (TotalNumNodes+1) and not Discon:

        if CountNodes > 0 and len(nlist) == 0:
            Discon = True
            break

        if len(NodeList) == 0:
            break

        nlist = GetNonExploredNodes( am, em )
        #print(f"  nlist:{nlist}")

        # Fetch one row
        row = am[ index ]

        # Fetch Neighbot Nodes
        NNodes = GetNeighborNodea( row )

        # Fetch Mnemonic
        mnemonic = GetMnemonic( NodeList, index )

        # Number of Parent Nodes
        num_parent_nodes = is_ParentNodeExist( NNodes, index )

        #print(f"NNodes:{NNodes}  mnemonic:{mnemonic}")

        br = False

        if not is_LeafNode( mnemonic, index ):
            #print(f"  This is NOT LEAF Node: {Branch}")
            if len(NNodes) > 2:
                #print(f"    This is Branch Noode:{NNodes[num_parent_nodes:]}")
                br = True

            # Register  arriving the branch node
            if ( len(NNodes) - num_parent_nodes ) >= 2 and PtrList[ index ] < 1:
                Branch.append( index )
                #print(f"Branch: {Branch}")

            CountNodes += 1
            tmp_index = index

            if is_StNode( mnemonic ) and not start_st:
                # Node is first store instruction
                start_st = True
                path.StPush( index )

                # Register Path Node
                if not start_ld:
                    st_ld_path.append( index )
                st_route_path.append( index )
                st_leaf_path.append( index )

            elif is_StNode( mnemonic ) and start_st:
                # Node is store instruction
                #   support multiple store instructions in a basic block
                start_st = True
                path.StPush( index )

                # Register Path Node
                if not start_ld:
                    st_ld_path.append( index )
                st_route_path.append( index )
                st_leaf_path.append( index )

            elif is_LdNode( mnemonic ) and not start_ld:
                # Node is first load instruction
                start_ld = True
                path.LdPush( index )

                # Register Path Node
                if start_st:
                    st_route_path.append( index )
                    st_leaf_path.append( index )
                    st_ld_path.append( index)
                    #print(f"st_route_path: {st_route_path}")
                    #print(f"st_leaf_path: {st_leaf_path}")
                    #print(f"st_ld_path: {st_ld_path}")
                    path.Register( 'st_ld_path', st_ld_path )
                    st_ld_path = []

                # Register Path Node
                ld_ld_path.append( index )
                ld_leaf_path.append( index )
                #print(f"ld_ld_path: {ld_ld_path}")
                #print(f"ld_leaf_path: {ld_leaf_path}")

            elif is_LdNode( mnemonic ) and start_ld:
                # Node is second load instruction
                start_ld = False
                path.LdPush( index )

                # Register Path Node
                if start_st:
                    st_route_path.append( index )
                    st_leaf_path.append( index )
                    #print(f"st_route_path: {st_route_path}")
                    #print(f"st_leaf_path: {st_leaf_path}")

                # Register Path Node
                ld_ld_path.append( index )
                ld_leaf_path.append( index )
                path.Register( 'ld_ld_path', ld_ld_path )
                #print(f"ld_ld_path: {ld_ld_path}")
                ld_ld_path = []

            else:
                # Node is common instruction
                # Register Path Node
                if start_st:
                    if not start_ld:
                        st_ld_path.append( index )
                        #print(f"st_ld_path: {st_ld_path}")
                    st_route_path.append( index )
                    st_leaf_path.append( index )
                    #print(f"st_route_path: {st_route_path}")
                    #print(f"st_leaf_path: {st_leaf_path}")

                # Register Path Node
                if start_ld:
                    ld_ld_path.append( index )
                    ld_leaf_path.append( index )
                    #print(f"ld_ld_path: {ld_ld_path}")
                    #print(f"ld_leaf_path: {ld_leaf_path}")


            tmp_index = index
            if PtrList[ index ] > len( NNodes ):
                index = Branch.pop(-1)
                CountNodes -= 1
                #print("  Branch Popped")
            elif PtrList[ index ]  >= 2:
                if len(nlist) > 0:
                    index = nlist[0]
                    #print(f"next node={index}")
                else:
                    break
            elif br:
                if num_parent_nodes > 1:
                    #print(f"Fan-out={num_parent_nodes}")
                    index = NNodes[ num_parent_nodes + PtrList[ index ] ]
                    CountNodes -= 1
                else:
                    #print(f"NNodes: {NNodes}, PtrList[ index ]+1:{PtrList[ index ]+1}, index:{index}")
                    index = NNodes[ PtrList[ index ] + 1 ]
                    check_index = NNodes[ PtrList[ index ] ]
                    check_mnemonic = GetMnemonic( NodeList, check_index )
                    if 'load' in check_mnemonic[1]:
                        start_ld = True
            else:
                #print(f"NNodes: {NNodes}, PtrList[ index ]:{PtrList[ index ]}, index:{index}")
                if 'store' in mnemonic[1] or 'load' in mnemonic[1] and len(NNodes) > 2:
                    index = NNodes[ PtrList[ index ] ]
                elif len(NNodes) > 1 and (PtrList[ index ]+1) < len(NNodes):
                    index = NNodes[ PtrList[ index ]  + 1 ]
                else:
                    index = NNodes[ PtrList[ index ] ]

            #print(f"  next node={index}")
            PtrList[ tmp_index ] += 1

            # Set explored node
            em = SetExplored( em, tmp_index, index )

        elif is_LeafNode( mnemonic, index ):
            #print("This is LEAF Node")
            PtrList[ index ] += 1

            # Register Path Node
            tmp_index = index
            if start_st:
                st_route_path.append( index )
                st_leaf_path.append( index )
                path.Register( 'st_route_path', st_route_path )
                path.Register( 'st_leaf_path', st_leaf_path )
                #print(f"st_route_path: {st_route_path}")
                #print(f"st_leaf_path: {st_leaf_path}")
                st_route_path = []
                st_leaf_path = []
                st_ld_path = []

            # Register Path Node
            if start_ld:
                ld_ld_path.append( index )
                ld_leaf_path.append( index )
                path.Register( 'ld_leaf_path', ld_leaf_path )
                #print(f"ld_leaf_path: {ld_leaf_path}")
                ld_ld_path = []
                ld_leaf_path = []
                start_ld = False

            path.Push( index )
            nlist = GetNonExploredNodes( am, em )
            if len(Branch) > 0:
                index = Branch.pop(-1)
            elif len(nlist) > 0:
                index = nlist[0]
            else:
                break
            #print("Branch Popped")

        # Check Remained Node
        #   exit when there is not remained
        #print(em)
        #print(f"CountNodes = {CountNodes}/{TotalNumNodes}")

    return path


def stldpath_formatter( st_ld_paths, st_leaf_paths ):

    reg_st_ld_paths = []

    for st_ld_ptr in range(len(st_ld_paths)):
        st_ld_path = st_ld_paths[st_ld_ptr]
        #print(f"st_ld_path:{st_ld_path}")
        if 0 == st_ld_path[0]:
            reg_st_ld_paths.append(st_ld_path)
            st_ld_path = []
            continue
        else:
            head_id = st_ld_path[0]
            for st_leaf_ptr in range(len(st_leaf_paths)-1, -1, -1):
                st_leaf_path = st_leaf_paths[st_leaf_ptr]
                #print(f"st_leaf_path : {st_leaf_path}")
                if head_id in st_leaf_path and head_id != st_leaf_path[0]:
                    idx = st_leaf_path.index(head_id)
                    st_ld_path = st_leaf_path[:idx]+st_ld_path
                    head_id = st_ld_path[0]

                    if 0 == st_ld_path[0]:
                        reg_st_ld_paths.append(st_ld_path)
                        st_ld_path = []
                        break

    return reg_st_ld_paths

def Gen_Path( am, NodeList, w_path, w_name ):

    path_ = Explore_Path( am, NodeList )

    st_ld_paths = path_.Get( 'st_ld_path' )
    st_leaf_paths = path_.Get( 'st_leaf_path' )
    st_ld_path = stldpath_formatter( st_ld_paths, st_leaf_paths )

    w_path_name = w_path+'/'+w_name+"_bpath_st_root.txt"
    with open(w_path_name, "w") as st_bpath:
        st_bpath.writelines(map(str, path_.Get( 'st_route_path' )))

    w_path_name = w_path+'/'+w_name+"_bpath_st_leaf.txt"
    with open(w_path_name, "w") as st_bpath:
        st_bpath.writelines(map(str, path_.Get( 'st_leaf_path' )))

    w_path_name = w_path+'/'+w_name+"_bpath_st_ld.txt"
    with open(w_path_name, "w") as st_bpath:
        st_bpath.writelines(map(str, st_ld_paths))

    w_path_name = w_path+'/'+w_name+"_bpath_ld_ld.txt"
    with open(w_path_name, "w") as st_bpath:
        st_bpath.writelines(map(str, path_.Get( 'ld_ld_path' )))

    w_path_name = w_path+'/'+w_name+"_bpath_ld_leaf.txt"
    with open(w_path_name, "w") as st_bpath:
        st_bpath.writelines(map(str, path_.Get( 'ld_leaf_path' )))
