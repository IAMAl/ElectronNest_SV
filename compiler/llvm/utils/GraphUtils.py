##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################
import copy


def ReadNodeList(r_file_name):

    r_node_list_file_name = r_file_name+"_node_list.txt"
    node_list = []
    with open(r_node_list_file_name, "r") as list:
        for line in list:
            line_ = []
            line = line.split(" ")
            for item in line:
                item = item.replace('\n', '')
                line_.append(item)

            node_list.append(line_)

    return  node_list

class Node:
    def __init__(self, am, am_size, index):
        self.NodeID = index
        self.am_size = am_size

        self.Detect = False

        dest_ids = []
        row = am[index]
        for clm_no, elm in enumerate(row):
            if elm == 1:
                dest_ids.append(clm_no)
        #print("init: Node-{} set destination nodes: {}".format(index, dest_ids))

        self.DestIDs = dest_ids

        self.Term = False

    def Set_MyNodeID(self, id):
        self.NodeID = id

    def Set_DestNodeID(self, row_am):
        for index, elm in row_am:
            self.DestIDs.append(index)

    def Read_DestIDs(self):
        dest_ids = []
        for id in self.DestIDs:
            dest_ids.append(id)
        return dest_ids

    def Set_Term(self):
        self.Term = True

    def Check_Term(self):
        #if self.Term:
        #    print("Node-{} is ended".format(self.NodeID))
        #else:
        #    print("Node-{} runs".format(self.NodeID))
        return self.Term

    def Set_Detect(self):
        self.Detect = True

    def Check_Detect(self):
        return self.Detect


def GetShape(lst):
    shape = []
    if isinstance(lst, list):
        shape.append(len(lst))
        if lst:
            shape.extend(GetShape(lst[0]))
    return shape


def AppendLowestList(my_id, lst):
    check = False
    temp = []
    if isinstance(lst, list):
        for lst_ in lst:
            #print("test:{}".format(lst_))
            rtn_lst, check = AppendLowestList(my_id, lst_)

        if not check:
            temp.append(lst_)

        if check:
            return lst.append(my_id), False
        else:
            return temp, False
    else:
        return lst, True


def RemoveList(lst):
    #print("Try to remove: {}".format(lst))
    if isinstance(lst, list):
        temp = []
        for lst_ in lst:
            if isinstance(lst_, list):
                if len(lst_) == 0:
                    return []

                lst_ = RemoveList(lst_)

            temp.append(lst_)

        return temp

    return lst


class EdgeTab:
    def __init__(self, am_size):
        self.am_size = am_size

        brank1 = []
        for _ in range(am_size):
            brank1.append([])
        brank2 = []
        for _ in range(am_size):
            brank2.append([])

        edges = []
        edges.append(brank1)
        edges.append(brank2)
        self.Edges = edges

    def Read(self, read_no, my_id):
        edges = self.Edges[read_no][my_id]
        self.Edges[read_no][my_id] = []
        return edges

    def Write(self, write_no, my_id, dest_ids, edges):
        #print("  >Write ID-{} in {}".format(my_id, edges))
        shape = GetShape(edges)
        if len(shape) == 1 and len(edges) == 0:
            for dest_id in dest_ids:
                self.Edges[write_no][dest_id].append([my_id])
                #print("  Dest Node-{}: {}".format(dest_id, self.Edges[write_no][dest_id]))
        elif len(shape) == 1 and len(edges) > 0:
            edges.append(my_id)
            for dest_id in dest_ids:
                self.Edges[write_no][dest_id].append(edges)
                #print("  Dest Node-{}: {}".format(dest_id, self.Edges[write_no][dest_id]))
        else:
            edges_, _ = AppendLowestList(my_id, edges)
            for dest_id in dest_ids:
                #print("  Dest Node-{}: {}".format(dest_id, edges_))
                self.Edges[write_no][dest_id].append(edges_)

    def Dump(self, my_id):
        for index, edges in enumerate(self.Edges):
            print("no-{} {}".format(index, edges))


def CheckEcho(node_id, edges):

    if isinstance(edges, list):
        temp = []
        for edges_ in edges:
            #print("  Check Echo for Node-{}: {}".format(node_id, edges))
            edge, check = CheckEcho(node_id, edges_)
            if check:
                #print("  Echo is Detected for Node-{}: {}".format(node_id, edge))
                break
            elif isinstance(edge, list) and len(edge) > 0:
                temp.append(edge)
            elif isinstance(edge, int):
                temp.append(edge)

        return temp, False
    else:
        return edges, edges == node_id


def CheckCycle(cycles, node_id, edges, first, last_level, level):

    if isinstance(edges, list):
        #print("  Check Cyclic Loop for Node-{}: {} at Level-{}".format(node_id, edges, level))
        temp = []
        level += 1
        first = True
        for edges_ in edges:
            cycles, edge, check, first, last_level, level = CheckCycle(cycles, node_id, edges_, first, last_level, level)

            if check and first and len(edges) > 2:
                cycles.append(edges)
                #print("  Cyclic-Loop Detected on Nodes: {} in List: {} at Level-{}".format(node_id, edges, level))
                break
            elif isinstance(edge, list) and len(edge) > 0:
                temp.append(edge)
            elif isinstance(edge, int):
                temp.append(edge)
            else:
                temp.append(edge)

            if last_level:
                first = False
            else:
                first = True


        level -= 1


        return cycles, temp, False, first, False, level
    else:
        #if edges == node_id:
        #    print("  Cyclic-Loop Detected on Nodes: {} at Level-{}".format(node_id, edges, level))
        return cycles, edges, edges == node_id, first, True, level


def CheckEmpty(node_id, edges):

    if isinstance(edges, list):
        if len(edges) == 0:
            #print("  Empty Detected on Nodes: {}".format(node_id))
            return True
        else:
            return False
    else:
        True


def NodeParser( Paths_, mode ):
    """
    Parser

    Arguments
        Paths_:     Set of Paths (list type)
        mode:       Parsing mode
                        'dfg'       Data-Flow Graph
                        otherwise   Control-Flow Graph
    """
    if mode == 'dfg':
        Paths = []
        num = 0
        for path_ in Paths_:
            path = []
            nodes = path_.split("][")
            if len(nodes) > 1:
                for node_infos in nodes:
                    node_infos = node_infos.replace("[", '')
                    node_infos = node_infos.replace("]", '')
                    node_infos = node_infos.replace("'", '')
                    node_infos = node_infos.replace(",", '')
                    node_infos = node_infos.split(" ")

                    node_info = []
                    for item in node_infos:
                        node_info.append(item)

                    path.append(node_info)

                Paths = path

            else:
                nodes = path_.split(", ")
                for node_info in nodes:
                    node_info = node_info.replace("[", '')
                    node_info = node_info.replace("]", '')
                    node_info = node_info.replace("'", '')
                    node_info = node_info.replace(",", '')

                    path.append(node_info)

                Paths.append(path)
            num += 1

    else:
        Paths = []
        for line in Paths_:
            line = line.split('], [')

            for path_ in line:
                path_ = path_.split(', ')
                path = []
                for node_id in path_:
                    node_id = node_id.replace("'", '')
                    node_id = node_id.replace("[", '')
                    node_id = node_id.replace("]", '')
                    node_id = node_id.replace("[]", '')
                    node_id = node_id.replace("][", '')
                    node_id = node_id.replace(",", '')
                    path.append(node_id)

                Paths.append(path)
    return Paths


class Create_CFGNode:
    """
    Node Class

    Role:
        Node having Data Structure for Control-Flow Graph.
    """
    def __init__( self ):
        self.ID = ""
        self.StLdPaths = []
        self.NeighborNodes = []
        self.Explored = False
        self.num_paths = 0
        self.num_nodes = 0
        self.read_cnt = 0
        self.read_ptr = 0


    def ReadNeighborExplored( self ):
        """
        Read Neighbor's Explored Flag
        """
        return self.NeighborNodes[1][1]


    def ReadPathNo( self, Src, Dst, index ):
        """
        Read Path Number
        """
        if self.read_cnt == self.num_paths:
            return index, Src, Dst, False

        if self.read_ptr == self.num_paths:
            return index, Src, Dst, False

        for no, StLdPath in enumerate(self.StLdPaths):
            if not StLdPath[1]:
                for st_no in StLdPath[2][Dst]:
                    for id in st_no:
                        if id == index:
                            self.StLdPaths[no][1] = True
                            self.read_cnt += 1
                            return index, Src, Dst, no

        for no, StLdPath in enumerate(self.StLdPaths):
            if not StLdPath[1]:
                for st_no in StLdPath[2][Src]:
                    for id in st_no:
                        if id == index:
                            self.StLdPaths[no][1] = True
                            self.read_cnt += 1
                            return index, Src, Dst, no

        temp_ptr = self.read_ptr
        for no, StLdPath in enumerate(self.StLdPaths):
            if not StLdPath[1]:
                self.StLdPaths[no][1] = True
                if self.read_ptr < self.num_paths:
                    self.read_ptr += 1
                if Src == Dst:
                    return self.StLdPaths[no][2][Src][0][0], Src, Dst^1, no
                else:
                    return self.StLdPaths[no][2][Src][0][0], Src, Dst, no

        return -1, Src, Dst, False


    def ClrExplores( self ):
        """
        Clear Explore Flag
        """
        for StLdPath in self.StLdPaths:
            StLdPath[1] = False

    def ReadNumPaths( self ):
        """
        Read Number of Paths in Node
        """
        return self.num_paths

    def SetNodeID( self, ID ):
        """
        Set This Node's ID
        """
        self.ID = ID

    def ReadNodeID( self ):
        """
        Read This Node's ID
        """
        return self.ID

    def ReadNumNodes( self ):
        """
        Read Number of Neighbor Nodes
        """
        return self.num_nodes

    def SetExplored( self ):
        """
        Set Flag of Explored
            The flag is set at read node
        """
        self.Explored = True

    def ClrExplored( self ):
        """
        Clear Flag of ExploredX
        """
        self.Explored = False

    def ReadExplored( self ):
        """
        Read Flag of Explored
        """
        return self.Explored

    def SetNeighborNode( self, node_id ):
        """
        Set Neighbor Node's ID,
        Initialize Flag-Explored
        """
        self.NeighborNodes.append([node_id, False])
        self.num_nodes += 1

    def SetNeigboorNode( self, node_id ):
        """
        Set Neighbor's Node-ID
        Set Valid Flag
        """
        for neighbor_node in self.NeighborNodes:
            if neighbor_node[0] == node_id:
                neighbor_node[1] = True

    def ClrNeigboorNode( self, node_id ):
        """
        Clear Neighbor's Valid Flag
        """
        for neighbor_node in self.NeighborNodes:
            if neighbor_node[0] == node_id:
                neighbor_node[1] = False

    def SetStLdPaths( self, path ):
        """
        Register Path inside of This Node
        path:   DFG-Path
        False:  Init Flag for Path-Explored
        []:     Init Set of Store and Load Indeces
        """
        self.StLdPaths.append([copy.deepcopy(path), False, [[], []]])
        self.num_paths += 1

    def ReadStLdPaths( self ):
        """
        Read Set (List) of Store-Load Paths
        """
        return self.StLdPaths

    def ReadStLdPath( self, path_no ):
        """
        Read Store-Load Path
        """
        return self.StLdPaths[path_no]

    def CheckStLdPaths( self, src ):
        """
        Check Availability of Source Register Index in Store-Load Path
        """
        Chk_Src = False
        for StLdPath in self.StLdPaths:
            for src_indices in StLdPath[2][src]:
                for src_index in src_indices:
                    if src_index > 0:
                        Chk_Src = True
        return Chk_Src

    def ReadStLdPathExplored( self, path_no ):
        """
        Read Explored-Flag of This Node's Path
        """
        return self.StLdPaths[path_no][1]


    def SetStLdIndex( self, path_no, st, index ):
        """
        Set Store/Load Indeces to Path[path_no]
            st = 0:     Store
            ld = 1:     Load
        """
        self.StLdPaths[path_no][2][st].append(index)

    def ReadStLdIndex( self, path_no, st ):
        """
        Read Path[path_no]
            st = 0:     Store
            ld = 1:     Load
        """
        return self.StLdPaths[path_no][2][st]

    def CheckExplored( self, node_id ):
        """
        Check Explored Flag and Valid Flags
        """
        for neigbor_node in self.NeighborNodes:
            if neigbor_node[0] == node_id:
                return True, neigbor_node[1]

        return False, False

    def CheckAllExplored( self ):
        """
        Check Explored Flag and Valid Flags
        """
        for neigbor_node in self.NeighborNodes:
            if neigbor_node[1]:
                return True, True

        return False, False

    def ClrNeigboorNodes( self ):
        """
        Clear Neibor Node;s Explored Flag
        """
        for neigbor_node in self.NeighborNodes:
            neigbor_node[1] = False


class Create_CFGNodes:
    """
    Control Flow Graph Class

    Role:
        Structure of Graph
    """
    def __init__(self):
        self.path_ptr = 0
        self.node_ptr = 0
        self.nums = 0
        self.nodes = []

    def ReadInitNode(self):
        self.node_ptr += 1
        if self.node_ptr <= len(self.nodes):
            return True, self.nodes[self.node_ptr-1]
        else:
            return False, -1

    def SetNode(self, node):
        """
        Register Node
        """
        self.nodes.append(copy.deepcopy(node))
        self.nums += 1

    def ReadNode(self, node_no):
        """
        Read Node
        """
        if node_no < len(self.nodes):
            return self.nodes[node_no]
        else:
            return self.nodes[0]

    def SetExplored(self, node_id):
        """
        Set Explored Flag to Node
        """
        for index, node in enumerate(self.nodes):
            if node.ReadNodeID() == node_id:
                self.nodes[index].SetExpored()

    def ReadExplored(self, node_id):
        """
        Check node_id is already explored
        """
        for node in self.nodes:
            if node.ReadNodeID() == node_id:
                return node.ReadExplored()

        return False

    def ClrAllExplored(self):
        """
        Clear Explored Flag for All
        """
        for node in self.nodes:
            node.ClrExplored()

    def ReadNum(self):
        """
        Read Number of (CFG) Nodes
        """
        return self.nums

    def SetStLdPaths(self, node_id, path):
        """
        Set Path to Node[node_id]
        """
        for node in self.nodes:
            if node.ReadNodeID() == node_id:
                node.SetStLdPaths(path)
                self.path_ptr += 1

    def SetStLdIndex(self, node_id, st, index):
        """
        Set Indeces to Node[node_id]
            st = 0:     Store
            st = 1:     Load
        """
        for node in self.nodes:
            if node.ReadNodeID() == node_id:
                node.SetStLdIndex(node.num_paths-1, st, index)

    def ReadCFGNode(self, cycle_no):
        """
        Read (CFG) Node
        """
        return self.nodes[cycle_no]


    def Reorder(self):
        nodes = []
        for index in range(self.nums-1, -1, -1):
            nodes.append(self.nodes[index])

        self.nodes = nodes

    def ReadNumNodes(self):
        """
        Read Number of (CFG) Nodes
        """
        return self.nums