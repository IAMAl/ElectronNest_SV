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
import sys
import argparse
import funcs.Analyzer as analyzis
import funcs.Gen_AGU as gen_agu_prog
import funcs.Gen_DataPath as gen_datapath_prog

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
        #f"{src_name}_cfg_loop.txt",
        f"mmm_cfg_loop.txt",
        #f"{src_name}_cfg_node_list.txt"
        f"mmm_cfg_node_list.txt"
    ]

    for f in required_files:
        path = os.path.join(src_path, f)
        if not os.path.exists(path):
            print(f"Error: Required file {f} not found")
            return False

    return True

if __name__ == "__main__":
    """Main entry point"""
    try:
        # Parse arguments
        parser = argparse.ArgumentParser(description="AGU Generator for ElectronNest")
        parser.add_argument('--src_path', help='Source file path', default='.')
        parser.add_argument('--src_name', help='Source file name', required=True)
        parser.add_argument('--w_path', help='Output file path', default='.')
        parser.add_argument('--w_name', help='Output file name prefix', required=True)
        parser.add_argument('--gen_path', help='agu/datapath/both', default='agu')
        args = parser.parse_args()

        if not verify_paths(args.src_path, args.w_path):
            sys.exit(1)

        if not verify_files(args.src_path, args.src_name):
            sys.exit(1)

        if args.gen_path == 'both':
            GEN_AGU = True
            GEN_PATH = True
        elif args.gen_path == 'agu':
            GEN_AGU = True
            GEN_PATH = False
        elif args.gen_path == 'datapath':
            GEN_AGU = False
            GEN_PATH = True
        else:
            GEN_AGU = False
            GEN_PATH = False

        if GEN_AGU or GEN_PATH:
            # パターン分析
            analyzer = analyzis.Analyzer(args.src_path, args.src_name)
            array_patterns, IndexExpression = analyzer.analyze()

        if GEN_AGU:
            # AGUプログラム生成
            agu_generator = gen_agu_prog.AGUGenerator(
                array_patterns, args.src_path, args.src_name, IndexExpression
            )
            agu_code = agu_generator.generate()

            # AGUコードの出力
            for array_name, program in agu_code.items():
                w_file_name = f"{args.w_name}_{array_name}_agu.ll"
                w_path = os.path.join(args.w_path, w_file_name)
                with open(w_path, 'w') as f:
                    if isinstance(program.get('code'), list):
                        f.write('\n'.join(program['code']))

            print("AGU Code generation completed successfully")

        if GEN_PATH:
            # データパスプログラム生成
            datapath_generator = gen_datapath_prog.DataPathGenerator(
                array_patterns,
                array_patterns.get('compute_paths', {}),
                args.src_path,
                args.src_name
            )
            datapath_code = datapath_generator.ComputeDataPath()

            # データパスコードの出力
            w_file_name = f"{args.w_name}_datapath.ll"
            w_path = os.path.join(args.w_path, w_file_name)
            with open(w_path, 'w') as f:
                if isinstance(datapath_code.get('code'), list):
                    f.write('\n'.join(datapath_code['code']))

            print("Datapath Code generation completed successfully")

    except Exception as e:
        print(f"Error during code generation: {e}")
        sys.exit(1)