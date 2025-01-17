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
			self.st_route_path.append( path[:] )

		elif path_select == 'st_ld_path':
			self.st_ld_path.append( path[:] )

		elif path_select == 'st_leaf_path':
			self.st_leaf_path.append( path[:] )

		elif path_select == 'ld_ld_path':
			self.ld_ld_path.append( path[:] )

		elif path_select == 'ld_leaf_path':
			self.ld_leaf_path.append( path[:] )

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
	return 'LEAF' in mnemonic[3]


def Get_NeighborNode( row ):
	NNodes = []
	for index, elm in enumerate( row ):
		if elm == 1:
			NNodes.append( index )
	return NNodes


def Get_Mnemonic( NodeList, index ):
	return NodeList[ index ]


def Set_Explored( em, src_idx, dst_idx ):
	if dst_idx != src_idx:
		em[ src_idx ][ dst_idx ] = 1
		em[ dst_idx ][ src_idx ] = 1
	return em


def Get_NonExploredNodes( am, em ):
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
	start_ld_ld = False
	start_ld_leaf = False

	# Branch node stack
	Branch = []

	# Node ID (index of Adjacency Matrix)
	index = 0
	tmp_index = 0
	nlist = []

	while CountNodes <= (TotalNumNodes+1) or len(nlist) == 0 or len(NodeList) == 0:

		nlist = Get_NonExploredNodes( am, em )
		#print(f"  nlist:{nlist}")

		# Fetch one row
		row = am[ index ]

		# Fetch Neighbot Nodes
		NNodes = Get_NeighborNode( row )

		# Fetch Mnemonic
		mnemonic = Get_Mnemonic( NodeList, index )

		# Number of Parent Nodes
		num_parent_nodes = is_ParentNodeExist( NNodes, index )

		#print(f"NNodes:{NNodes}  mnemonic:{mnemonic}")

		br = False

		if not is_LeafNode( mnemonic, index ):
			#print(f"  This is NOT LEAF Node: {Branch}")
			if len(NNodes) > 2:
				#print(f"  This is Branch Noode:{NNodes[num_parent_nodes:]}")
				br = True

			# Register arriving the branch node
			if ( len(NNodes) - num_parent_nodes ) >= 2 and PtrList[ index ] < 1:
				Branch.append( int(mnemonic[0]) )
				#print(f"Branch: {Branch}")

			CountNodes += 1
			tmp_index = index

			if is_StNode( mnemonic ) and not start_st:
				# Node is first store instruction
				start_st = True
				path.StPush( index )

				# Register Path Node
				if not start_ld_ld:
					st_ld_path.append( index )
				st_route_path.append( index )
				st_leaf_path.append( index )

			elif is_StNode( mnemonic ) and start_st:
				# Node is store instruction
				#   support multiple store instructions in a basic block
				start_st = True
				path.StPush( index )

				# Register Path Node
				if not start_ld_ld:
					st_ld_path.append( index )
				st_route_path.append( index )
				st_leaf_path.append( index )

			elif is_LdNode( mnemonic ) and not start_ld_ld:
				# Node is first load instruction
				start_ld_ld = True
				start_ld_leaf = True
				path.LdPush( index )

				# Register Path Node
				if start_st:
					st_route_path.append( index )
					st_leaf_path.append( index )
					st_ld_path.append( index)
					#print(f"  st_route_path: {st_route_path}")
					#print(f"  st_leaf_path: {st_leaf_path}")
					#print(f"  st_ld_path: {st_ld_path}")
					path.Register( 'st_ld_path', st_ld_path )
					st_ld_path = []

				# Register Path Node
				ld_ld_path.append( index )
				if index < ld_ld_path[-1]:
					ld_ld_path = []

				ld_leaf_path.append( index )
				#print(f"  ld_ld_path: {ld_ld_path}")
				#print(f"  ld_leaf_path: {ld_leaf_path}")

			elif is_LdNode( mnemonic ) and start_ld_ld:
				# Node is second load instruction

				start_ld_leaf = True
				path.LdPush( index )

				# Register Path Node
				if start_st:
					st_route_path.append( index )
					st_leaf_path.append( index )
					#print(f"  st_route_path: {st_route_path}")
					#print(f"  st_leaf_path: {st_leaf_path}")

				# Register Path Node
				if index < ld_ld_path[-1]:
					ld_ld_path = []
				else:
					ld_ld_path.append( index )
					path.Register( 'ld_ld_path', ld_ld_path )
				ld_leaf_path = [index]
				#print(f"  ld_ld_path: {ld_ld_path}")
				#print(f"  ld_leaf_path: {ld_leaf_path}")
				if len(Branch) > 1:
					append_point = Branch[-1]
					if append_point in ld_ld_path:
						branch_index = ld_ld_path.index(append_point)
						ld_ld_path = ld_ld_path[0:branch_index]
					else:
						ld_ld_path = []
						start_ld_ld = False
				else:
					ld_ld_path = []
					start_ld_ld = False

			else:
				# Node is common instruction
				# Register Path Node
				if start_st:
					if not start_ld_ld:
						if len(st_leaf_path) > 0 and len(Branch) > 0:
							append_no = Branch[-1]
							st_ld_path = st_leaf_path[:append_no+1]
						st_ld_path.append( index )
						#print(f"  st_ld_path: {st_ld_path}")

					st_leaf_path.append( index )
					#print(f"  st_leaf_path: {st_leaf_path}")

					st_route_path.append( index )
					#print(f"  st_route_path: {st_route_path}")

				# Register Path Node
				if start_ld_ld:
					if len(ld_ld_path) > 0 and index < ld_ld_path[-1]:
						ld_ld_path = []
						ld_leaf_path = []

						start_ld_ld = False
					else:
						ld_ld_path.append( index )
						ld_leaf_path.append( index )
					#print(f"  ld_ld_path: {ld_ld_path}")
					#print(f"  ld_leaf_path: {ld_leaf_path}")


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
					check_mnemonic = Get_Mnemonic( NodeList, check_index )
					if 'load' in check_mnemonic[1]:
						start_ld_ld = True
			else:
				#print(f"NNodes: {NNodes}, PtrList[ index ]:{PtrList[ index ]}, index:{index}")
				if 'store' in mnemonic[1] or 'load' in mnemonic[1] and len(NNodes) > 2:
					index = NNodes[ PtrList[ index ] ]
				elif len(NNodes) > 1 and (PtrList[ index ]+1) < len(NNodes):
					index = NNodes[ PtrList[ index ]  + 1 ]
				elif PtrList[ index ] < len(NNodes):
					index = NNodes[ PtrList[ index ] ]
				else:
					index = NNodes[-1]

			if PtrList[ index ] < len(NNodes):
				#print(f"  next node={index}")
				PtrList[ tmp_index ] += 1

			# Set explored node
			em = Set_Explored( em, tmp_index, index )

		elif is_LeafNode( mnemonic, index ):
			#print("  This is LEAF Node")
			PtrList[ index ] += 1

			# Register Path Node
			tmp_index = index
			if start_st:
				st_route_path.append( index )
				st_leaf_path.append( index )
				path.Register( 'st_route_path', st_route_path )
				path.Register( 'st_leaf_path', st_leaf_path )
				#print(f"  st_route_path: {st_route_path}")
				#print(f"  st_leaf_path: {st_leaf_path}")
				st_route_path = []
				st_leaf_path = []

				if len(Branch) > 0:
					append_point = Branch[-1]
					if append_point in st_ld_path:
						branch_index = st_ld_path.index(append_point)
						st_ld_path = st_ld_path[0:branch_index]
						#print(f"  st_ld_path: {st_ld_path}")
				else:
					st_ld_path = []

			# Register Path Node
			#ld_ld_path.append( index )
			if start_ld_leaf:
				#print(f"ld_leaf_path in Leaf:{ld_leaf_path}")
				ld_leaf_path.append( index )
				path.Register( 'ld_leaf_path', ld_leaf_path )
				#print(f"  All registered paths: {path.Get('ld_leaf_path')}")
				ld_leaf_path = []  # クリア
				start_ld_leaf = False
				if start_ld_ld and len(Branch) > 0:
					append_point = Branch[-1]
					if append_point in ld_ld_path:
						branch_index = ld_ld_path.index(append_point)
						ld_ld_path = ld_ld_path[0:branch_index]
						#print(f"  ld_ld_path: {ld_ld_path}")
				elif len(ld_ld_path)>0 and index < ld_ld_path[-1]:
					ld_ld_path = []
					start_ld_ld = False

			path.Push( index )
			nlist = Get_NonExploredNodes( am, em )
			if len(Branch) > 0:
				index = Branch.pop(-1)
			elif len(nlist) > 0:
				index = nlist[0]
			else:
				break
			#print(f"Branch Popped:index={index}")

		# Check Remained Node
		#   exit when there is not remained
		#print(em)
		#print(f"CountNodes = {CountNodes}/{TotalNumNodes}")

	return path

def St_Path_Formatter( paths ):

	for start, chain in enumerate(paths):
		if start+1 < len(paths):
			append_no = start+1
			check_chain = paths[append_no]
			#print(f"append_no:{append_no} chain:{chain} check_chain:{check_chain}")
			for check_node in check_chain:
				if check_node in chain:
					index = chain.index(check_node)
					check_chain = chain[0:index]+check_chain
					paths[append_no] = check_chain
					break

	return paths

def PopList( row, offset ):
	clm_nums = []
	for no, elm in enumerate(row):
		#no = length - no
		if elm == 1:
			clm_nums.append(no + offset)

	return clm_nums

def Get_StPath( am, level, path, row_id ):
	#print(f"node-{row_id} arrive")
	Path = []
	path.append( row_id )
	row_ids = PopList(am[row_id][row_id+1:], row_id+1)
	if len(row_ids) == 0:
		Path = path

	while row_ids:
		#print( row_ids )
		row_id_ = row_ids.pop(0)
		#print(f"path:{path}  row_id:{row_id_}")
		path, Path_ = Get_StPath( am, level+1, path, row_id_ )
		#print(f"node-{row_id} backed, path:{path}")
		if len(row_ids) > 0:
			path = path[0:level+1]
		if len(Path_) > 1:
			Path.append( Path_ )
		else:
			Path = Path_
		#print(f"Path:{Path} path:{path}")

	return path, Path

def Get_StNodeIDs(NodeList):
	node_ids = []
	for no, node in enumerate(NodeList):
		mnemonis = Get_Mnemonic( NodeList, no )
		if 'store' in mnemonis[1]:
			node_ids.append(no)

	return node_ids

def Flatten_List(nested_list):
	flattened = []
	for item in nested_list:
		if isinstance(item, list):
			flattened.extend(Flatten_List(item))
		else:
			flattened.append(item)
	return flattened

def Get_St_Path( am, NodeList ):
	Path = []
	st_node_list = Get_StNodeIDs(NodeList)
	while st_node_list:
		Path_ = []
		path = []
		st_node_id = st_node_list.pop()
		path.append(st_node_id)
		#print(f"st_node_id:{st_node_id}")
		row_ids = PopList(am[st_node_id][st_node_id+1:], st_node_id+1)
		#print(f"row_ids:{row_ids}")
		while row_ids:
			row_id = row_ids.pop(0)
			path, Path_ = Get_StPath( am, 1, path, row_id )
			#print(f"node-{st_node_id} backed, path:{path}")
			path = path[0:1]
			Path.append( Path_ )

	Path = Flatten_List( Path )

	Path_ = []
	path_ = []
	done_st_node = []
	st_node_list = Get_StNodeIDs(NodeList)
	while st_node_list:
		st_node = st_node_list.pop(0)
		for no, node in enumerate(Path):

			if node == st_node:
				path = [st_node]
				for mo, node_ in enumerate(Path[no+1:]):
					#print(f"{mo}:{node_}")
					if node_ != st_node and node_ not in done_st_node:
						path.append(node_)
						#print(f"len(path[no+1:]:{len(path[no+1:])} path:{path}")
						if mo == (len(Path[no+1:])-1):
							path_.append(path)
					else:
						path_.append(path)
						path = [st_node]
						break

		Path_.append(path_)
		path_ = []
		done_st_node.append(st_node)

	if len(Path_) == 1:
		if isinstance(Path_[0], list):
			Path = Path_[0]
	else:
		Path = Path_

	#print(f"end:{Path}")
	return Path

def Fetch_Ld_NodeID(NodeList):
	node_ids = []
	for no, node in enumerate(NodeList):
		mnemonis = Get_Mnemonic( NodeList, no )
		if 'load' in mnemonis[1]:
			node_ids.append(no)

	return node_ids

def Get_St_Ld(paths, NodeList):
	Paths = []
	for path in paths:
		path_ = []
		for node_id in path:
			path_.append(node_id)
			mnemonis = Get_Mnemonic( NodeList, int(node_id) )
			if 'load' in mnemonis[1]:
				break

		Paths.append(path_)

	return Paths

def Gen_StLd_Path( NodeList, st_leaves, st_ld_paths ):

	st_leaves_ = st_leaves
	match_list = []
	for check_st_ld_path in st_ld_paths:
		for mo, st_leaf_path in enumerate(st_leaves):
			Mismatch = False
			if len(st_leaf_path) > len(check_st_ld_path):
				for no in range(len(check_st_ld_path)):
					#print(f"no:{no} check {st_leaf_path[no]} != {check_st_ld_path[no]}")
					if st_leaf_path[no] != check_st_ld_path[no]:
						Mismatch = True
						break
					mnemonic = Get_Mnemonic( NodeList, int(st_leaf_path[no]) )
					#print(f"mnemonic:{mnemonic}")
					if 'load' in mnemonic[1]:
						#print("  matched")
						if mo < len(st_leaves_):
							st_leaves_.pop(mo)
						Mismatch = False
						break

			if Mismatch and mo not in match_list:
				#print(f"break-{mo}")
				match_list.append(mo)

	Path = Flatten_List(st_leaves_)
	#print(Path)

	Path_ = []
	path_ = []
	done_st_node = []
	st_node_list = Get_StNodeIDs(NodeList)
	#print(st_node_list)
	st_node_list_ = st_node_list.copy()
	while st_node_list:
		st_node = st_node_list.pop(0)
		for no, node in enumerate(Path):

			if node == st_node:
				path = [st_node]
				for mo, node_ in enumerate(Path[no+1:]):
					#print(f"{mo}:{node_}")
					if node_ != st_node and node_ not in done_st_node:
						if node_ not in st_node_list_:
							path.append(node_)
						else:
							path_.append(path)
							break
						#print(f"len(path[no+1:]:{len(path[no+1:])} path:{path}")
						if mo == (len(Path[no+1:])-1) and node_ not in st_node_list:
							path_.append(path)
					elif node_ not in st_node_list:
						path_.append(path)
						break

		Path_.append(path_)
		#path_ = []
		done_st_node.append(st_node)

	if len(Path_) >= 1:
		if isinstance(Path_[0], list):
			Path = Path_[0]
	else:
		Path = Path_

	return Path

def Get_StLd_Path(st_leaf_path, NodeList):
	Path_ = []
	for path in st_leaf_path:
		Path = []
		LOAD_EXIST = False
		for path_ in path:
			node_id = path_
			Path.append(node_id)
			mnemonic = Get_Mnemonic( NodeList, int(node_id) )
			#print(mnemonic)
			if 'load' in mnemonic[1]:
				LOAD_EXIST = True
				break

		if LOAD_EXIST:
			if Path not in Path_:
				Path_.append(Path)
				Path = []

	return Path_

def merge(list_a, list_b):

	for item_a in list_a:
		#print(f"item_a:{item_a}")
		for index_b, item_b in enumerate(list_b):
			#print(f"item_b:{item_b}")
			if len(item_a) == len(item_b):
				CHECK = False
				for no in range(len(item_a)):
					if item_a[no] != item_b[no]:
						CHECK = True
						break
				if not CHECK:
					list_b.pop(index_b)

	return list_a + list_b

def Gen_Path( am, NodeList, w_path, w_name ):

	st_leaf_path = Get_St_Path( am, NodeList )
	#print(f"st_leaf_path:{st_leaf_path}")

	explored_path = Explore_Path( am, NodeList )

	st_ld_paths = explored_path.Get( 'st_ld_path' )
	#print(f"st_ld_paths:{st_ld_paths}")
	st_ld_paths = St_Path_Formatter(st_ld_paths)
	#print(f"st_ld_paths:{st_ld_paths}")

	st_leaves = Gen_StLd_Path(NodeList, st_leaf_path, st_ld_paths)
	#print(f"st_leaves:{st_leaves}")

	st_leaf_paths = explored_path.Get( 'st_leaf_path' )
	#print(f"st_leaf_paths-0:{st_leaf_paths}")
	st_leaf_paths = St_Path_Formatter(st_leaf_paths)
	#print(f"st_leaf_paths-1:{st_leaf_paths}")
	st_leaf_paths = merge(st_leaf_paths, st_leaves)
	#print(f"st_leaf_paths-2:{st_leaf_paths}")

	st_ld_remained = Get_StLd_Path(st_leaf_paths, NodeList)
	#print(f"st_ld_remained:{st_ld_remained}")
	
	st_ld_paths = merge(st_ld_paths, st_ld_remained)
	#print(f"st_ld_paths:{st_ld_paths}\n")

	w_path_name = w_path+'/'+w_name+"_bpath_st_root.txt"
	with open(w_path_name, "w") as st_route_path:
		st_route_path.writelines(map(str, explored_path.Get( 'st_route_path' )))

	w_path_name = w_path+'/'+w_name+"_bpath_st_leaf.txt"
	with open(w_path_name, "w") as st_leaf_path:
		st_leaf_path.writelines(map(str, st_leaf_paths ))

	w_path_name = w_path+'/'+w_name+"_bpath_st_ld.txt"
	with open(w_path_name, "w") as st_ld_path:
		st_ld_path.writelines(map(str, st_ld_paths))

	w_path_name = w_path+'/'+w_name+"_bpath_ld_ld.txt"
	with open(w_path_name, "w") as ld_ld_path:
		ld_ld_path.writelines(map(str, explored_path.Get( 'ld_ld_path' )))

	w_path_name = w_path+'/'+w_name+"_bpath_ld_leaf.txt"
	with open(w_path_name, "w") as ld_leaf_path:
		ld_leaf_path.writelines(map(str, explored_path.Get( 'ld_leaf_path' )))
