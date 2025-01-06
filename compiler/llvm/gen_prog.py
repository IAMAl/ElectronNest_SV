import os
import sys
import argparse
import funcs.Analyzer as analyzis
import funcs.Gen_Prog as gen_prog

def verify_paths(src_path, w_path):
	"""Verify input/output paths exist"""
	if not os.path.exists(src_path):
		print(f"Error: Source path {src_path} does not exist")
		return False

	if not os.path.exists(w_path):
		try:
			os.makedirs(w_path)
		except OSError as e:
			print(f"Error creating output path {w_path}: {e}")
			return False

	return True


def verify_files(src_path, src_name):
	"""Verify required input files exist"""
	required_files = [
		f"{src_name}_cfg_loop.txt",
		f"{src_name}_cfg_node_list.txt"
	]

	for f in required_files:
		path = os.path.join(src_path, f)
		if not os.path.exists(path):
			print(f"Error: Required file {f} not found")
			return False

	return True


def main():
	"""Main entry point"""
	try:
		# Parse arguments
		parser = argparse.ArgumentParser(description="AGU Generator for ElectronNest")
		parser.add_argument('--src_path', help='Source file path', default='.')
		parser.add_argument('--w_path', help='Output file path', default='.')
		parser.add_argument('--src_name', help='Source file name', required=True)
		parser.add_argument('--w_name', help='Output file name prefix', required=True)
		args = parser.parse_args()

		# Verify paths and files
		if not verify_paths(args.src_path, args.w_path):
			sys.exit(1)

		if not verify_files(args.src_path, args.src_name):
			sys.exit(1)

		# Analyze patterns
		analyzer = analyzis.Analyzer(args.src_path, args.src_name)
		array_patterns, IndexExpression = analyzer.analyze()
		#print(array_patterns)

		# Generate AGU programs
		generator = gen_prog.AGUGenerator(array_patterns, args.src_path, args.src_name, IndexExpression)  
		agu_code = generator.generate()

		# Write output files
		for array_name, program in agu_code.items():
			w_file_name = f"{args.w_name}_{array_name}_agu.ll"
			w_path = os.path.join(args.w_path, w_file_name)

			with open(w_path, 'w') as f:
				# コードと構造情報を分けて書き出し
				if isinstance(program.get('code'), list):
					f.write('\n'.join(program['code']))
				else:
					print(f"Warning: Invalid code format for {array_name}")

		print("AGU generation completed successfully")

	except Exception as e:
		print(f"Error during AGU generation: {e}")
		sys.exit(1)

if __name__ == "__main__":
	main()