##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.FileUtils as fileutils
import utils.AMUtils as amutils
import utils.GraphUtils as graphutils
import funcs.Gen_Path as genpath
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

prog = fileutils.ProgReader( r_file_path=r_file_path, r_file_name=r_file_name )


for func in prog.funcs:
    name_func = func.name.replace('\n', '')

    for bblock in func.bblocks:
        name_bblock = bblock.name.replace('\n', '')
        r_file_name = name_func+"_bblock_"+name_bblock

        am_size, am = amutils.Preprocess( r_file_path, r_file_name )
        NodeList = graphutils.ReadNodeList(r_file_name)

        w_file_name = name_func+"_bblock_"+name_bblock
        genpath.Gen_Path( am, NodeList, w_file_path, w_file_name )