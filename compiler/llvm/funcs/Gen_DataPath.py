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
import os
import sys
import logging


# Configure logging
def setup_logger():
	# Create logger
	logger = logging.getLogger('DataPathGenerator')
	logger.setLevel(logging.INFO)

	# Create console handler and set level to debug
	ch = logging.StreamHandler(sys.stdout)
	ch.setLevel(logging.INFO)

	# Create formatter
	formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

	# Add formatter to ch
	ch.setFormatter(formatter)

	# Add ch to logger
	logger.addHandler(ch)

	return logger

# Initialize logger
logger = setup_logger()

class DataPathGenerator:
	def __init__(self, array_patterns, compute_paths, r_file_path, r_name):
		self.array_patterns = array_patterns['array_patterns']
		self.compute_paths = compute_paths
		self.loop_levels = array_patterns['loop_levels']
		self.loops = array_patterns['loops']
		self.r_path = r_file_path
		self.r_name = r_name
		self.array_dims = self._get_array_dimensions()  # ここで呼び出し

	def _get_array_dimensions(self) -> Dict[str, List[int]]:
		"""
		配列の次元情報を取得
		Returns:
			Dict[str, List[int]]: {array_name: [dim1, dim2, ...]}
		"""
		try:
			array_dims = {}
			for array_name, pattern in self.array_patterns.items():
				dims = []
				if 'array_info' in pattern:
					array_info = pattern['array_info']
					# loop_accessから次元サイズを収集
					for access in array_info.get('loop_access', {}).values():
						if 'array_size' in access:
							dims.append(access['array_size'])
				
				if dims:  # 次元情報が得られた場合のみ追加
					array_dims[array_name] = dims
			
			return array_dims

		except Exception as e:
			logger.error(f"Error getting array dimensions: {e}")
			return {}

	def _group_paths_by_dataflow(self, paths: List[Dict]) -> Dict:
		"""データフローに基づいてパスをグループ化"""
		try:
			dataflows = {}
			
			for path in paths:
				print(f"Debug: Processing path: {path['path_id']}, type: {path['type']}")
				
				# 計算シーケンスの分析
				computation_sequence = []
				control_sequence = []
				
				for comp in path.get('computation', {}).get('sequence', []):
					opcode = comp['opcode'].split('_')[0]
					if opcode == 'icmp':
						control_sequence.append(comp)
					elif opcode in {'add', 'mul', 'sub'}:
						computation_sequence.append(comp)
				
				# パスの分類
				if computation_sequence:
					flow_id = f"compute_{path['path_id']}"
					dataflows[flow_id] = {
						'loads': path.get('inputs', {}).get('loads', []),
						'computation': computation_sequence,
						'stores': [],
						'blocks': {path['path_id'].split('_')[1]},
						'splits': {}
					}
					
				if control_sequence:
					flow_id = f"control_{path['path_id']}"
					dataflows[flow_id] = {
						'loads': [],
						'computation': control_sequence,
						'stores': [],
						'blocks': {path['path_id'].split('_')[1]},
						'splits': {
							'condition': {
								'reg': control_sequence[0]['output_reg'],
								'comp': control_sequence[0]
							}
						}
					}
				
				print(f"Debug: Created flows for path {path['path_id']}")
				
			return dataflows

		except Exception as e:
			logger.error(f"Error in grouping paths by dataflow: {e}")
			return {}

	def _handle_path_split(self, dataflow: Dict, path: Dict):
		"""分岐情報の処理"""
		try:
			# 分岐条件を特定
			for comp in path['computation']['sequence']:
				if comp['opcode'].startswith('icmp'):
					condition_reg = comp['output_reg']
					dataflow['splits']['condition'] = {
						'reg': condition_reg,
						'comp': comp
					}
					break

			# 分岐後のパスを記録
			block_id = path['path_id'].split('_')[1]
			if 'paths' not in dataflow['splits']:
				dataflow['splits']['paths'] = {}
			dataflow['splits']['paths'][block_id] = path

		except Exception as e:
			logger.error(f"Error handling path split: {e}")

	def _analyze_path_connections(self, path_groups: Dict) -> List[Dict]:
		"""
		分割されたパス間の接続関係を解析
		Args:
			path_groups: グループ化されたデータフロー情報
		Returns:
			List[Dict]: 接続されたデータフロー情報のリスト
		"""
		try:
			print(f"Debug: Analyzing path connections")
			print(f"Debug: Input path groups: {path_groups}")
			
			connected_paths = []
			
			for flow_id, flow in path_groups.items():
				current_flow = flow.copy()
				# 存在しないキーへのアクセスを避ける
				current_flow.setdefault('splits', {})
				
				# 条件分岐パスの検出
				if flow_id.startswith('condition_'):
					# 条件ノードを特定
					for comp in flow['computation']:
						if comp['opcode'].startswith('icmp'):
							if 'splits' not in current_flow:
								current_flow['splits'] = {}
							current_flow['splits']['condition'] = {
								'reg': comp['output_reg'],
								'comp': comp
							}
							break
				
				connected_paths.append(current_flow)
				
			print(f"Debug: Connected paths: {connected_paths}")
			return connected_paths
			
		except Exception as e:
			logger.error(f"Error analyzing path connections: {e}")
			return []

	def _connect_split_paths(self, flow: Dict) -> Dict:
		"""分割されたパスの接続"""
		try:
			connected = flow.copy()
			connected['path_sequence'] = []

			# 分岐条件のある基本ブロックを開始点とする
			condition_block = next(iter(flow['splits']['paths'].keys()))
			connected['path_sequence'].append({
				'block': condition_block,
				'type': 'condition',
				'comp': flow['splits']['condition']['comp']
			})

			# 分岐後のパスを追跡
			for block_id, path in flow['splits']['paths'].items():
				if block_id != condition_block:
					connected['path_sequence'].append({
						'block': block_id,
						'type': 'computation',
						'sequence': path['computation']['sequence']
					})

			return connected

		except Exception as e:
			logger.error(f"Error connecting split paths: {e}")
			return flow

	def _generate_flow_id(self, loads: List[Dict], stores: List[Dict]) -> str:
		"""
		データフローの識別子を生成
		Args:
			loads: ロードノード情報のリスト
			stores: ストアノード情報のリスト
		Returns:
			データフロー識別子
		"""
		try:
			# ロードとストアの配列名を収集
			load_arrays = [load['array'] for load in loads if 'array' in load]
			store_arrays = [store['array'] for store in stores if 'array' in store]
			
			# 識別子の生成（例：load_a_b_store_c）
			flow_parts = []
			if load_arrays:
				flow_parts.append('load_' + '_'.join(sorted(load_arrays)))
			if store_arrays:
				flow_parts.append('store_' + '_'.join(sorted(store_arrays)))
				
			return '_'.join(flow_parts) if flow_parts else 'compute'

		except Exception as e:
			logger.error(f"Error generating flow ID: {e}")
			return f"flow_{len(loads)}_{len(stores)}"

	def _generate_dataflow_code(self, flow: Dict) -> List[str]:
		"""
		データフローのLLVM IRコード生成
		入力データをロードし、演算を行い、結果をストアする汎用的なデータパス
		"""
		try:
			print(f"Debug: Generating dataflow code")
			code = []

			compute_seq = []
			for comp in flow.get('computation', []):
				opcode = comp['opcode'].split('_')[0]
				if opcode in {'mul', 'add', 'sub', 'and', 'or', 'xor', 'shl', 'ashr', 'lshr'}:
					compute_seq.append(comp)
					print(f"Debug: Added computation: {opcode} {comp['input_regs']} -> {comp['output_reg']}")

			if compute_seq:
				# 1. ロードすべき入力の特定
				output_regs = {comp['output_reg'] for comp in compute_seq}
				for comp in compute_seq:
					for input_reg in comp['input_regs']:
						if input_reg not in output_regs:
							code.append(f"{input_reg} = load i32, i32* %ptr_{input_reg.strip('%')}, align 4")

				# 2. 計算シーケンス
				for comp in compute_seq:
					code.append(self._generate_operation(comp))

				# 3. 最終結果のストア
				# データフローの最終出力を特定
				final_output = compute_seq[-1]['output_reg']
				code.append(f"store i32 {final_output}, i32* %ptr_out_{final_output.strip('%')}, align 4")

			print(f"Debug: Generated code:\n" + "\n".join(code))
			return code

		except Exception as e:
			logger.error(f"Error generating dataflow code: {e}")
			return []

	def _generate_operation(self, comp: Dict) -> str:
		"""個々の演算のコード生成"""
		op_map = {
			'mul': 'mul',
			'add': 'add',
			'sub': 'sub',
			'and': 'and',
			'or': 'or',
			'xor': 'xor',
			'shl': 'shl',
			'ashr': 'ashr',
			'lshr': 'lshr'
		}
		
		opcode = comp['opcode'].split('_')[0]
		if opcode in op_map:
			return f"{comp['output_reg']} = {op_map[opcode]} i32 {comp['input_regs'][0]}, {comp['input_regs'][1]}"
		
		return ""

	def _generate_computation_sequence(self, sequence: List[Dict]) -> List[str]:
		"""
		計算シーケンスのコード生成
		Args:
			sequence: [
				{
					'node_id': str,
					'opcode': str,
					'input_regs': List[str],
					'output_reg': str
				}
			]
		Returns:
			List[str]: LLVM IR命令のリスト
		"""
		try:
			print(f"Debug: Generating computation sequence for: {sequence}")
			code = []
			for comp in sequence:
				opcode = comp['opcode'].split('_')[0]
				output_reg = comp['output_reg'].strip('%') if comp.get('output_reg') else None
				input_regs = [reg.strip('%') for reg in comp.get('input_regs', [])]

				# 入力レジスタの存在を確認
				if not input_regs or not output_reg:
					print(f"Debug: Skipping invalid computation: {comp}")
					continue

				if opcode == 'add':
					code.append(f"%{output_reg} = add i32 %{input_regs[0]}, %{input_regs[1] if len(input_regs) > 1 else input_regs[0]}")
				elif opcode == 'mul':
					code.append(f"%{output_reg} = mul i32 %{input_regs[0]}, %{input_regs[1] if len(input_regs) > 1 else input_regs[0]}")
				elif opcode == 'sub':
					code.append(f"%{output_reg} = sub i32 %{input_regs[0]}, %{input_regs[1] if len(input_regs) > 1 else input_regs[0]}")
				else:
					print(f"Debug: Unsupported operation: {opcode}")

			print(f"Debug: Generated computation sequence: {code}")
			return code

		except Exception as e:
			logger.error(f"Error generating computation sequence: {e}")
			print(f"Debug: Sequence that caused error: {sequence}")
			return []

	def _generate_condition_code(self, comp: Dict) -> List[str]:
		"""
		条件分岐のコード生成
		Args:
			comp: {
				'opcode': str,      # 'icmp_<condition>'
				'input_regs': List[str],
				'output_reg': str
			}
		Returns:
			List[str]: LLVM IR命令のリスト
		"""
		try:
			print(f"Debug: Generating condition code for: {comp}")
			code = []
			output_reg = comp['output_reg'].strip('%')
			input_regs = [reg.strip('%') for reg in comp['input_regs']]

			# LLVM IRの標準的な比較条件
			condition_map = {
				'eq': 'eq',    # equal
				'ne': 'ne',    # not equal
				'slt': 'slt',  # signed less than
				'sle': 'sle',  # signed less or equal
				'sgt': 'sgt',  # signed greater than
				'sge': 'sge'   # signed greater or equal
			}
			
			# opcodeから条件を抽出
			# 例: icmp_slt_123 -> slt
			opcode_parts = comp['opcode'].split('_')
			cond = 'slt'  # デフォルト値
			for part in opcode_parts[1:]:  # icmpの後の部分を確認
				if part in condition_map:
					cond = condition_map[part]
					break

			# インデックス変数との比較（ループ条件）の場合
			if input_regs:
				if len(input_regs) == 2:  # 2つのレジスタ間の比較
					code.append(f"%{output_reg} = icmp {cond} i32 %{input_regs[0]}, %{input_regs[1]}")
				else:  # ループ境界値との比較
					code.append(f"%{output_reg} = icmp {cond} i32 %{input_regs[0]}, i32 32")  # 32はデフォルト値
					
			print(f"Debug: Generated condition code: {code}")
			return code

		except Exception as e:
			logger.error(f"Error generating condition code: {e}")
			print(f"Debug: Comp data that caused error: {comp}")
			return []

	def _get_loop_bound(self, loop_level: str) -> int:
		"""
		ループレベルに対応する境界値を取得
		"""
		try:
			if loop_level in self.loop_levels:
				for array_name, pattern in self.array_patterns.items():
					loop_access = pattern.get('array_info', {}).get('loop_access', {})
					if loop_level in loop_access:
						return loop_access[loop_level].get('array_size', 32)
			return 32  # デフォルト値

		except Exception as e:
			logger.error(f"Error getting loop bound: {e}")
			return 32

	def _generate_load_node(self, load: Dict) -> str:
		"""
		ロードノードの登録（レジスタ名の生成）
		Returns:
			str: 生成されたレジスタ名
		"""
		try:
			# ロードノードのレジスタ名を生成
			# AGUが生成したポインタを使用する想定
			return f"load_{load['node_id']}"

		except Exception as e:
			logger.error(f"Error generating load node: {e}")
			return f"error_load_{load['node_id']}"

	def ComputeDataPath(self) -> Dict:
		result = {'code': [], 'structure': {'entry': None, 'exit': None}}
		
		try:
			compute_paths = self.compute_paths.get('compute_paths', [])
			print(f"Initial compute_paths: {compute_paths}")  # デバッグ出力
			
			path_groups = self._group_paths_by_dataflow(compute_paths)
			print(f"Path groups: {path_groups}")  # デバッグ出力
			
			connected_paths = self._analyze_path_connections(path_groups)
			print(f"Connected paths: {connected_paths}")  # デバッグ出力
			
			for flow in connected_paths:
				code = self._generate_dataflow_code(flow)
				result['code'].extend(code)
				
			return result
			
		except Exception as e:
			logger.error(f"Error in ComputeDataPath: {e}")
			return result