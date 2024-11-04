##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import funcs.MergeCFGNodes as MergeCFGNodes
import argparse

open('utils/__init__.py', 'a').close()

parser = argparse.ArgumentParser(description="args")

parser.add_argument('--src_path',   help='source file path',    default='.')
parser.add_argument('--w_path',     help='gened file path',     default='.')
parser.add_argument('--src_name',   help='source file name',    required=True)

args = parser.parse_args()

r_file_path = args.src_path
r_file_name = args.src_name
w_file_path = args.w_path

MergeCFGNodes.ExtractCFGNodeMerger( r_file_path, r_file_name, w_file_path )