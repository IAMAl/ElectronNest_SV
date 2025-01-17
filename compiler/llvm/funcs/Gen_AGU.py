##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################
import os
from typing import TypedDict, List, Dict, Tuple, Optional, Set, Union, Any


class AGUGenerator:

	def __init__(self, array_patterns, r_file_path, r_name, IndexExpression):
		"""
		AGUGeneratorの初期化
		Args:
			array_patterns: AGUAnalyzerの分析結果
				{
					'array_patterns': {
						array_name: {
							'access_paths': [],
							'pointer_regs': {},
							'dependencies': {},
							'connectivity': {}
						}
					},
					'loop_levels': {},
					'loops': []
				}
			r_file_path: 入力ファイルのパス
			r_name: 入力ファイルの名前
		"""
		self.array_patterns = array_patterns['array_patterns']
		self.loop_levels = array_patterns['loop_levels']
		self.loops = array_patterns['loops']
		self.r_path = r_file_path
		self.r_name = r_name
		self.IndexExpression = IndexExpression

		# 配列の次元情報
		self.array_dims = self._get_array_dimensions()

		# キャッシュの追加
		self._code_cache = {}
		self._structure_cache = {}

	def _generate_loop_init(self, loop_info: Dict, loop_level: int) -> List[str]:
		"""ループのインデックス初期化コードを生成 (Modified)"""
		init_code = []
		try:
			index_reg = f"%i{loop_level}"
			init_code.extend([
				f"{index_reg} = alloca i32, align 4",
				f"store i32 0, i32* {index_reg}, align 4",
			])

			if loop_info.get('blocks') and loop_info.get('blocks')['header']:
				header_block = loop_info['blocks']['header']
				for index_expression in loop_info.get("index_expressions", []):
					if index_expression.is_loop_carried:
						init_code.extend([
							f"%{index_reg}.load = load i32, i32* {index_reg}, align 4",
							f"%{index_reg}.cmp = icmp slt i32 %{index_reg}.load, 32",  # Array bound should come from array_dims
							f"br i1 %{index_reg}.cmp, label %loop.body.{loop_level}, label %loop.end.{loop_level}"
						])
						break #If found loop carried, break the loop.
			return init_code

		except Exception as e:
			print(f"Error generating loop initialization: {e}")
			return []

	def _generate_array_agu(self, array_name: str, array_info: Dict, array_dims: List[int]) -> Dict:
		result = {
			'code': [],
			'structure': {'loops': [], 'entry': None, 'exit': None}
		}

		try:
			# ヘッダー情報
			result['code'].extend([
				f"; AGU for array {array_name}",
				"target datalayout = \"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128\"",
				"target triple = \"x86_64-pc-linux-gnu\"",
				"",
				f"define dso_local void @agu_{array_name}() #0 {{",
			])

			# 配列の次元ごとにループを生成
			dimensions = array_info['array_info']['dimensions']
			loop_access = array_info['array_info']['loop_access']

			# 使用されるループレベルを特定
			used_levels = set()
			for _, access_info in loop_access.items():
				used_levels.add(int(access_info['dimension']))

			# ループの生成
			for dim in range(dimensions):
				level = str(dim + 1)  # ループレベル
				dim_size = array_dims[dim]  # 次元のサイズ

				# ループヘッダー生成
				loop_code = self._generate_loop_structure(
					level=level,
					size=dim_size,
					array_info=array_info,
					is_innermost=(dim == dimensions - 1)
				)
				result['code'].extend(loop_code)

				# 最内ループでメモリアクセスを生成
				if dim == dimensions - 1:
					access_code = self._generate_memory_access(
						array_name=array_name,
						array_info=array_info,
						array_dims=array_dims
					)
					result['code'].extend(access_code)

			# ループの終了部分を生成
			for dim in range(dimensions):
				level = str(dim + 1)
				result['code'].extend(self._generate_loop_exit(level))

			# 関数終了
			result['code'].extend([
				"ret void",
				"}",
				"",
				"attributes #0 = { nounwind }"
			])

			return result

		except Exception as e:
			print(f"Error in _generate_array_agu for {array_name}: {e}")
			return result

	def _get_array_type(self, array_name: str, dims: List[int]) -> str:
		"""配列型の文字列を生成"""
		type_str = "i32"
		for dim in reversed(dims):
			type_str = f"[{dim} x {type_str}]"
		return type_str

	def _analyze_access_patterns(self, array_info: Dict) -> Dict:
		"""アクセスパターンを分析"""
		patterns = {
			'reads': [],
			'writes': [],
			'indices': []
		}

		for access in array_info.get('access_paths', []):
			if 'store_id' in access:
				patterns['writes'].append(access)
			if 'load_ids' in access:
				patterns['reads'].append(access)
			if 'defined_reg' in access:
				patterns['indices'].extend(access['defined_reg'])

		return patterns

	def _generate_loop_structure(self, level: str, size: int, array_info: Dict, is_innermost: bool) -> List[str]:
		"""ループ構造の生成"""
		code = [
			f"; Loop level {level}",
			f"%i{level} = alloca i32, align 4",
			f"store i32 0, i32* %i{level}, align 4",
			f"br label %loop.header.{level}",
			"",
			f"loop.header.{level}:",
			f"%i{level}.load = load i32, i32* %i{level}, align 4",
			f"%i{level}.cmp = icmp slt i32 %i{level}.load, {size}",
			f"br i1 %i{level}.cmp, label %loop.body.{level}, label %loop.exit.{level}",
			"",
			f"loop.body.{level}:"
		]
		return code

	def _generate_memory_access(self, array_name: str, array_info: Dict, array_dims: List[int]) -> List[str]:
		"""任意の次元数に対応したメモリアクセスコードの生成"""
		code = []

		# インデックスレジスタのロード
		for reg in array_info['array_info']['index_regs']:
			code.extend([
				f"; Access using {reg}",
				f"%{reg.replace('%', '')}.val = load i32, i32* {reg}, align 4"
			])

		# 型文字列の構築（内側から外側へ）
		base_type = "i32"
		current_type = base_type
		for dim_size in reversed(array_dims):
			current_type = f"[{dim_size} x {current_type}]"

		# 最初のGEP（最外次元のポインタ）
		current_ptr = f"@{array_name}"
		current_type_ptr = f"{current_type}*"

		# 各次元に対してGEP命令を生成
		for i, reg in enumerate(array_info['array_info']['index_regs']):
			reg_val = f"%{reg.replace('%', '')}.val"

			# 次の型を計算（1次元分減らす）
			next_type = current_type.replace(f"[{array_dims[i]} x ", "", 1)[:-1]
			ptr_name = f"%ptr_{i}"

			code.append(
				f"{ptr_name} = getelementptr inbounds {current_type}, "
				f"{current_type_ptr} {current_ptr}, i32 0, i32 {reg_val}"
			)

			# 次のイテレーションの準備
			current_ptr = ptr_name
			current_type = next_type
			current_type_ptr = f"{current_type}*"

		# 最終ポインタに対するload/store操作
		ops = array_info['array_info']['operations']
		final_ptr = current_ptr

		if ops['has_load']:
			code.append(f"%loaded.val = load i32, i32* {final_ptr}, align 4")
		if ops['has_store']:
			code.append(f"store i32 %loaded.val, i32* {final_ptr}, align 4")

		return code

	def _generate_loop_exit(self, level: str) -> List[str]:
		"""ループ終了コードの生成"""
		return [
			"",
			f"loop.exit.{level}:",
			f"%i{level}.next = add i32 %i{level}.load, 1",
			f"store i32 %i{level}.next, i32* %i{level}, align 4",
			f"br label %loop.header.{level}"
		]

	def _generate_store_instruction(self, store_id: str, addr_reg: str) -> List[str]:
		"""store命令を生成"""
		return [
			f"  store i32 %val_{store_id}, i32* {addr_reg}, align 4"
		]

	def _generate_load_instruction(self, load_id: str, addr_reg: str) -> List[str]:
		"""load命令を生成"""
		return [
			f"  %val_{load_id} = load i32, i32* {addr_reg}, align 4"
		]

	def _generate_address_calculation(self, array_name: str, array_dims: List[int], index_expression, base_alignment: int) -> Dict:
		"""配列要素のアドレス計算コードを生成"""

		result = {
			'code': [],
			'registers': {'base': None, 'final': None},
			'indices': []
		}
		reg_num = 0
		# ベースアドレス取得 (unchanged)
		base_reg = f"%{reg_num}"
		dims_str = ' x '.join(f'[{dim}' for dim in array_dims) + ' x i32]'
		result['code'].append(
			f"{base_reg} = getelementptr [{dims_str}], [{dims_str}]* @{array_name}, "
			f"i64 0, i64 0"
		)
		result['registers']['base'] = base_reg
		reg_num += 1

		# Use source_variables from IndexExpression (Corrected)
		index_cast_regs = []
		for idx_reg in index_expression.source_variables:
			cast_reg = f"%{reg_num}"
			result['code'].append(
				f"{cast_reg} = sext i32 {idx_reg} to i64"
			)
			index_cast_regs.append(cast_reg)
			reg_num += 1

		# 次元ごとの計算 (unchanged, but now uses the correct index_cast_regs)
		current_ptr = base_reg
		for dim, idx_reg in enumerate(index_cast_regs): #Use index_cast_regs
			next_ptr = f"%{reg_num}"
			if dim == 0:
				sub_dims = array_dims[1:]
				sub_dims_str = ' x '.join(f'[{d}' for d in sub_dims) + ' x i32]'
				result['code'].append(
					f"{next_ptr} = getelementptr {sub_dims_str}, "
					f"{sub_dims_str}* {current_ptr}, i64 {idx_reg}"
				)
			else:
				result['code'].append(
					f"{next_ptr} = getelementptr i32, i32* {current_ptr}, i64 {idx_reg}"
				)
			current_ptr = next_ptr
			reg_num += 1

		result['registers']['final'] = current_ptr
		return result

	def _generate_block(self, block_id: str, array_info: Dict, array_dims: List[int], base_alignment: int) -> Dict:
		result = {
			'code': [],
			'registers': {'inputs': [], 'outputs': [], 'temps': []},
			'control_flow': {'next_blocks': [], 'branch_type': None}
		}

		try:
			# ブロックラベル
			result['code'].append(f"b{block_id}:")

			# この配列の特定ブロックのアクセス情報取得
			accesses = [reg for reg in array_info.get('pointer_regs', [])
								if reg.get('array_name') == self.current_array and
									reg.get('block_id') == block_id]

			for access in accesses:
				# インデックスレジスタの取得
				for index_expression in array_info["access_paths"]:
					if index_expression.base != self.current_array:
						continue

				# アドレス計算コード生成
				addr_calc = self._generate_address_calculation(
					self.current_array,
					array_dims,
					index_expression, # Pass the IndexExpression
					base_alignment
				)
				result['code'].extend(addr_calc['code'])
				result['registers']['temps'].extend(addr_calc['registers'].values())

				# メモリアクセス命令生成
				if block_ops := array_info.get('accesses', {}).get('mem_ops', {}).get(block_id, {}):
					for op_type, ops in block_ops.items():
						if op_type == 'loads':
							reg_base = len(result['registers']['temps'])
							for i, load in enumerate(ops):
								load_reg = f"%{reg_base + i}"
								result['code'].append(
									f"{load_reg} = load i32, i32* {addr_calc['registers']['final']}, "
									f"align {base_alignment}"
								)
								result['registers']['outputs'].append(load_reg)
						elif op_type == 'stores':
							for i, store in enumerate(ops):
								val_reg = f"%val_{store.get('value', i)}"
								result['code'].append(
									f"store i32 {val_reg}, i32* {addr_calc['registers']['final']}, "
									f"align {base_alignment}"
								)

			# ループ制御コード生成
			if loop_info := array_info.get('loops', {}).get(block_id):
				level = loop_info.get('level', 0)
				position = loop_info.get('position', {}).get('type')

				if position == 'header':
					index_reg = f"%i{level}"
					result['code'].extend([
						f"%{index_reg}.next = add i32 %{index_reg}.load, 1",
						f"store i32 %{index_reg}.next, i32* {index_reg}, align 4"
					])
				elif position == 'exit':
					result['code'].append(f"br label %loop.header.{level}")

			return result

		except Exception as e:
			print(f"Error generating block {block_id}: {e}")
			return result

	def _analyze_block_order(self, connectivity: Dict) -> List[str]:
		"""実行順序の決定"""
		ordered = []
		visited = set()

		def visit(block: str, depth: int = 0):
			if block in visited:
				return
			visited.add(block)

			edges = connectivity['forward_edges'].get(block, [])
			normal = [(e['target'], depth + 1) for e in edges if not e['is_loop_edge']]
			loops = [(e['target'], depth) for e in edges if e['is_loop_edge']]

			for target, d in sorted(normal + loops, key=lambda x: x[1]):
				visit(target, d)
			ordered.append(block)

		# エントリーブロックを特定して開始
		entry = next((k for k in connectivity['forward_edges'].keys()
						if not any(e['source'] == k for edges in connectivity['backward_edges'].values()
								for e in edges)),
						next(iter(connectivity['forward_edges'])))
		visit(entry)
		return ordered

	def _find_loop_blocks(self,
			header_block: str,
			next_blocks: List[str],
			connectivity: Dict) -> Dict:
		"""ループを構成するブロック群を特定"""
		result = {
			'blocks': [],
			'header': header_block,
			'back_edge': None,
			'depth': 0
		}

		visited = set()
		loop_blocks = []

		def collect_blocks(block: str, depth: int = 0):
			if block in visited:
				return
			visited.add(block)
			loop_blocks.append((block, depth))

			# 前方エッジをたどる
			for edge in connectivity['forward_edges'].get(block, []):
				if not edge['is_loop_edge']:
					collect_blocks(edge['target'], depth + 1)

		# ヘッダーからブロック収集開始
		collect_blocks(header_block)
		result['blocks'] = [b[0] for b in sorted(loop_blocks, key=lambda x: x[1])]
		result['depth'] = max(d for _, d in loop_blocks)

		# バックエッジの特定
		for block in result['blocks']:
			for edge in connectivity['backward_edges'].get(block, []):
				if edge['source'] == header_block and edge['is_loop_edge']:
					result['back_edge'] = {
						'source': block,
						'target': header_block,
						'depth': next((d for b, d in loop_blocks if b == block), 0)
					}

		return result

	def _get_loop_level(self, block_id: str, loops: List[List[str]]) -> int:
		"""
		基本ブロックのループ階層レベルを取得

		Args:
			block_id: 基本ブロックID
			loops: 全ループ情報のリスト [[node_id, ...], ...]
				内側のループから外側のループの順で格納

		Returns:
			int: ループの階層レベル
				- 0: ループに属さない
				- 1以上: ループの階層レベル（値が大きいほど外側）

		Example:
			loops = [
				['19', '22', '46'],         # 最内ループ（k-loop）
				['9', '12', '19', '49'],    # 中間ループ（j-loop）
				['5', '8', '9', '53']       # 最外ループ（i-loop）
			]
			block_id='19'の場合、最内ループと中間ループに属するため、
			最も深い階層レベル3を返す
		"""
		try:
			max_level = 0

			# 各ループレベルを確認
			# enumerate(reversed(loops))により外側から内側へ処理
			for idx, loop_blocks in enumerate(reversed(loops)):
				if block_id in loop_blocks:
					# 逆順なので、最外ループが最後に来る
					# よって、level = len(loops) - idx
					level = len(loops) - idx
					max_level = max(max_level, level)

			return max_level

		except Exception as e:
			print(f"Error getting loop level for block {block_id}: {e}")
			print(f"Context - Number of loops: {len(loops)}")
			return 0

	def _get_array_dimensions(self) -> Dict[str, List[int]]:
		"""
		LLVM IRファイルから配列の次元情報を抽出

		Returns:
			Dict[str, List[int]]: {
				array_name: [dim1, dim2, ...],  # 配列ごとの次元サイズリスト
				例: {'a': [32, 32], 'b': [64, 64]}
			}
		デフォルト値: {}
		"""
		array_dims: Dict[str, List[int]] = {}

		try:
			# LLVM IRファイルのパスを構築
			llvm_file = os.path.join(self.r_path, "mmm.ll")
			if not os.path.exists(llvm_file):
				print(f"Warning: LLVM IR file not found: {llvm_file}")
				return array_dims

			# ファイルを読み込んで配列定義を解析
			with open(llvm_file, 'r') as f:
				for line in f:
					# グローバル配列の定義行を検出
					if '@' in line and 'global' in line and 'zeroinitializer' in line:
						# 配列名を抽出（例: @a = ... から 'a'を取得）
						parts = line.split('=')[0].strip()
						array_name = parts.replace('@', '').strip()

						# 次元情報を抽出
						dims: List[int] = []
						dim_parts = line.split('[')[1:]  # [32 x [32 x i32]] の部分を分割

						for part in dim_parts:
							if 'x' in part:
								# 次元サイズを抽出（例: "32 x" から "32"を取得）
								dim_str = part.split('x')[0].strip()
								if dim_str.isdigit():
									dims.append(int(dim_str))

						# 有効な次元情報が得られた場合のみ登録
						if dims:
							array_dims[array_name] = dims

			return array_dims

		except Exception as e:
			print(f"Error getting array dimensions: {e}")
			print("Context - LLVM IR file path:", llvm_file)
			return array_dims

	def generate(self) -> Dict:
		"""
		AGUプログラムの生成

		Returns:
			{
				array_name: {                # 配列ごとのAGUプログラム
					'code': str,             # LLVM IR形式のコード
					'structure': {           # プログラム構造情報
						'loops': [           # ループ情報
							{
								'blocks': List[str],  # ループ構成ブロック
								'level': int         # ネストレベル
							}
						],
						'entry': str,        # エントリーブロック
						'exit': str         # 終了ブロック
					}
				}
			}
		"""
		result = {}
		try:
			print(f"Generating Code.")
			# 配列ごとのAGUプログラム生成
			for array_name, pattern in self.array_patterns.items():
				# 空の配列名と'None'をスキップ
				if not array_name or array_name == 'None':
					continue

				# 配列の次元情報の確認
				if array_name not in self.array_dims:
					print(f"Warning: No dimension information for array {array_name}")
					continue

				# AGUプログラムの生成
				agu_program = self._generate_array_agu(
					array_name,
					pattern,
					self.array_dims[array_name]
				)

				result[array_name] = agu_program

			return result

		except Exception as e:
			print(f"Error generating AGU programs: {e}")
			return result
