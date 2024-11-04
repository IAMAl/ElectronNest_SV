class AGUGenerator:
	def __init__(self):
		self.ld_ld_paths = []		# Matrix access patterns
		self.loop_structure = []	# Loop and trigger points
		self.index_paths = []		# Index handling paths
		self.basic_blocks = {}		# BB info from CFG
		self.instructions = {}		# Instruction info
		self.loop_levels = []		# List of loop level indices
		self.array_names = []		# List of array names
		self.array_access = {}		# Dictionary of array access patterns

	def get_function_info(self, instruction):
		"""Extract function call information"""
		function_info = {
			'name': None,		# Function name
			'arguments': [],	# Function arguments
			'return_type': None	# Return type
		}

		# Parse call instruction
		parts = instruction.split()
		for i, part in enumerate(parts):
			if 'call' in part:
				# Get return type
				function_info['return_type'] = parts[i+1]
				# Get function name
				function_info['name'] = parts[i+2].split('@')[1].split('(')[0]
				# Get arguments
				args_start = instruction.find('(') + 1
				args_end = instruction.rfind(')')
				args_str = instruction[args_start:args_end]
				args = args_str.split(',')
				for arg in args:
					function_info['arguments'].append(arg.strip())
				break

		return function_info

	def get_branch_condition(self, loop_info):
		"""Extract branch condition from loop info"""
		condition = {
			'type': None,		# Comparison type
			'operands': [],	# Operands in condition
			'target': None	# Branch target
		}

		# Find icmp instruction before branch
		for instruction in self.instructions.values():
			if 'icmp' in instruction and loop_info in instruction:
				condition['type'] = self.get_comparison_type(instruction)
				condition['operands'] = self.get_operands(instruction)
				break

		# Get branch target from br instruction
		if 'br' in loop_info:
			parts = loop_info.split()
			for i, part in enumerate(parts):
				if 'label' in part:
					condition['target'] = parts[i+1]
					break

		return condition

	def get_bound_condition(self, loop_info):
		"""Extract bound condition from loop info"""
		condition = {
			'type': None,		# Comparison type
			'bound_var': None, # Bound variable
			'index_var': None  # Index variable
		}

		for instruction in self.instructions.values():
			if 'icmp' in instruction and loop_info in instruction:
				condition['type'] = self.get_comparison_type(instruction)
				operands = self.get_operands(instruction)
				# First operand typically index variable
				condition['index_var'] = operands[0]
				# Second operand typically bound variable
				condition['bound_var'] = operands[1]
				break

		return condition

	def build_bb_chain(self, bb_id, triggers):
		"""Build chain of basic blocks for trigger points"""
		def follow_chain(start_bb, visited=None):
			if visited is None:
				visited = set()

			chain = []
			current_bb = start_bb

			while current_bb and current_bb not in visited:
				chain.append(current_bb)
				visited.add(current_bb)
				current_bb = self.get_next_bb(current_bb)

			return chain

		# Build chain for initialization
		if 'init' in self.basic_blocks[bb_id].get('type', ''):
			init_chain = follow_chain(bb_id)
			triggers['on_init']['bb_chain'].extend(init_chain)

		# Build chain for update
		elif 'update' in self.basic_blocks[bb_id].get('type', ''):
			update_chain = follow_chain(bb_id)
			triggers['on_update']['bb_chain'].extend(update_chain)

	def analyze_index_pattern(self):
		"""Analyze index patterns for each array access"""
		for array_name in self.array_access:
			array_info = self.array_access[array_name]

			# For each dimension/index
			for index, info in array_info['indices'].items():
				index_info = {
					'init': {
						'instruction': None,	# Initialization instruction
						'bb': None				# Basic block
					},
					'update': {
						'instruction': None,	# Update instruction
						'bb': None,				# Basic block
						'operation': None		# Operation type (add, mul, etc)
					},
					'bound': {
						'instruction': None,	# Bound check instruction
						'bb': None,				# Basic block
						'condition': None		# Comparison type (<, <=, etc)
					},
					'trigger': {
						'on_init': [],			# What triggers initialization
						'on_update': []			# What triggers update
					}
				}

				# Analyze instructions in loop structure
				for loop_info in self.loop_structure:
					bb_id = self.get_bb_id(loop_info)
					instr_id = self.get_instruction_id(loop_info)

					if f"{index}_init" in loop_info:
						index_info['init']['instruction'] = self.instructions[instr_id]
						index_info['init']['bb'] = bb_id

					elif f"{index}_update" in loop_info:
						index_info['update']['instruction'] = self.instructions[instr_id]
						index_info['update']['bb'] = bb_id
						index_info['update']['operation'] = self.get_operation_type(self.instructions[instr_id])

					elif f"{index}_bound" in loop_info:
						index_info['bound']['instruction'] = self.instructions[instr_id]
						index_info['bound']['bb'] = bb_id
						index_info['bound']['condition'] = self.get_comparison_type(self.instructions[instr_id])

				# Analyze trigger relationships
				index_info['trigger'] = self.analyze_triggers(index, array_info['dimension'])

				info['index_pattern'] = index_info

	def get_operation_type(self, instruction):
		"""Analyze operation type in update instruction"""
		# Can be any operation (add, mul, shift, function call, etc)
		if 'add' in instruction:
			return 'add'
		elif 'mul' in instruction:
			return 'mul'
		elif 'call' in instruction:
			return 'call'
		# ... other operations
		return None

	def get_comparison_type(self, instruction):
		"""Analyze comparison type in bound check"""
		if 'icmp slt' in instruction:
			return '<'
		elif 'icmp sle' in instruction:
			return '<='
		# ... other comparisons
		return None

	def analyze_triggers(self, index, dimension):
		"""Analyze what triggers index init/update"""
		triggers = {
			'on_init': [],
			'on_update': []
		}

		# Find loop level of this index
		idx_level = self.loop_levels.index(index)

		if idx_level == 0:  # Outermost
			triggers['on_init'].append('entry')
		else:  # Inner loop
			# Initialized when outer loop continues
			outer_idx = self.loop_levels[idx_level-1]
			triggers['on_init'].append(f'{outer_idx}_continue')

		if idx_level < dimension-1:  # Not innermost
			# Update triggered by inner loop completion
			inner_idx = self.loop_levels[idx_level+1]
			triggers['on_update'].append(f'{inner_idx}_complete')

		return triggers

	def generate_agu_ir(self, array_name):
		"""Generate AGU IR for an array"""
		array_info = self.array_access[array_name]
		agu_ir = []

		# For each index in dimension order
		for index in self.loop_levels:
			if index in array_info['indices']:
				index_pattern = array_info['indices'][index]['index_pattern']

				# Add initialization
				agu_ir.append(index_pattern['init']['instruction'])

				# Add bound check
				agu_ir.append(index_pattern['bound']['instruction'])

				# Add update operation
				agu_ir.append(index_pattern['update']['instruction'])

		# Add array access pattern
		agu_ir.extend(array_info['access_path'])

		return agu_ir

import argparse
import os
import numpy as np

import utils.IRPaser as irparse
import utils.ProgConstructor as progconst
import utils.GraphUtils as graphutils
import utils.FileUtils as fileutils
import utils.AMUtils as amutils
from test_prog import AGUGenerator

def parse_args():
	"""Parse command line arguments"""
	parser = argparse.ArgumentParser(description='AGU Generator from LLVM IR Analysis')
	parser.add_argument('--input-path', type=str, required=True,
					help='Path to input LLVM IR file')
	parser.add_argument('--output-path', type=str, required=True,
					help='Path for output AGU IR')
	parser.add_argument('--func-name', type=str, required=True,
					help='Function name to analyze')
	parser.add_argument('--cfg-file', type=str, required=True,
					help='CFG adjacency matrix file')
	return parser.parse_args()

def read_and_parse_ir(input_path, func_name):
	"""Read and parse LLVM IR file"""
	# Parse LLVM IR into program structure
	prog = irparse.IR_Parser(input_path, func_name + ".ll")

	# Initialize instruction pointers
	ptr, total_num_funcs, total_num_blocks, total_num_instrs, instr = progconst.InitInstr(prog)

	return prog, ptr

def analyze_basic_blocks(prog, base_name):
	"""Analyze each basic block"""
	bblock_data = {}

	# For each function in program
	for func in prog.funcs:
	# For each basic block in function
	for bblock in func.bblocks:
		name = f"{func.name}_bblock_{bblock.name}"

		# Read DFG paths from Gen_Path output
		paths = {}
		for path_type in ['ld_ld', 'st_ld', 'st_leaf', 'ld_leaf']:
			with open(f"{base_name}_{name}_bpath_{path_type}.txt", "r") as f:
				paths[path_type] = f.readlines()

		# Read adjacency matrix
		am = amutils.Preprocess(base_name, name)

		bblock_data[bblock.name] = {
			'paths': paths,
			'am': am
		}

	return bblock_data

def read_cfg_matrix(cfg_file):
	"""Read CFG adjacency matrix"""
	with open(cfg_file, "r") as f:
		cfg_str = f.read()
		return np.array(eval(cfg_str))

def main():
	args = parse_args()

	# Read and parse LLVM IR
	prog, ptr = read_and_parse_ir(args.input_path, args.func_name)

	# Analyze basic blocks
	bblock_data = analyze_basic_blocks(prog, os.path.join(args.input_path, args.func_name))

	# Read CFG matrix
	cfg_matrix = read_cfg_matrix(args.cfg_file)

	# Create AGU generator with collected data
	agu_gen = AGUGenerator(bblock_data, cfg_matrix)

	# Set input data from analysis
	for bb_name, data in bblock_data.items():
	agu_gen.ld_ld_paths.extend(data['paths']['ld_ld'])
	# Add other necessary paths...

	# Process with AGU generator
	agu_gen.analyze_array_access()
	agu_gen.analyze_index_pattern()

	# Generate AGU IR for each array
	for array_name in agu_gen.array_access:
	agu_ir = agu_gen.generate_agu_ir(array_name)

	# Write AGU IR to output file
	output_file = os.path.join(args.output_path, f"agu_{array_name}.ll")
	with open(output_file, "w") as f:
		for ir in agu_ir:
			f.write(f"{ir}\n")

if __name__ == "__main__":
	main()