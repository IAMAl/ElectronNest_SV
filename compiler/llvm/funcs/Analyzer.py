##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################
from typing import TypedDict, List, Dict, Tuple, Optional, Set, Union, Any
from dataclasses import dataclass
import os
import utils.AMUtils as AMUtils
import re
from typing import List, Optional
import functools


@dataclass
class RegisterInfo:
	regs: List[str]			# Register's name
	array_dim: int			# Array Dimension

@dataclass
class PointerInfo:
	block_id: str			# Basic Block ID
	gep_node_id: List[str]	# getelementptr Node-ID
	array_name: str			# Array Name
	index_regs: RegisterInfo

@dataclass
class MemoryOp:
	reg_addr: str			# Register index used for Address
	reg_val: str			# REgister index used for Value

@dataclass
class LoopInfo:
	nodes: List[str]		# Loop CFG Nodes
	header: str				# Loop Header
	exit: str				# Exit Node
	parent: str				# Parent Node-ID
	children: List[str]		# Child Node-ID
	array_dims: Dict[str, int]	# {Array Name: Access Dim}

@dataclass
class DimensionAccess:
	dimension: int			# Access Dim
	loop_level: str			# Loop Level
	array_size: int			# Dim Size

@dataclass
class ArrayDimInfo:
	array_name: str						# Array Name
	dim_accesses: List[DimensionAccess]	# Dim Info

class IndexExpression:
	base: str					# Base address of the array
	path: List[int]				# List of *node IDs* that compute the index
	source_variables: List[str]	# Source variable for this index expression.

class Analyzer:
	def __init__(self, r_file_path: str, r_file_name: str):
		self.r_path = r_file_path
		self.r_name = r_file_name
		self.loops = self._read_loop_structure()
		self.array_patterns: Dict = {}
		self.pointer_regs_info: Dict = {}
		self.store_load_deps: Dict = {}
		self.cfg_connectivity: Dict = {}
		self._node_list_cache = {}
		self._am_cache = {}
		self._gep_chain_cache = {}
		self.nodes_cache = {}
		all_nodes, node_to_block = self._collect_all_nodes()
		self.all_nodes = all_nodes
		self.node_to_block = node_to_block
		self.loop_levels = self._analyze_loop_levels()

	def _collect_all_nodes(self):
			"""全ての基本ブロックのノード情報を収集し、node_to_blockも作成"""
			all_nodes = {}
			node_to_block = {}
			try:
				block_ids = self._get_all_block_ids()

				for block_id in block_ids:
					nodes = self._read_node_list(block_id)
					if nodes is None:
						continue
					all_nodes[block_id] = nodes
					for node in nodes:
						node = node[0].split()
						if node and node[0].isdigit():
							node_to_block[node[0]] = block_id

				return all_nodes, node_to_block
			except Exception as e:
				print(f"Error collecting all nodes: {e}")
				return {}

	def _get_all_block_ids(self):
		"""全ての基本ブロックIDを取得する"""
		try:
			cfg_loop_file = os.path.join(self.r_path, f"{self.r_name}_cfg_loop.txt")
			cfg_loop_file = os.path.join(self.r_path, f"mmm_cfg_loop.txt")
			if not os.path.exists(cfg_loop_file):
				print(f"Warning: CFG loop file not found: {cfg_loop_file}")
				return []

			block_ids = []
			with open(cfg_loop_file, 'r') as f:
				import ast
				loops = ast.literal_eval(f.read())
				block_ids = list(set([block_id for loop in loops for block_id in loop]))
			return block_ids

		except FileNotFoundError:
			print(f"Error: CFG loop file not found: {cfg_loop_file}")
			return []
		except (SyntaxError, ValueError) as e:
			print(f"Error parsing CFG loop file: {e}")
			return []
		except Exception as e:
			print(f"An unexpected error occurred: {e}")
			return []

	@functools.lru_cache(maxsize=128)
	def _read_node_list(self, block_id: str) -> List[List[str]]:
		"""
		基本ブロックのノードリストを読み込み

		Args:
			block_id: 基本ブロックID

		Returns:
			List[List[str]]: [
				[node_id, opcode, operands..., LEAF],  # LEAFノード
				[node_id, opcode, operands...],        # 通常ノード
				...
			]
			各ノードの情報を配列として返す
			- LEAFノードは最後の要素が"LEAF"
			- 通常ノードはオペコードとオペランドのリスト
		"""
		if block_id in self.nodes_cache:
			return self.nodes_cache[block_id]

		try:
			file_path = os.path.join(self.r_path, f"{self.r_name}_bblock_{block_id}_node_list.txt")
			if not os.path.exists(file_path):
				print(f"Warning: Node file not found: {file_path}")
				return []

			nodes: List[List[str]] = []
			with open(file_path, 'r') as f:
				for line in f:
					node = line.strip().split(',')
					nodes.append(node)

			self.nodes_cache[block_id] = nodes
			return nodes

		except Exception as e:
			print(f"Error reading node list from {file_path}: {e}")
			return []

	def _read_path_file(self, block_id: str, path_type: str) -> List[str]:
		"""パスファイルの読み込み"""
		try:
			path_file = os.path.join(self.r_path,
				f"{self.r_name}_bblock_{block_id}_bpath_{path_type}.txt")
			if not os.path.exists(path_file):
				return []
			with open(path_file, 'r') as f:
				return f.readlines()
		except Exception:
			return []

	def _path_formatter(self, paths: List[str]) -> List[List[List[str]]]:
		"""
		パス情報のフォーマット処理
		Args:
			paths: パス情報の文字列リスト
				例: ["[1,2,3][4,5,6]", "[7,8,9][10,11,12]"]
		Returns:
			List[List[List[str]]]: [
				[["1","2","3"], ["4","5","6"]],  # 1つ目のパス
				[["7","8","9"], ["10","11","12"]] # 2つ目のパス
			]
		"""
		try:
			formatted_paths = []

			for path in paths:
				if not path.strip():
					continue

				current_path = []
				path_segments = path.split(']')

				for segment in path_segments:
					if not segment.strip():
						continue

					node_ids = segment.replace('[', '').strip()
					if node_ids:
						nodes = [n.strip() for n in node_ids.split(',')]
						nodes = [n for n in nodes if n]
						if nodes:
							current_path.append(nodes)

				if current_path:
					formatted_paths.append(current_path)

			return formatted_paths

		except Exception as e:
			print(f"Error in path formatter: {e}")
			return []

	def _path_formatter2(self, path: str) -> List[List[str]]:
			"""
			パス情報のフォーマット処理 (文字列またはリストに対応)
			"""
			try:
				formatted_path = []
				if not path:
					return formatted_path

				if isinstance(path, str):
					segments = path.split('[')[1:]

					for segment in segments:
						node_ids = segment.replace(']', '').replace(' ', '')
						if node_ids:
							nodes = node_ids.split(',')
							nodes = [n for n in nodes if n]
							if nodes:
								formatted_path.append(nodes)
				elif isinstance(path, list):
					formatted_path.append([str(n) for n in path])
				else:
					print(f"Warning: Invalid path type: {type(path)}")
					return []

				return formatted_path

			except Exception as e:
				print(f"Error in path formatter2: {e}")
				return []

	def _format_path(path_str: Optional[str]) -> List[List[str]]:
		"""
		Formats a path string into a list of node ID lists.

		Handles both single and multiple path strings.

		Args:
			path_str: The path string to format (e.g., "[1,2,3][4,5,6]" or "[[1,2,3][4,5,6]][[7,8][9]]").
				Can be None or empty.

		Returns:
			A list of lists of node IDs, or an empty list if the input is invalid.
			For example:
				_format_path("[1,2,3][4,5,6]") == [["1", "2", "3"], ["4", "5", "6"]]
				_format_path("[[1,2][3]][[4,5]]") == [["1","2"], ["3"]], [["4","5"]]
				_format_path("") == []
				_format_path(None) == []
		"""
		if not path_str or not path_str.strip():
			return []

		paths = path_str.split('][')
		formatted_paths: List[List[List[str]]] = []
		for path in paths:
			path = path.strip('[]')

			formatted_path: List[List[str]] = []
			segments = re.findall(r"\[([^\]]+)\]", path)
			for segment in segments:
				nodes = [node.strip() for node in segment.split(',') if node.strip()]
				if nodes:
					formatted_path.append(nodes)
			if formatted_path:
				formatted_paths.append(formatted_path)

		if len(formatted_paths) == 1:
			return formatted_paths[0]
		return formatted_paths

	def _find_begin_geps(self, block_id: str) -> List[Dict[str, Any]]:
		"""
		始端getelementptrノードの特定
		Args:
			block_id: 基本ブロックID
		Returns:
			[
				{
					'array_name': str,     # 配列名
					'path_no': int,        # パス番号
					'gep_node_id': str,    # GEPノードID
					'begin_node_id': str   # 始端ノードID
				}
			]
		デフォルト値：[{"array_name": "", "path_no": 0, "gep_node_id": "0", "begin_node_id": "0"}]
		"""
		begin_geps = []
		default_gep = {
			"array_name": "",
			"path_no": 0,
			"gep_node_id": "0",
			"begin_node_id": "0"
		}

		try:
			# 1. ノード情報の取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return [default_gep]

			# 2. ld-to-ldパスファイルの読み込みと解析
			ld_ld_path = os.path.join(self.r_path,
				f"{self.r_name}_bblock_{block_id}_bpath_ld_ld.txt")

			if not os.path.exists(ld_ld_path):
				return [default_gep]

			with open(ld_ld_path, 'r') as f:
				ld_ld_paths = f.readlines()

			if not ld_ld_paths:
				return [default_gep]

			# 3. パス情報の解析
			paths = self._path_formatter(ld_ld_paths)[0]
			if not paths or not paths[0]:
				return [default_gep]

			# 4. 各パスの解析
			for list_no, path in enumerate(paths):
				if not path:
					continue

				begin_node_id = path[-1].strip()
				if not begin_node_id:
					continue

				# 5. パス内のGEPノード探索
				BREAK = False
				for node_id in reversed(path):
					node_id = node_id.strip()
					if not node_id or not node_id.isdigit():
						continue

					node_idx = int(node_id)
					if node_idx >= len(nodes):
						continue

					# 6. getelementptrノードの判定
					node = nodes[node_idx][0]
					if len(node) < 1:
						continue

					opcode = node.split()[1]
					if 'getelementptr' in opcode:
						array_name = None

						# 形式1, 2に対応 (@<array_name>)
						match = re.search(r"@(\w+)", node)
						if match:
							array_name = match.group(1).split('_')[0]

						# 形式3に対応 (getelementptr_<array_name>)
						if array_name is None:  # @形式で見つからなかった場合
							match = re.search(r"getelementptr_([a-zA-Z0-9_]+)", node)
							if match:
								array_name = match.group(1).split('_')[0]

						# 配列名が見つからなくても情報を保持
						begin_geps.append({
							"array_name": array_name,	# None の場合もあり
							"path_no": list_no,
							"gep_node_id": node_id,
							"begin_node_id": begin_node_id
						})
						break

			return begin_geps if begin_geps else [default_gep]

		except Exception as e:
			print(f"Error in _find_begin_geps for block {block_id}: {e}")
			return [default_gep]

	def _find_terminal_geps(self,
			block_id: str,
			gep_nodes: List[Tuple[int, List[str]]]) -> List[Tuple[int, List[str]]]:
		"""
		終端getelementptrノードの特定
		Args:
			block_id: 基本ブロックID
			gep_nodes: [(行番号, ノード情報), ...] 形式のgetelementptrノードリスト
		Returns:
			[(行番号, ノード情報), ...] 形式の終端GEPノードのリスト
		"""
		terminal_geps = []

		try:
			# 1. ノードリストの読み込み
			nodes = self._read_node_list(block_id)
			if not nodes:
				return terminal_geps

			# 2. AMファイルの読み込みと処理
			am_file = f"{self.r_name}_bblock_{block_id}"
			am_size, am = AMUtils.Preprocess(self.r_path, am_file)

			# 3. 各getelementptrノードの解析
			for gep in gep_nodes:
				gep_line = gep[0]
				# 接続先を探索
				for dst_idx in range(am_size):
					if am[gep_line][dst_idx]:
						# 接続先のノードを確認
						if dst_idx >= len(nodes):
							continue

						dst_node = nodes[dst_idx][0].split()
						if len(dst_node) > 1:
							# load/store命令に接続している場合は終端GEPと判定
							if 'load' in dst_node[1] or 'store' in dst_node[1]:
								terminal_geps.append(gep)
								break

							# 別のGEPに接続している場合はチェーンの一部
							if 'getelementptr' in dst_node[1]:
								continue

			return terminal_geps

		except Exception as e:
			print(f"Error in _find_terminal_geps for block {block_id}: {e}")
			print(f"Context - GEP nodes: {len(gep_nodes)}")
			return terminal_geps

	def _find_forward_loads(self,
			target_block: str,
			store_reg: str,
			store_line: int,
			source_block: str,
			loop_nodes: List[str]) -> Dict:
		"""
		CFG順方向でのload命令検索
		Args:
			target_block: 検索対象ブロック
			store_reg: 検索対象レジスタ
			store_line: store命令の行番号
			source_block: ソースブロック
			loop_nodes: ループノード群
		Returns:
			{
				'loads': [
					{
						'line_num': int,
						'is_loop_edge': bool,
						'edge_type': str
					}
				]
			}
		"""
		result = {'loads': []}

		try:
			# 1. ターゲットブロックのノード情報取得
			node_info = self._read_node_list(target_block)
			if not node_info:
				return result

			# 2. ループエッジの判定
			is_loop_edge = False
			edge_type = 'normal'
			if source_block == loop_nodes[0] and target_block == loop_nodes[-1]:
				is_loop_edge = True
				edge_type = 'loop_forward'
			elif source_block == loop_nodes[-1] and target_block == loop_nodes[0]:
				is_loop_edge = True
				edge_type = 'loop_back'

			# 3. load命令の検索
			for line_num, node in enumerate(node_info):
				node = node[0].split()
				if len(node) < 2:
					continue
				if 'load' in node[1] and store_reg in node[3]:
					load_info = {
						'line_num': line_num,
						'is_loop_edge': is_loop_edge,
						'edge_type': edge_type
					}
					result['loads'].append(load_info)

			return result

		except Exception as e:
			print(f"Error finding forward loads in block {target_block}: {e}")
			return result

	def _collect_memory_ops(self,
			node_info: List[List[str]],
			reg_list: List[str]) -> Tuple[Dict[int, MemoryOp], Dict[int, MemoryOp]]:
		"""
		store/load命令の収集
		Args:
			node_info: ノードの情報リスト [[opcode, operands...], ...]
			reg_list: 対象レジスタのリスト
		Returns:
			stores: {
				line_num: MemoryOp(reg_addr=str, reg_val=str)
				# store命令の行番号をキーとするメモリ操作情報
			}
			loads: {
				line_num: MemoryOp(reg_addr=str, reg_val=str)
				# load命令の行番号をキーとするメモリ操作情報
			}
		"""
		stores: Dict[int, MemoryOp] = {}
		loads: Dict[int, MemoryOp] = {}

		try:
			# 入力パラメータの検証
			if not node_info or not reg_list:
				return stores, loads

			# 各ノードの解析
			for line_num, node in enumerate(node_info):
				node = node[0].split()
				if len(node) < 2:
					continue

				# レジスタ使用の確認
				if not any(reg in str(node) for reg in reg_list):
					continue

				# store命令の解析
				if 'store' in node[1]:
					if len(node) >= 5:			# store命令は最低5つの要素が必要
						stores[line_num] = MemoryOp(
							reg_addr=node[3],	# アドレスレジスタ
							reg_val=node[4]		# 格納値レジスタ
						)

				# load命令の解析
				elif 'load' in node[1]:
					if len(node) >= 4:			# load命令は最低4つの要素が必要
						loads[line_num] = MemoryOp(
							reg_addr=node[3],	# アドレスレジスタ
							reg_val=node[2]		# 格納先レジスタ
						)

			return stores, loads

		except Exception as e:
			print(f"Error collecting memory operations: {e}")
			print("Context - Node info length:", len(node_info), "Reg list length:", len(reg_list))
			return stores, loads

	def _read_loop_structure(self) -> List[List[str]]:
		"""
		ループ構造情報の読み込みと解析

		Returns:
			List[List[str]]: [
				[node_id, ...],  # 最内ループ
				[node_id, ...],  # 中間ループ
				[node_id, ...],  # 最外ループ
			]
			内側から外側のループの順でノードIDのリストを返す
		"""
		try:
			# 1. ループ構造ファイルの読み込み
			loop_file_path = os.path.join(self.r_path, f"{self.r_name}_cfg_loop.txt")
			if not os.path.exists(loop_file_path):
				return []

			with open(loop_file_path, 'r') as f:
				content = f.read().strip()
				if not content:
					return []

			# 2. ループ構造の解析
			content = content.strip('[]')
			loop_strs = content.split('],')
			loops = []

			# 3. 各ループの処理
			for loop_str in loop_strs:
				loop_str = loop_str.replace('[', '').replace(']', '')
				nodes = []

				# ループノードの抽出
				for node in loop_str.split(','):
					node = node.strip().strip("'").strip('"')
					if node:  # 空のノードは除外
						nodes.append(node)

				if nodes:  # 空のループは除外
					loops.append(nodes)

			# 4. ループの検証
			validated_loops = []
			for loop in loops:
				# 各ループが最低2つのノードを持つことを確認
				if len(loop) >= 2:
					validated_loops.append(loop)
				else:
					print(f"Warning: Invalid loop structure detected: {loop}")

			return validated_loops

		except Exception as e:
			print(f"Error reading loop structure: {e}")
			return []

	def _analyze_loop_levels(self) -> Dict[str, LoopInfo]:
		result: Dict[str, LoopInfo] = {}

		try:
			if not self.loops:
				print("No loops found in the program")
				return result

			print(f"  Analyzing loop structure:")
			print(f"    Found {len(self.loops)} loop levels")

			for idx, loop_nodes in enumerate(reversed(self.loops)):
				level = str(len(self.loops) - idx)
				print(f"\n    Analyzing loop level {level}:")
				print(f"      Nodes: {loop_nodes}")

				parent_level = str(int(level) + 1) if int(level) < len(self.loops) else ""
				children_levels = [str(int(level) - 1)] if int(level) > 1 else []

				array_dims = self._collect_array_dimensions_for_loop(loop_nodes)
				print(f"      Array dimensions: {array_dims}")

				result[level] = LoopInfo(
					nodes=loop_nodes,
					header=loop_nodes[0],
					exit=loop_nodes[-1],
					parent=parent_level,
					children=children_levels,
					array_dims=array_dims
				)

			return result

		except Exception as e:
			print(f"Error analyzing loop levels: {e}")
			return result

	def _collect_array_dimensions_for_loop(self, loop_nodes: List[str]) -> Dict[str, Dict[str, int]]:
		"""ループ内の配列アクセス次元を収集"""
		array_dims = {}
		try:
			for block_id in loop_nodes:
				nodes = self._read_node_list(block_id)
				if not nodes:
					continue

				for node in nodes:
					node = node[0].split()
					if 'getelementptr' in str(node[1]):
						array_match = re.search(r'@([a-zA-Z0-9_]+)', str(node[1]))
						if array_match:
							array_name = array_match.group(1)
							# インデックスの解析
							dim_info = self._analyze_array_dimension_from_gep(node)
							if dim_info:
								array_dims[array_name] = dim_info

			return array_dims

		except Exception as e:
			print(f"Error collecting array dimensions: {e}")
			return {}

	def _analyze_array_dimension_from_gep(self, node: List[str]) -> Optional[Dict[str, int]]:
		"""getelementptrからアクセスされる配列の次元を分析"""
		try:
			# インデックス計算の解析
			for i, token in enumerate(node):
				if token.startswith('%') and token != '%0':
					# このインデックスが何次元目のアクセスに使用されているか判断
					dimension = self._determine_index_dimension(node, i)
					if dimension >= 0:
						size = self._get_dimension_size(node, dimension)
						return {
							'dimension': dimension,
							'size': size
						}
			return None

		except Exception as e:
			print(f"Error analyzing array dimension from GEP: {e}")
			return None

	def _determine_index_dimension(self, node: List[str], index_position: int) -> int:
		"""
		getelementptrのインデックスが何次元目のアクセスに使用されているか判断
		Args:
			node: getelementptrノードの情報
			index_position: インデックスの位置
		Returns:
			次元番号（0から開始）または-1（エラー時）
		"""
		try:
			# getelementptrの型情報からインデックスの次元を判断
			dimension_count = 0
			for i, token in enumerate(node):
				if token.startswith('%') and token != '%0':
					if i == index_position:
						return dimension_count
					dimension_count += 1
			return -1

		except Exception as e:
			print(f"Error determining index dimension: {e}")
			return -1

	def _get_dimension_size(self, node: List[str], dimension: int) -> int:
		"""
		配列の指定された次元のサイズを取得
		Args:
			node: getelementptrノードの情報
			dimension: 次元番号
		Returns:
			次元のサイズまたは0（エラー時）
		"""
		try:
			# 型情報からサイズを抽出する
			# 例: [32 x [32 x i32]] から32を抽出
			type_info = ' '.join(node)
			matches = re.findall(r'\[(\d+) x', type_info)
			if dimension < len(matches):
				return int(matches[dimension])
			return 0

		except Exception as e:
			print(f"Error getting dimension size: {e}")
			return 0

	def _detect_array_access(self, block_id, pointer_regs):
		"""
		ブロック内の配列アクセスを検出

		Args:
			block_id: ブロックID
			pointer_regs: ポインタレジスタ情報

		Returns:
			{
				'mem_ops': {
					'loads': [load_info, ...],
					'stores': [store_info, ...]
				},
				'store_deps': {
					store_line_num: {
						'loads': [load_info, ...]
					}
				}
			} or None
		"""
		try:
			nodes = self._read_node_list(block_id)
			if not nodes:
				return None

			mem_ops = {'loads': [], 'stores': []}
			store_deps = {}

			for line_num, node in enumerate(nodes):
				node = node[0].split()
				if len(node) > 1:
					if 'load' in node[1]:
						for pointer_reg in pointer_regs:
							if pointer_reg["block_id"] == block_id:
								for index_reg in pointer_reg["index_regs"]["regs"]:
									if index_reg in str(node):
										mem_ops['loads'].append({'line_num': line_num})
										break
					elif 'store' in node[1]:
						for pointer_reg in pointer_regs:
							if pointer_reg["block_id"] == block_id:
								for index_reg in pointer_reg["index_regs"]["regs"]:
									if index_reg in str(node):
										mem_ops['stores'].append({'line_num': line_num, 'value': node[2]})
										break

			if mem_ops['loads'] or mem_ops['stores']:
				return {'mem_ops': mem_ops, 'store_deps': store_deps}
			else:
				return None

		except Exception as e:
			print(f"Error detecting array access in block {block_id}: {e}")
			return None

	def _analyze_array_paths(self, pointer_regs_info, store_load_deps, cfg_connectivity):
		result = {}

		try:
			block_order = store_load_deps.get('block_order', {})
			if not block_order:
				return result

			for loop_level, blocks in block_order.items():
				loop_blocks = blocks.get('sequence', [])
				start_node = blocks.get('start', '')
				end_node = blocks.get('end', '')

				if not loop_blocks or not start_node or not end_node:
					continue

				for block_id in loop_blocks:
					for pointer_regs in pointer_regs_info:
						if pointer_regs.get('block_id') != block_id:
							continue

						array_name = pointer_regs.get('array_name')
						if not array_name:
							continue

						if array_name not in result:
							result[array_name] = {'access_paths': []}

						array_access = self._detect_array_access(block_id, pointer_regs)
						if not array_access:
							continue

						index_regs = pointer_regs['index_regs']['regs']
						index_expressions = []
						for index_reg in index_regs:
							path = self._trace_index_variable(index_reg, block_id, store_load_deps.get("paths"), self.nodes)
							if path:
								index_expression = IndexExpression(
									base=array_name,
									path=path,
									source_variables=[index_reg],
									loop_level=int(loop_level),
									is_loop_carried=self._is_loop_carried_register(index_reg, block_id, self._analyze_loop_structure(block_id))
								)
								index_expressions.append(index_expression)

						current_path = {
							'blocks': [],
							'index_expressions': index_expressions,
							'mem_ops': {},
							'store_deps': {},
							'is_loop_path': False,
							'loop_level': int(loop_level),
							'loop_position': {
								'start': start_node,
								'end': end_node
							}
						}

						self._build_forward_path(
							block_id,
							array_access,
							store_load_deps,
							cfg_connectivity,
							current_path,
							result[array_name]['access_paths']
						)

			return result

		except Exception as e:
			print(f"Error analyzing array paths: {e}")
			return result

	def _build_forward_path(self, block_id, array_access, store_load_deps, cfg_connectivity, current_path, access_paths):
		"""
		配列アクセスの前方パスを構築

		Args:
			block_id: 現在のブロックID
			array_access: 配列アクセス情報
			store_load_deps: Store-Load依存関係
			cfg_connectivity: CFG接続情報
			current_path: 現在のパス情報
			access_paths: すべてのアクセスパス
		"""
		try:
			# 現在のブロックをパスに追加
			current_path['blocks'].append(block_id)

			# メモリオペレーションの追加
			if 'mem_ops' not in current_path:
				current_path['mem_ops'] = {}
			if block_id not in current_path['mem_ops']:
				current_path['mem_ops'][block_id] = {}
			current_path['mem_ops'][block_id].update(array_access['mem_ops'])

			# Store依存の追加
			if 'store_deps' not in current_path:
				current_path['store_deps'] = {}
			if block_id not in current_path['store_deps']:
				current_path['store_deps'][block_id] = {}
			current_path['store_deps'][block_id].update(array_access.get('store_deps', {}))

			# 次のブロックの探索
			next_blocks = cfg_connectivity['forward_edges'].get(block_id, [])

			if not next_blocks:  # 末端ブロックの場合
				# パスの重複チェック
				if not any(self._paths_equal(current_path, existing_path) for existing_path in access_paths):
					access_paths.append(current_path.copy())  # パスを追加
				return

			for next_block_info in next_blocks:
				next_block = next_block_info['target']
				is_loop_edge = next_block_info['is_loop_edge']

				# ループバックエッジの場合、パスを打ち切る
				if is_loop_edge and next_block in current_path['blocks']:
					if not any(self._paths_equal(current_path, existing_path) for existing_path in access_paths):
						current_path["is_loop_path"] = True #Set loop path
						access_paths.append(current_path.copy())
					continue

				# 次のブロックの情報を取得
				next_block_info = next((info for info in store_load_deps.get('block_info', []) if info['block_id'] == next_block), None)
				if not next_block_info:
					continue

				next_array_access = self._detect_array_access(next_block, next_block_info)
				if not next_array_access:
					continue

				#IndexExpressionの引き継ぎ
				next_path = current_path.copy()
				next_path["index_expressions"] = current_path["index_expressions"].copy()

				# 再帰的にパスを構築
				self._build_forward_path(
					next_block,
					next_array_access,
					store_load_deps,
					cfg_connectivity,
					next_path,
					access_paths
				)

		except Exception as e:
			print(f"Error building forward path: {e}")
			print(f"Context - Block: {block_id}")

	def _paths_equal(self, path1, path2):
		"""パスが等しいかどうかを判定"""
		if len(path1['blocks']) != len(path2['blocks']):
			return False
		return path1['blocks'] == path2['blocks']

	def _trace_index_variable(self, index_reg, start_block, paths, cfg_connectivity, loop_blocks):
			"""Traces the definition of an index variable."""
			path = []
			current_reg = index_reg
			current_block = start_block
			visited_nodes = set()

			while True:
				nodes_in_block = self.all_nodes.get(current_block)  # current_blockを使用
				if not nodes_in_block:
					print(f"Warning: Nodes not found for block: {current_block}")
					break

				found_definition = False
				for node_id, node in enumerate(nodes_in_block):
					node = node[0].split()
					if (current_block, node_id) in visited_nodes:
						print(f"Warning: Already visited node: {(current_block, node_id)}, possible loop in data flow")
						return None
					visited_nodes.add((current_block, node_id))

					if len(node) > 2 and current_reg == node[1]:
						path.append(node_id)
						if "phi" in node[0]:  # node[1]ではなくnode[0]をチェック
							incoming_block = self._get_phi_incoming_block(current_block, node, cfg_connectivity)
							if incoming_block:
								current_block = incoming_block
								for operand in node[2:]:
									if operand.startswith("%") and operand != current_reg:
										current_reg = operand
										found_definition = True
										break
								if not found_definition: #phiノードのオペランドに%で始まるものがなかった場合
									print(f"Warning: No valid operand found in phi node: {node}")
									return None
								break
							else:
								print(f"Warning: Incoming block not found for phi node in block {current_block}: {node}")
								return None
						elif any(op in node[0] for op in ['add', 'sub', 'mul', 'sext', 'zext', 'trunc', 'shl', 'ashr', 'lshr', 'and', 'or', 'xor']):
							for operand in node[2:]:
								if operand.startswith('%'):
									current_reg = operand
									found_definition = True
									break
							if not found_definition: #オペランドに%で始まるものがなかった場合
								print(f"Warning: No valid operand found in arithmetic operation: {node}")
								return None
							if found_definition:
								break
						elif "load" in node[0]:
							for p in paths:
								if node_id in p:
									sub_path = p[:p.index(node_id) + 1]
									path.extend(reversed(sub_path[1:]))
									current_reg = self._get_load_source_register(nodes_in_block[sub_path[0]])
									found_definition = True
									break
							if found_definition:
								break
						else:
							return path

				if not found_definition:
					prev_block = self._get_previous_block(current_block, loop_blocks, cfg_connectivity)
					if prev_block:
						current_block = prev_block
					else:
						break

			return path

	def _get_phi_incoming_block(self, current_block, phi_node, cfg_connectivity):
		for source_block, edges in cfg_connectivity["backward_edges"].items():
			for edge in edges:
				if edge["target"] == current_block:
					for operand in phi_node[2:]:
						if operand.startswith("%") and operand in [node.split()[1] for node in self._read_node_list(source_block)]:
							return source_block
		return None

	def _get_previous_block(self, block_id, loop_blocks, cfg_connectivity):
		current_index = loop_blocks.index(block_id)
		if current_index > 0:
			return loop_blocks[current_index - 1]
		else:
			for source_block, edges in cfg_connectivity["backward_edges"].items():
				for edge in edges:
					if edge["target"] == block_id and edge["is_loop_edge"]:
						return edge["source"]
		return None

	def _get_load_source_register(self, load_node):
		if "load" in load_node[1] and len(load_node) > 2:
			return load_node[2]
		return None

	def _analyze_array_paths(self, pointer_regs_info, store_load_deps, cfg_connectivity):
		result = {}

		try:
			block_order = store_load_deps.get('block_order', {})
			if not block_order:
				return result

			for loop_level, blocks in block_order.items():
				loop_blocks = blocks.get('sequence', [])
				start_node = blocks.get('start', '')
				end_node = blocks.get('end', '')

				if not loop_blocks or not start_node or not end_node:
					continue

				for block_id in loop_blocks:
					for pointer_regs in pointer_regs_info:
						if pointer_regs.get('block_id') != block_id:
							continue

						array_name = pointer_regs.get('array_name')
						if not array_name:
							continue

						if array_name not in result:
							result[array_name] = {'access_paths': []}

						array_access = self._detect_array_access(block_id, pointer_regs)
						if not array_access:
							continue

						index_regs = pointer_regs['index_regs']['regs']
						index_expressions = []
						for index_reg in index_regs:
							path = self._trace_index_variable(index_reg, block_id, store_load_deps.get("paths"), self.nodes)
							if path:
								index_expression = IndexExpression(
									base=array_name,
									path=path,
									source_variables=[index_reg],
									loop_level=int(loop_level),
									is_loop_carried=self._is_loop_carried_register(index_reg, block_id, self._analyze_loop_structure(block_id))
								)
								index_expressions.append(index_expression)

						current_path = {
							'blocks': [],
							'index_expressions': index_expressions,
							'mem_ops': {},
							'store_deps': {},
							'is_loop_path': False,
							'loop_level': int(loop_level),
							'loop_position': {
								'start': start_node,
								'end': end_node
							}
						}

						self._build_forward_path(
							block_id,
							array_access,
							store_load_deps,
							cfg_connectivity,
							current_path,
							result[array_name]['access_paths']
						)

			return result

		except Exception as e:
			print(f"Error analyzing array paths: {e}")
			return result

	def _analyze_node_dependencies(self,
			current_node: str,
			stores: Dict[int, MemoryOp],
			loads: Dict[int, MemoryOp],
			loop_nodes: List[str],
			start_node: str,
			end_node: str,
			loop_id: str) -> Dict:
		"""ノード間のstore-load依存関係を分析"""
		deps = {
			'internal_deps': {
				'store_to_load': [],
				'load_to_load': [],
				'store_to_store': []
			},
			'external_deps': {
				'incoming': [],
				'outgoing': []
			},
			'loop_carried': {
				'forward': [],
				'backward': []
			}
		}

		# 内部依存関係の分析 (既存実装)
		deps['internal_deps'] = self._analyze_internal_dependencies(stores, loads, current_node)

		# 外部依存関係の分析
		deps['external_deps'] = self._analyze_external_dependencies(current_node, stores, loop_nodes)

		# ループ伝搬依存関係の分析
		deps['loop_carried'] = self._analyze_loop_carried_dependencies(current_node, stores, loop_nodes, start_node, end_node)

		return deps

	def _analyze_external_dependencies(self, current_node: str, stores: Dict[int, MemoryOp], loop_nodes: List[str]) -> Dict:
		"""外部依存関係分析"""
		external_deps = {'incoming': [], 'outgoing': []}
		try:
			current_index = loop_nodes.index(current_node)

			for store_line, store_op in stores.items():
				for next_node in loop_nodes[current_index + 1:]:
					dependent_loads = self._find_dependent_loads(next_node, store_op.reg_addr, store_line, current_node, "", "", "")
					if dependent_loads:
						external_deps['outgoing'].append({
							'from': {'node': current_node, 'line': store_line, 'op': store_op},
							'to': {'node': next_node, 'loads': dependent_loads}
						})
			return external_deps
		except ValueError:
			print(f"Warning: Node {current_node} not found in loop nodes")
			return external_deps

	def _analyze_loop_carried_dependencies(self, current_node: str, stores: Dict[int, MemoryOp], loop_nodes: List[str], start_node: str, end_node: str) -> Dict:
		"""ループ伝搬依存関係分析"""
		loop_carried_deps = {'forward': [], 'backward': []}
		try:
			current_index = loop_nodes.index(current_node)

			for store_line, store_op in stores.items():
				if current_node == start_node:
					dependent_loads = self._find_dependent_loads(end_node, store_op.reg_addr, store_line, current_node, "", start_node, end_node, is_loop_forward=True)
					if dependent_loads:
						loop_carried_deps['forward'].append({
							'from': {'node': current_node, 'line': store_line, 'op': store_op},
							'to': {'node': end_node, 'loads': dependent_loads}
						})

				if current_node == end_node:
					dependent_loads = self._find_dependent_loads(start_node, store_op.reg_addr, store_line, current_node, "", start_node, end_node, is_loop_back=True)
					if dependent_loads:
						loop_carried_deps['backward'].append({
							'from': {'node': current_node, 'line': store_line, 'op': store_op},
							'to': {'node': start_node, 'loads': dependent_loads}
						})

			return loop_carried_deps

		except ValueError:
			print(f"Warning: Node {current_node} not found in loop nodes")
			return loop_carried_deps

	def _analyze_internal_dependencies(self, stores: Dict[int, MemoryOp],
									loads: Dict[int, MemoryOp],
									block_id: str) -> Dict:
		"""ブロック内部の依存関係分析"""
		internal_deps = {
			'store_to_load': [],
			'load_to_load': [],
			'store_to_store': []
		}

		nodes = self._read_node_list(block_id)
		if not nodes:
			return internal_deps

		# Store to Load依存
		for store_line, store_op in stores.items():
			for load_line, load_op in loads.items():
				if store_line < load_line and store_op.reg_addr == load_op.reg_addr:
					internal_deps['store_to_load'].append({
						'from': {'line': store_line, 'op': store_op},
						'to': {'line': load_line, 'op': load_op}
					})

		# Load to Load依存
		sorted_loads = sorted(loads.items())
		for i, (line1, load1) in enumerate(sorted_loads[:-1]):
			for line2, load2 in sorted_loads[i+1:]:
				if load1.reg_addr == load2.reg_addr:
					internal_deps['load_to_load'].append({
						'from': {'line': line1, 'op': load1},
						'to': {'line': line2, 'op': load2}
					})

		# Store to Store依存
		sorted_stores = sorted(stores.items())
		for i, (line1, store1) in enumerate(sorted_stores[:-1]):
			for line2, store2 in sorted_stores[i+1:]:
				if store1.reg_addr == store2.reg_addr:
					internal_deps['store_to_store'].append({
						'from': {'line': line1, 'op': store1},
						'to': {'line': line2, 'op': store2}
					})

		return internal_deps

	def _analyze_gep_chain(self, block_id: str, start_node: str) -> List[Dict]:
		"""
		getelementptrのチェーンを追跡
		Args:
			block_id: 基本ブロックID
			start_node: 開始ノードのID
		Returns:
			[
				{
					'node_id': str,          # ノードID
					'array_name': str,       # 配列名（最初のgetelementptrのみ）
					'index_reg': str,        # このノードで使用されるインデックスレジスタ
					'dimension': int         # アクセスする次元
				}
			]
		"""
		gep_chain = []
		try:
			# AMファイルを使用してノード間の接続を取得
			am_file = f"{self.r_name}_bblock_{block_id}"
			am_size, am = AMUtils.Preprocess(self.r_path, am_file)

			# ノード情報を取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return gep_chain

			# 現在のノードから開始
			current_id = start_node
			visited = set()

			while current_id and current_id not in visited:
				visited.add(current_id)
				current_node = nodes[int(current_id)][0].split()

				if 'getelementptr' not in current_node[1]:
					break

				# ノード情報の解析
				node_info = {
					'node_id': current_id,
					'array_name': None,
					'index_reg': None,
					'dimension': len(gep_chain)  # 次元はチェーンの長さと一致
				}

				# 配列名の抽出（最初のgetelementptrのみ）
				if not gep_chain:  # 最初のノード
					array_match = re.search(r'@([a-zA-Z0-9_]+)', current_node[1])
					if array_match:
						node_info['array_name'] = array_match.group(1).split('_')[0]

				# インデックスレジスタの抽出
				for token in current_node:
					if token.startswith('%') and token != '%0':
						node_info['index_reg'] = token
						break

				gep_chain.append(node_info)

				# 次のgetelementptrを探す
				next_id = None
				current_idx = int(current_id)
				for dst_idx in range(am_size):
					if am[current_idx][dst_idx]:
						dst_node = nodes[dst_idx][0].split()
						if 'getelementptr' in dst_node[1]:
							next_id = str(dst_idx)
							break

				current_id = next_id

			print(f"GEP chain for block {block_id}, starting at node {start_node}:")
			for node in gep_chain:
				print(f"  Node: {node}")

			return gep_chain

		except Exception as e:
			print(f"Error analyzing GEP chain: {e}")
			return gep_chain

	def _analyze_array_access(self, block_id: str, node_info: List[str]) -> Dict[str, ArrayDimInfo]:
		"""ブロック内の配列アクセスパターンを分析"""
		array_accesses = {}

		try:
			for i, node in enumerate(node_info):
				node = node[0].split()

				# getelementptrチェーンの開始点を探す
				if 'getelementptr' in str(node[1]):
					# 最初のgetelementptrかどうかを確認
					if '@' in str(node[1]):  # 配列名を持つgetelementptr
						# gepチェーンを分析
						gep_chain = self._analyze_gep_chain(block_id, str(i))
						if not gep_chain:
							continue

						array_name = gep_chain[0]['array_name']
						if not array_name:
							continue

						# 配列アクセス情報の初期化
						if array_name not in array_accesses:
							array_accesses[array_name] = ArrayDimInfo(
								array_name=array_name,
								dim_accesses=[]
							)

						# チェーンの各ノードについて次元アクセス情報を収集
						for gep_node in gep_chain:
							if gep_node['index_reg']:  # インデックスレジスタがある場合
								loop_level = self._find_loop_level_for_index({
									'register': gep_node['index_reg'],
									'position': i  # 元のノードの位置
								}, block_id)

								array_size = self._get_array_dimension_size(
									array_name,
									gep_node['dimension']
								)

								dim_access = DimensionAccess(
									dimension=gep_node['dimension'],
									loop_level=loop_level,
									array_size=array_size
								)
								array_accesses[array_name].dim_accesses.append(dim_access)

			return array_accesses

		except Exception as e:
			print(f"Error analyzing array access in block {block_id}: {e}")
			return {}

	def _analyze_gep_indices(self, node: List[str]) -> List[Dict]:
		"""getelementptrのインデックスを分析"""
		try:
			indices = []
			# getelementptrの構文を分析
			for i, token in enumerate(node):
				if token.startswith('%') and token != '%0':  # インデックスとして使用されているレジスタ
					indices.append({
						'register': token,
						'position': i
					})
			return indices
		except Exception as e:
			print(f"Error analyzing GEP indices: {e}")
			return []

	def _find_loop_level_for_index(self, index_info: Dict, block_id: str) -> str:
		try:
			reg = index_info['register']
			print(f"\n  Analyzing loop level for register: {reg}")
			print("    Current block:", block_id)
			print("    Available loop levels:")

			# 利用可能なループレベルの表示
			for level, info in self.loop_levels.items():
				print(f"    Level {level} nodes: {info.nodes}")

			# 最内ループから順にブロックを探す
			for level in sorted(self.loop_levels.keys(), key=int):  # レベル順にソート
				info = self.loop_levels[level]
				if block_id in info.nodes:
					print(f"    Found block {block_id} in loop level {level}")
					# ブロック内のノードをチェック
					nodes = self._read_node_list(block_id)
					if nodes:
						print("    Checking nodes for register usage...")
						for node in nodes:
							node_parts = node[0].split()
							if reg in node_parts:
								print(f"    Found register {reg} in node: {' '.join(node_parts)}")
								if any(op in node_parts[1] for op in ['add', 'mul', 'phi', 'icmp', 'shl', 'or']):
									print(f"    Register is used in loop calculation")
									return level

					# ヘッダーブロックもチェック
					header_nodes = self._read_node_list(info.header)
					if header_nodes:
						print(f"    Checking header block {info.header}...")
						for node in header_nodes:
							node_parts = node[0].split()
							if reg in node_parts and any(op in node_parts[1] for op in ['add', 'mul', 'phi', 'icmp', 'shl', 'or']):
								print(f"    Register is used in loop header")
								return level

					# デフォルトでそのループレベルを返す
					return level

			print(f"    Block {block_id} not found in any loop")
			return "unknown"

		except Exception as e:
			print(f"Error finding loop level for register {reg}: {e}")
			print(f"Context - Block ID: {block_id}")
			return "unknown"

	def _is_register_defined_in_loop(self, reg: str, loop_nodes: List[str]) -> bool:
		"""レジスタがループ内で定義されているか確認"""
		try:
			for node_id in loop_nodes:
				nodes = self._read_node_list(node_id)
				for node in nodes:
					node = node[0].split()
					if len(node) > 2 and node[2] == reg:  # レジスタが定義される位置
						return True
			return False
		except Exception as e:
			print(f"Error checking register definition: {e}")
			return False

	def _get_array_dimension_size(self, array_name: str, dimension: int) -> int:
		"""配列の各次元のサイズを取得"""
		try:
			print(f"\n  Looking for size of array {array_name}, dimension {dimension}")
			llvm_file = os.path.join(self.r_path, f"{self.r_name}.ll")
			if not os.path.exists(llvm_file):
				print(f"    LLVM file not found: {llvm_file}")
				return 0

			with open(llvm_file, 'r') as f:
				for line in f:
					if f'@{array_name} =' in line:
						print(f"    Found array definition: {line.strip()}")
						matches = re.findall(r'\[(\d+) x', line)
						print(f"    Found dimensions: {matches}")
						if dimension < len(matches):
							return int(matches[dimension])

			print(f"    Warning: No size information found for array {array_name}, dimension {dimension}")
			return 0

		except Exception as e:
			print(f"Error getting array dimension size: {e}")
			return 0

	def _analyze_array_access_patterns(self, block_id: str, pointer_regs_info: List[Dict]) -> Dict:
		"""ブロック内の配列アクセスパターンを分析"""
		array_accesses = {}
		node_list_path = os.path.join(self.r_path, f"noundef_bblock_{block_id}_node_list.txt")
		bpath_st_ld_path = os.path.join(self.r_path, f"noundef_bblock_{block_id}_bpath_st_ld.txt")

		print(f"  Analyzing Array Access Pattern")

		if not os.path.exists(node_list_path) or not os.path.exists(bpath_st_ld_path):
			print("    File not found")
			return array_accesses

		array_accesses = {}
		for pointer_regs in pointer_regs_info:
			array_name = pointer_regs["array_name"]
			if array_name is None:
				print("Could not find array name in pointer_regs_info")
				continue

			with open(bpath_st_ld_path, 'r') as f:
				for line in f:
					st_ld_paths = self._path_formatter(line)
					if not st_ld_paths:
						continue
					store_id = st_ld_paths[0][0]
					load_ids = []
					for st_ld_path in st_ld_paths:
						load_ids.append(st_ld_path[-1])

					if not load_ids:
						continue
					if array_name not in array_accesses:
						array_accesses[array_name] = {"access_paths": []}
					array_accesses[array_name]["access_paths"].append({
						"store_id": store_id,
						"load_ids": load_ids,
						"defined_reg":pointer_regs['index_regs']['regs']
					})

		return array_accesses

	def _analyze_cfg_connectivity(self,
			block_id: str,
			loop_nodes: List[str]) -> Dict:
		"""
		CFGベースの連結性分析
		Args:
			block_id: 基本ブロックID
			loop_nodes: ループノードのリスト
		Returns:
			{
				'forward_edges': {
					block_id: [
						{
							'target': str,        # 接続先ブロックID
							'is_loop_edge': bool, # ループエッジか
							'edge_type': str      # 'normal'/'loop_forward'/'loop_back'
						}
					]
				},
				'backward_edges': {
					block_id: [
						{
							'source': str,        # 接続元ブロックID
							'is_loop_edge': bool, # ループエッジか
							'edge_type': str      # 'normal'/'loop_forward'/'loop_back'
						}
					]
				}
			}
		"""
		result = {
			'forward_edges': {},
			'backward_edges': {}
		}

		try:
			print(f"  Analyzing CFG Connectivity")
			# 入力パラメータの検証
			if not loop_nodes or block_id not in loop_nodes:
				return result

			# ループの基本情報
			loop_start = loop_nodes[0]
			loop_end = loop_nodes[-1]
			current_idx = loop_nodes.index(block_id)

			# 順方向エッジの分析
			result['forward_edges'][block_id] = []

			# 通常の順方向エッジ
			if current_idx < len(loop_nodes) - 1:
				next_block = loop_nodes[current_idx + 1]
				result['forward_edges'][block_id].append({
					'target': next_block,
					'is_loop_edge': False,
					'edge_type': 'normal'
				})

			# ループの始端から終端へのエッジ
			if block_id == loop_start:
				result['forward_edges'][block_id].append({
					'target': loop_end,
					'is_loop_edge': True,
					'edge_type': 'loop_forward'
				})

			# 逆方向エッジの分析
			result['backward_edges'][block_id] = []

			# 通常の逆方向エッジ
			if current_idx > 0:
				prev_block = loop_nodes[current_idx - 1]
				result['backward_edges'][block_id].append({
					'source': prev_block,
					'is_loop_edge': False,
					'edge_type': 'normal'
				})

			# ループの終端から始端へのエッジ
			if block_id == loop_end:
				result['backward_edges'][block_id].append({
					'source': loop_start,
					'is_loop_edge': True,
					'edge_type': 'loop_back'
				})

			return result

		except Exception as e:
			print(f"Error in analyzing CFG connectivity: {e}")
			print(f"Context - Block ID: {block_id}, Loop nodes: {loop_nodes}")
			return result

	def _get_block_id_from_node_id(self, node_id: str) -> str:
		"""ノードIDからブロックIDを取得"""
		print(f"self.node_to_block:{self.node_to_block.get(node_id)}")
		return self.node_to_block.get(node_id)

	def _collect_index_registers(self,
			block_id: str,
			term_gep,
			begin_geps) -> Dict[str, Union[List[str], int]]:
		"""インデックスレジスタの収集"""
		reg_info = {
			'regs': [],
			'array_dim': 0,
			'dependencies': {}
		}
		array_name = 'None'
		try:
			# 1. パスファイルの読み込み
			paths = {
				'ld_leaf': self._read_path_file(block_id, 'ld_leaf'),
				'ld_ld': self._read_path_file(block_id, 'ld_ld')
			}

			if not any(paths.values()) or not paths['ld_ld']:
				return array_name, reg_info

			# 2. ノード情報の取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return array_name, reg_info

			# 3. AMの読み込み
			am_file = f"{self.r_name}_bblock_{block_id}"
			if am_file not in self._am_cache:
				am_size, am = AMUtils.Preprocess(self.r_path, am_file)
				self._am_cache[am_file] = (am_size, am)
			else:
				am_size, am = self._am_cache[am_file]

			# 4. 終端ノードからのレジスタ収集
			formatted_paths = self._path_formatter(paths['ld_ld'])
			if not formatted_paths:
				return array_name, reg_info

			array_name, term_registers, ld_node_ids = self._collect_from_terminal(
				term_gep[0],
				formatted_paths[0],
				nodes
			)
			if term_registers:
				for reg in term_registers:
					if reg not in reg_info['regs']:
						reg_info['regs'].append(reg)

			# 5. 始端ノードからのレジスタ収集
			begin_registers = []
			regs = self._collect_from_begin(ld_node_ids, paths['ld_leaf'], nodes)
			begin_registers.extend(regs)
			if begin_registers:
				for reg in begin_registers:
					if reg not in reg_info['regs']:
						reg_info['regs'].append(reg)

			# 6. 依存関係の解析
			deps = {}
			for reg in reg_info['regs']:
				dep_info = self._analyze_register_dependency(
					reg, nodes, am, am_size)
				if dep_info:
					deps[reg] = dep_info
			reg_info['dependencies'] = deps

			# 7. 次元数の設定
			reg_info['array_dim'] = len(reg_info['regs'])

			return array_name, reg_info

		except Exception as e:
			print(f"Error collecting index registers: {e}")
			return array_name, {'regs': [], 'array_dim': 0, 'dependencies': {}}

	def _collect_from_terminal(self, term_node_id: str, ld_paths: List[str], nodes: List[List[str]]) -> List[str]:
			"""終端ノードからのレジスタ収集"""
			registers = []
			start_node_ids = []
			array_name = ''
			path_no = []
			try:
				for no, ld_path in enumerate(ld_paths):
					start_node_id = ld_path[-1]

					if str(term_node_id) not in ld_path:
						continue

					start_node_ids.append(start_node_id)
					path_no.append(no)
					for node in nodes:
						node = node[0].split()

						if len(node) > 2 and str(term_node_id) in node[0] and 'load' in node[1]:
							reg = node[-1]
							if reg.startswith('%') and reg not in registers:
								registers.append(reg)
				for no in path_no:
					ld_path = ld_paths[no]
					for id in ld_path:
						node = nodes[int(id)]
						node = node[0].split()
						if '@' in node[1]:
							array_name = node[1].split('_')[1][1:]

				return array_name, registers, start_node_ids

			except Exception as e:
				print(f"Error in _collect_from_terminal: {e}")
			return array_name, registers, start_node_ids

	def _collect_from_begin(self, ld_node_ids, leaf_paths, nodes):
		"""始端ノードからのレジスタ収集"""
		registers = []
		try:
			for ld_node_id in ld_node_ids:
				for leaf_path_str in leaf_paths:
					leaf_paths = self._path_formatter2(leaf_path_str)
					for leaf_path in leaf_paths:
						if str(ld_node_id) in str(leaf_path[0]):
							leaf_node = nodes[int(leaf_path[-1])][0].split()
							if leaf_node[-1] == 'LEAF' and leaf_node[1].startswith('%'):
								reg = leaf_node[1]
								if reg not in registers:
									registers.append(reg)
			return registers

		except Exception:
			return registers

	def _analyze_register_dependency(self, reg: str, nodes: List[List[str]],
								am: List[List[int]], am_size: int) -> Optional[Dict]:
		"""レジスタの依存関係分析"""
		try:
			for line_num, node in enumerate(nodes):
				node = node[0].split()
				if len(node) > 2 and reg in node[1]:
					for src_idx in range(am_size):
						if am[src_idx][line_num]:
							src_node = nodes[src_idx]
							if len(src_node) > 1:
								return {
									'source': src_node[1],
									'type': self._get_dependency_type(src_node[1]),
									'block': str(src_idx)
								}
			return None

		except Exception:
			return None

	def _get_dependency_type(self, opcode: str) -> str:
		"""オペコードから依存関係の種類を判定"""
		if 'load' in opcode:
			return 'load'
		elif 'phi' in opcode:
			return 'phi'
		return 'calc'

	def _analyze_store_load_dependency(self,
			block_id: str,
			pointer_regs_info: List[Dict],
			loops: List[List[str]]) -> Dict:
		result = {
			'forward_deps': {},
			'block_order': {}
		}

		try:
			print(f"  Analyzing Store-Load Dependency")
			# 1. block_idが属するループを特定
			target_loop = None
			target_loop_id = None
			for loop_id, loop_nodes in enumerate(loops):
				if block_id in loop_nodes:
					target_loop = loop_nodes
					target_loop_id = str(loop_id)
					break

			if target_loop is None:
				print(f"Warning: Block {block_id} not found in any loop")
				return result

			# 2. ブロック順序の登録
			result['block_order'][target_loop_id] = {
				'sequence': target_loop,
				'start': target_loop[0],
				'end': target_loop[-1]
			}

			# 3. ブロックの依存関係の初期化
			result['forward_deps'][block_id] = {
				'incoming_loads': {},
				'outgoing_stores': {}
			}

			# 4. レジスタ情報の処理
			# 各ポインタレジスタ情報について処理
			for info in pointer_regs_info:
				if 'index_regs' in info and 'regs' in info['index_regs']:
					reg_list = info['index_regs']['regs']
				else:
					continue

				# ノード情報を取得
				nodes = self._read_node_list(block_id)
				if not nodes:
					continue

				# load/store命令の収集
				stores, loads = self._collect_memory_ops(nodes, reg_list)

				# ロード命令の処理を追加
				for line_num, load_op in loads.items():
					array_name = self._get_array_from_reg(load_op.reg_addr)
					if array_name:
						if line_num not in result['forward_deps'][block_id]['incoming_loads']:
							result['forward_deps'][block_id]['incoming_loads'][line_num] = {
								'reg': load_op.reg_addr,
								'array': array_name
							}

				# 依存関係の分析
				deps = self._analyze_block_forward_deps(
					block_id,
					reg_list,
					target_loop
				)

				if deps:
					# 既存の依存関係と統合
					for store_line, store_info in deps.get('outgoing_stores', {}).items():
						if store_line not in result['forward_deps'][block_id]['outgoing_stores']:
							result['forward_deps'][block_id]['outgoing_stores'][store_line] = store_info
						else:
							existing_info = result['forward_deps'][block_id]['outgoing_stores'][store_line]
							for block, loads in store_info.get('next_blocks', {}).items():
								if block not in existing_info['next_blocks']:
									existing_info['next_blocks'][block] = loads
								else:
									existing_info['next_blocks'][block]['loads'].extend(loads.get('loads', []))

							result['forward_deps'][block_id]['outgoing_stores'][store_line] = existing_info

			return result

		except Exception as e:
			print(f"Error in _analyze_store_load_dependency: {e}")
			return result

	def _analyze_block_forward_deps(self,
			block_id: str,
			reg_list: List[str],
			loop_nodes: List[str]) -> Dict:
		"""
		ブロックの順方向依存関係を分析
		Args:
			block_id: 基本ブロックID
			reg_list: レジスタ名のリスト
			loop_nodes: ループノード群
		Returns:
			{
				'outgoing_stores': {
					line_num: {
						'reg': str,
						'next_blocks': {
							block_id: {
								'loads': [
									{
										'line_num': int,
										'is_loop_edge': bool,
										'edge_type': str
									}
								]
							}
						}
					}
				}
			}
		"""
		result = {'outgoing_stores': {}}

		try:
			print(f"    Analyzing Block Forward Dependencies")
			# 1. ノード情報の取得
			node_info = self._read_node_list(block_id)
			if not node_info:
				return result

			# 2. store/load命令の収集
			stores, loads = self._collect_memory_ops(node_info, reg_list)

			# 3. 現在のブロックの位置を特定
			try:
				current_idx = loop_nodes.index(block_id)
			except ValueError:
				print(f"    Warning: Block {block_id} not found in loop nodes")
				return result

			next_blocks = loop_nodes[current_idx+1:] if current_idx < len(loop_nodes)-1 else []

			# 4. store命令の処理
			for store_line, store_info in stores.items():
				result['outgoing_stores'][store_line] = {
					'reg': store_info.reg_addr,
					'next_blocks': {}
				}

				# 5. 順方向の依存関係を分析
				for next_block in next_blocks:
					deps = self._find_forward_loads(
						next_block,
						store_info.reg_addr,
						store_line,
						block_id,
						loop_nodes
					)
					if deps and deps['loads']:
						result['outgoing_stores'][store_line]['next_blocks'][next_block] = deps

				# 6. ループエッジの処理
				if block_id == loop_nodes[-1]:  # 終端から始端へ
					end_deps = self._find_forward_loads(
						loop_nodes[0],
						store_info.reg_addr,
						store_line,
						block_id,
						loop_nodes
					)
					if end_deps and end_deps['loads']:
						result['outgoing_stores'][store_line]['next_blocks'][loop_nodes[0]] = end_deps

			return result

		except Exception as e:
			print(f"Error in _analyze_block_forward_deps: {e}")
			print(f"Context - Block: {block_id}, Reg list: {reg_list}")
			return result

	def _find_dependent_loads(self,
			target_node: str,
			store_reg: str,
			store_line: int,
			source_node: str,
			loop_id: str,
			start_node: str,
			end_node: str,
			is_loop_back: bool = False,
			is_loop_forward: bool = False) -> List[Dict]:
		"""
		対象ノードから依存するload命令を検索
		Args:
			target_node: 検索対象ノード
			store_reg: store命令のレジスタ
			store_line: store命令の行番号
			source_node: 元のノード
			loop_id: ループID
			start_node: ループ始端ノード
			end_node: ループ終端ノード
			is_loop_back: ループバックエッジか
			is_loop_forward: ループ前方エッジか
		Returns:
			[
				{
					'block_id': str,       # ブロックID
					'line_num': int,       # load命令の行番号
					'loop_info': {
						'loop_id': str,         # ループID
						'is_loop_edge': bool,   # ループエッジか
						'edge_type': str,       # エッジタイプ
						'from_pos': str,        # 依存元の位置
						'to_pos': str          # 依存先の位置
					}
				}
			]
		"""
		dependent_loads = []

		try:
			# 1. ターゲットノードのノード情報を取得
			nodes = self._read_node_list(target_node)
			if not nodes:
				return dependent_loads

			# 2. ノード位置情報の設定
			from_pos = self._determine_node_position(source_node, start_node, end_node)
			to_pos = self._determine_node_position(target_node, start_node, end_node)
			edge_type = self._determine_edge_type(is_loop_back, is_loop_forward)

			# 3. load命令の探索と依存関係の解析
			for line_num, node in enumerate(nodes):
				node = node[0].split()
				if len(node) < 2:
					continue

				# load命令かつ対象レジスタを使用している場合
				if 'load' in node[1] and store_reg in node[3]:
					load_info = {
						'block_id': target_node,
						'line_num': line_num,
						'loop_info': {
							'loop_id': loop_id,
							'is_loop_edge': is_loop_back or is_loop_forward,
							'edge_type': edge_type,
							'from_pos': from_pos,
							'to_pos': to_pos
						}
					}
					dependent_loads.append(load_info)

			return dependent_loads

		except Exception as e:
			print(f"Error finding dependent loads in node {target_node}: {e}")
			print(f"Context - Store register: {store_reg}, Source node: {source_node}")
			return dependent_loads

	def _determine_node_position(self, node: str, start_node: str, end_node: str) -> str:
		"""ノードの位置を判定"""
		if node == start_node:
			return 'start'
		elif node == end_node:
			return 'end'
		return 'middle'

	def _determine_edge_type(self, is_loop_back: bool, is_loop_forward: bool) -> str:
		"""エッジタイプの判定"""
		if is_loop_back:
			return 'backward'
		elif is_loop_forward:
			return 'forward'
		return 'normal'

	def _determine_node_position(self, node: str, start_node: str, end_node: str) -> str:
		"""ノードの位置を判定"""
		if node == start_node:
			return 'start'
		elif node == end_node:
			return 'end'
		return 'middle'

	def _determine_edge_type(self, is_loop_back: bool, is_loop_forward: bool) -> str:
		"""エッジタイプの判定"""
		if is_loop_back:
			return 'backward'
		elif is_loop_forward:
			return 'forward'
		return 'normal'

	def _analyze_node_dependencies(self,
			current_node: str,
			stores: Dict[int, MemoryOp],
			loads: Dict[int, MemoryOp],
			loop_nodes: List[str],
			start_node: str,
			end_node: str,
			loop_id: str) -> Dict:
		"""
		ノード間のstore-load依存関係を分析
		Args:
			current_node: 現在の処理ノード
			stores: 現在ノードのstore命令情報 {line_num: MemoryOp}
			loads: 現在ノードのload命令情報 {line_num: MemoryOp}
			loop_nodes: ループノードのリスト
			start_node: ループ始端ノード
			end_node: ループ終端ノード
			loop_id: ループID
		Returns:
			{
				'stores': {
					line_num: {
						'reg': str,     # レジスタ名
						'loads': [      # 依存するload命令のリスト
							{
								'block_id': str,   # ブロックID
								'line_num': int,   # 行番号
								'loop_info': {
									'loop_id': str,        # ループID
									'is_loop_edge': bool,  # ループエッジか
									'edge_type': str,      # エッジタイプ
									'from_pos': str,       # 開始位置
									'to_pos': str         # 終了位置
								}
							}
						]
					}
				}
			}
		"""
		result = {'stores': {}}

		try:
			# 入力検証
			if not stores:
				return result

			# 現在のノードの位置を特定
			try:
				current_idx = loop_nodes.index(current_node)
			except ValueError:
				print(f"Warning: Node {current_node} not found in loop nodes")
				return result

			# 各store命令の依存関係を分析
			for store_line, store_info in stores.items():
				result['stores'][store_line] = {
					'reg': store_info.reg_addr,
					'loads': []
				}

				# 後続ノードのload命令との依存関係を確認
				next_nodes = loop_nodes[current_idx + 1:]
				for next_node in next_nodes:
					deps = self._find_dependent_loads(
						next_node,
						store_info.reg_addr,
						store_line,
						current_node,
						loop_id,
						start_node,
						end_node
					)
					if deps:
						result['stores'][store_line]['loads'].extend(deps)

				# ループエッジの依存関係を確認
				if current_node == end_node:
					# 終端から始端への依存関係
					deps = self._find_dependent_loads(
						start_node,
						store_info.reg_addr,
						store_line,
						current_node,
						loop_id,
						start_node,
						end_node,
						is_loop_back=True
					)
					if deps:
						result['stores'][store_line]['loads'].extend(deps)

				elif current_node == start_node:
					# 始端から終端への依存関係
					deps = self._find_dependent_loads(
						end_node,
						store_info.reg_addr,
						store_line,
						current_node,
						loop_id,
						start_node,
						end_node,
						is_loop_forward=True
					)
					if deps:
						result['stores'][store_line]['loads'].extend(deps)

			return result

		except Exception as e:
			print(f"Error analyzing node dependencies: {e}")
			print(f"Context - Current node: {current_node}, Loop ID: {loop_id}")
			return result

	def _analyze_pointer_registers(self, block_id: str) -> List[Dict]:
		results = []
		result = {
			'block_id': block_id,
			'gep_node_id': [],
			'array_name': "",
			'term_gep_id': 0,
			'index_regs': {}
		}

		try:
			print(f"  Analyzing Pointer Register")
			# 1. ノード情報の取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return results

			# 2. getelementptrノードの収集
			gep_nodes = []
			for line_num, node in enumerate(nodes):
				node = node[0].split()
				if len(node) > 1 and 'getelementptr' in node[1]:
					gep_nodes.append((line_num, node))

			if not gep_nodes:
				result['index_regs'] = {'regs': [], 'array_dim': 0}
				results.append(result)
				return results

			# 3. 終端GEPノードと始端GEPノードの特定
			terminal_geps = self._find_terminal_geps(block_id, gep_nodes)
			begin_geps = self._find_begin_geps(block_id)

			# 4. ループ情報の取得（新しい戻り値形式を使用）
			loop_info = self._analyze_loop_structure(block_id)

			# 5. 各GEPに対する処理
			for terminal_gep in terminal_geps:
				result['gep_node_id'] = [gep[0] for gep in gep_nodes]
				gep_node_id = terminal_gep[0]

				if terminal_gep:
					result['term_gep_id'] = terminal_gep[0]

					# インデックスレジスタの収集
					array_name, reg_info = self._collect_index_registers(block_id, terminal_gep, begin_geps)
					result['array_name'] = array_name
					result['index_regs'] = reg_info

					results.append(result.copy())

			return results

		except Exception as e:
			print(f"Error in analyzing pointer registers for block {block_id}: {e}")
			return results


	def _analyze_loop_structure(self, block_id: str) -> Dict[str, Any]:
		"""
		特定のブロックに関連するループ構造を分析
		Args:
			block_id: 基本ブロックID
		Returns:
			{
				'loop_info': {
					'id': str,            # ループのID
					'level': int,         # ループのネストレベル
					'nodes': List[str],   # ループを構成するノードリスト
					'current': {          # 現在のブロックの情報
						'position': str,  # 'header', 'exit', 'body'のいずれか
						'is_header': bool,
						'is_exit': bool
					}
				},
				'structure': {
					'header': str,      # ヘッダーブロックID
					'exit': str,        # 出口ブロックID
					'body': List[str]   # 本体のブロックIDリスト
				},
				'edges': {
					'forward': List[str],   # 順方向エッジの接続先
					'backward': List[str],  # 逆方向エッジの接続先
					'loop_carried': bool    # ループ伝搬依存の有無
				}
			}
		"""
		try:
			for idx, loop_nodes in enumerate(self.loops):
				if block_id in loop_nodes:
					header = loop_nodes[0]
					exit_node = loop_nodes[-1]

					result = {
						'loop_info': {
							'id': str(idx),
							'level': len(self.loops) - idx,
							'nodes': loop_nodes,
							'current': {
								'position': 'body',
								'is_header': block_id == header,
								'is_exit': block_id == exit_node
							}
						},
						'structure': {
							'header': header,
							'exit': exit_node,
							'body': loop_nodes[1:-1]
						},
						'edges': {
							'forward': [],
							'backward': [],
							'loop_carried': False
						}
					}

					# 位置情報の更新
					if block_id == header:
						result['loop_info']['current']['position'] = 'header'
					elif block_id == exit_node:
						result['loop_info']['current']['position'] = 'exit'

					# エッジ情報の構築
					block_idx = loop_nodes.index(block_id)
					if block_idx < len(loop_nodes) - 1:
						result['edges']['forward'].append(loop_nodes[block_idx + 1])
					if block_idx > 0:
						result['edges']['backward'].append(loop_nodes[block_idx - 1])

					# ループ伝搬依存の確認
					if block_id == header:
						result['edges']['forward'].append(exit_node)
						result['edges']['loop_carried'] = True
					elif block_id == exit_node:
						result['edges']['backward'].append(header)
						result['edges']['loop_carried'] = True

					return result

			# ループに所属しない場合のデフォルト値
			return {
				'loop_info': {
					'id': '',
					'level': 0,
					'nodes': [],
					'current': {
						'position': 'body',
						'is_header': False,
						'is_exit': False
					}
				},
				'structure': {
					'header': '',
					'exit': '',
					'body': []
				},
				'edges': {
					'forward': [],
					'backward': [],
					'loop_carried': False
				}
			}

		except Exception as e:
			print(f"Error analyzing loop structure for block {block_id}: {e}")
			return {
				'loop_info': {'id': '', 'level': 0, 'nodes': [], 'current': {'position': 'body', 'is_header': False, 'is_exit': False}},
				'structure': {'header': '', 'exit': '', 'body': []},
				'edges': {'forward': [], 'backward': [], 'loop_carried': False}
			}

	def _is_loop_carried_register(self, reg: str, block_id: str, loop_info: Dict) -> bool:
		"""
		レジスタがループ伝搬依存を持つか判定
		Args:
			reg: 検査対象レジスタ
			block_id: 基本ブロックID
			loop_info: ループ構造情報
		Returns:
			bool: ループ伝搬依存の有無
		"""
		try:
			if not loop_info['edges']['loop_carried']:
				return False

			nodes = self._read_node_list(block_id)
			if not nodes:
				return False

			# レジスタの定義位置を確認
			for line_num, node in enumerate(nodes):
				node - node[0].split()
				if len(node) > 2 and reg in node[1]:
					# レジスタがループヘッダで定義され、ループ内で使用される場合
					if (loop_info['loop_info']['current']['is_header'] and
						any(self._is_reg_used_in_block(reg, loop_node)
							for loop_node in loop_info['loop_info']['nodes'])):
						return True

			return False

		except Exception as e:
			print(f"Error checking loop carried register {reg}: {e}")
			return False

	def _is_reg_used_in_block(self, reg: str, block_id: str) -> bool:
		"""
		指定したブロック内でレジスタが使用されているか確認
		"""
		try:
			nodes = self._read_node_list(block_id)
			return any(reg in node[0].split() for node in nodes if len(node) > 1)
		except Exception:
			return False

	def _analyze_gep_from_dependencies(self,
			block_id: str,
			dep: Dict,
			loop_info: Dict) -> Optional[Dict]:
		"""
		依存関係からGEP情報を分析
		Args:
			block_id: 基本ブロックID
			dep: 依存関係情報
			loop_info: ループ構造情報 {
				'level': int,          # ループのネストレベル
				'loop_id': str,        # 所属するループのID
				'position': {          # ブロックの位置情報
					'is_header': bool,
					'is_exit': bool,
					'type': str
				}
			}
		Returns:
			{
				'gep_node_id': List[str],  # GEPノードID
				'array_name': str,         # 配列名
				'term_gep_id': str,        # 終端GEPノードID
				'index_regs': {            # レジスタ情報
					'regs': List[str],
					'array_dim': int
				}
			}
		"""
		try:
			# 1. ノード情報の取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return None

			# 2. 依存関係からGEPノードを特定
			gep_nodes = []
			array_name = ""
			for store_info in dep.get('stores', {}).values():
				reg = store_info.get('reg', '')
				if not reg:
					continue

				# レジスタを使用するGEPノードを検索
				for line_num, node in enumerate(nodes):
					node = node[0].split()
					if len(node) > 1 and 'getelementptr' in node[1] and reg in node[1]:
						gep_nodes.append(str(line_num))
						# 配列名の抽出（形式: getelementptr_@array_name）
						if '@' in node[1]:
							array_name = node[1].split('_')[1][1:]
						break

			if not gep_nodes:
				return None

			# 3. インデックスレジスタの収集
			index_regs: Set[str] = set()
			for store_info in dep.get('stores', {}).values():
				# store命令の依存するload命令からレジスタを収集
				for load_info in store_info.get('loads', []):
					if 'line_num' in load_info:
						load_line = load_info['line_num']
						if load_line < len(nodes):
							load_node = nodes[load_line]
							if len(load_node) > 2 and load_node[1].startswith('%'):
								index_regs.add(load_node[1])

			# 4. 終端GEPの特定
			term_gep_id = gep_nodes[-1] if gep_nodes else "0"

			return {
				'gep_node_id': gep_nodes,
				'array_name': array_name,
				'term_gep_id': term_gep_id,
				'index_regs': {
					'regs': list(index_regs),
					'array_dim': len(index_regs)
				}
			}

		except Exception as e:
			print(f"Error analyzing GEP from dependencies for block {block_id}: {e}")
			return None

	def _get_terminal_gep(self,
			terminal_geps: List[Tuple[int, List[str]]],
			block_id: str,
			gep_node_id: str) -> Optional[Tuple[int, List[str]]]:
		"""
		指定されたGEPノードに接続する終端GEPノードを取得
		Args:
			terminal_geps: [(line_num, node_info), ...] 形式の終端GEPノードリスト
			block_id: 基本ブロックID
			gep_node_id: 検索対象のGEPノードID
		Returns:
			終端GEPノード (line_num, node_info) または None
		"""
		try:
			# 1. 入力パラメータの検証
			if not terminal_geps or not gep_node_id:
				return None

			# 2. ノードリストの取得
			nodes = self._read_node_list(block_id)
			if not nodes:
				return None

			# 3. AMファイルの読み込み
			am_file = f"{self.r_name}_bblock_{block_id}"
			am_size, am = AMUtils.Preprocess(self.r_path, am_file)

			# 4. 各終端GEPに対してチェーンの確認
			for term_gep in terminal_geps:
				# GEPチェーンの取得
				gep_chain = self._get_gep_chain(term_gep[0], am, nodes)

				# 指定されたGEPノードがチェーンに含まれるか確認
				for chain_node in gep_chain:
					if int(gep_node_id) == int(chain_node):
						return term_gep

			# 5. 該当するGEPが見つからない場合、最初の終端GEPを返す
			return terminal_geps[0] if terminal_geps else None

		except Exception as e:
			print(f"Error in _get_terminal_gep for block {block_id}: {e}")
			print(f"Context - Terminal GEPs: {len(terminal_geps)}, GEP node ID: {gep_node_id}")
			return None

	def _get_gep_chain(self,
			term_gep_line: int,
			am: List[List[int]],
			nodes: List[List[str]]) -> List[int]:
		"""
		終端GEPからGEPチェーンを取得
		Args:
			term_gep_line: 終端GEPの行番号
			am: 隣接行列
			nodes: ノード情報のリスト
		Returns:
			GEPチェーンを構成するノードの行番号リスト
		"""
		if (term_gep_line, tuple(map(tuple, am))) in self._gep_chain_cache:
			return self._gep_chain_cache[(term_gep_line, tuple(map(tuple, am)))]
		try:
			if term_gep_line >= len(nodes):
				return []

			if 'getelementptr' not in nodes[term_gep_line][0].split()[1]:
				return []

			# GEPチェーンの構築
			gep_chain = [term_gep_line]
			visited = {term_gep_line}
			current_line = term_gep_line

			while True:
				found_prev = False
				# 前方のGEPノードを探索
				for src_idx in range(len(am)):
					if am[src_idx][current_line] and src_idx not in visited:
						if src_idx >= len(nodes):
							continue

						src_node = nodes[src_idx]
						if len(src_node) <= 1:
							continue

						# GEPノードの場合はチェーンに追加
						if 'getelementptr' in src_node[1]:
							gep_chain.append(src_idx)
							visited.add(src_idx)
							current_line = src_idx
							found_prev = True
							break

				if not found_prev:
					break

			self._gep_chain_cache[(term_gep_line, tuple(map(tuple, am)))] = gep_chain
			return gep_chain

		except Exception as e:
			print(f"Error in _get_gep_chain: {e}")
			print(f"Context - Terminal GEP line: {term_gep_line}")
			return []

	def _update_array_operations(self, array_patterns: Dict, store_load_deps: Dict):
		"""
		配列の操作情報と依存関係を更新
		"""
		try:
			for block_id, deps in store_load_deps.get('forward_deps', {}).items():
				# store操作の分析
				for store_info in deps.get('outgoing_stores', {}).values():
					writing_array = self._get_array_from_reg(store_info['reg'])
					if writing_array in array_patterns:
						array_patterns[writing_array]['array_info']['operations']['has_store'] = True

					# 依存関係の更新
					for array_name, pattern in array_patterns.items():
						for load_info in deps.get('incoming_loads', {}).values():
							reading_array = self._get_array_from_reg(load_info['reg'])
							if reading_array == array_name:
								pattern['array_info']['operations']['has_load'] = True

			return array_patterns  # 修正したarray_patternsを返す

		except Exception as e:
			print(f"Error updating array operations: {e}")
			return array_patterns

	def _get_array_from_reg(self, reg: str) -> Optional[str]:
		"""レジスタから対応する配列名を取得"""
		try:
			# ノードからレジスタを利用している配列を探索
			for block_id, nodes in self.all_nodes.items():
				for node in nodes:
					node_info = node[0].split()
					if 'getelementptr' in str(node_info[1]):
						if reg in node_info[2:]:
							# まず現在のノードで@シンボルをチェック
							array_match = re.search(r'@([a-zA-Z0-9_]+)', str(node_info[1]))
							if array_match:
								return array_match.group(1)

							# @シンボルがない場合、AMファイルを使って先行するgetelementptrを探索
							am_file = f"{self.r_name}_bblock_{block_id}"
							am_size, am = AMUtils.Preprocess(self.r_path, am_file)

							# 現在の行番号を取得
							current_line = int(node_info[0])

							# 先行するノードを探索
							for src_idx in range(am_size):
								if am[src_idx][current_line]:
									if src_idx >= len(nodes):
										continue

									src_node = nodes[src_idx][0].split()
									if 'getelementptr' in src_node[1]:
										array_match = src_node[1].split('_')[1][1:]
										if array_match:
											return array_match
			return None

		except Exception as e:
			print(f"Error in _get_array_from_reg: {e}")
			return None

	def _analyze_memory_operations(self, node_info: List[str], reg: str) -> Dict[str, bool]:
		"""ノード情報からメモリ操作を分析"""
		operations = {
			'has_load': False,
			'has_store': False
		}

		try:
			for node in node_info:
				if isinstance(node, list):
					node = node[0]
				regs = node.split()[3:]
				if reg in str(regs):
					if 'load' in str(node[1]):
						operations['has_load'] = True
					elif 'store' in str(node[1]):
						operations['has_store'] = True
		except Exception as e:
			print(f"Error analyzing memory operations: {e}")

		return operations

	def _update_dependencies(self, array_patterns: Dict, deps: Dict):
		"""配列間の依存関係を更新"""
		try:
			for store_info in deps.get('outgoing_stores', {}).values():
				writing_array = self._get_array_from_reg(store_info['reg'])
				if writing_array not in array_patterns:
					continue

				for load_info in store_info.get('loads', []):
					reading_array = self._get_array_from_reg(load_info['reg'])
					if reading_array not in array_patterns:
						continue

					# 依存関係の更新
					if reading_array not in array_patterns[writing_array]['dependencies']['read_from']:
						array_patterns[writing_array]['dependencies']['read_from'].append(reading_array)
					if writing_array not in array_patterns[reading_array]['dependencies']['write_to']:
						array_patterns[reading_array]['dependencies']['write_to'].append(writing_array)

			return array_patterns

		except Exception as e:
			print(f"Error updating dependencies: {e}")
			return array_patterns

	def analyze(self) -> Dict:
		result = {
			'array_patterns': {},
			'loop_levels': self._analyze_loop_levels(),
			'loops': self.loops
		}

		try:
			print(f"Analyzing:")
			# ループレベルごとの分析
			for loop_id, loop_info in result['loop_levels'].items():
				loop_nodes = loop_info.nodes

				# 各基本ブロックの分析
				for block_id in loop_nodes:
					print(f"block_id-{block_id}")
					# 1. ポインタレジスタの分析
					pointer_regs_info = self._analyze_pointer_registers(block_id)
					if not pointer_regs_info:
						continue

					# 2. 配列アクセスパターンの分析
					nodes = self._read_node_list(block_id)
					array_accesses = self._analyze_array_access(block_id, nodes)

					print(f"  Array accesses in block {block_id}:")
					for array_name, info in array_accesses.items():
						print(f"    Array: {array_name}")
						print(f"    Dimension accesses: {info.dim_accesses}")

					# 3. 各配列の情報を整理
					for pointer_reg in pointer_regs_info:
						array_name = pointer_reg['array_name']
						if not array_name or array_name == 'None':
							continue

						# 3.1 配列情報の初期化
						if array_name not in result['array_patterns']:
							result['array_patterns'][array_name] = {
								'array_info': {
									'dimensions': pointer_reg['index_regs']['array_dim'],
									'block_id': pointer_reg['block_id'],
									'index_regs': pointer_reg['index_regs']['regs'],
									'operations': {
										'has_load': False,
										'has_store': False
									},
									'loop_access': {}
								},
								'dependencies': {
									'read_from': [],
									'write_to': []
								}
							}

						# 3.2 ループアクセス情報の更新
						if array_name in array_accesses:
							for dim_access in array_accesses[array_name].dim_accesses:
								result['array_patterns'][array_name]['array_info']['loop_access'][dim_access.loop_level] = {
									'dimension': dim_access.dimension,
									'array_size': dim_access.array_size
								}

					# 4. store-load依存関係の分析と配列操作の設定
					store_load_deps = self._analyze_store_load_dependency(
						block_id,
						pointer_regs_info,
						self.loops
					)

					# 5. 依存関係と操作の設定
					update_ = self._update_array_operations(result['array_patterns'], store_load_deps)
					result['array_patterns'] = update_

			return result, IndexExpression

		except Exception as e:
			print(f"Error in analyze: {e}")
			return result, IndexExpression