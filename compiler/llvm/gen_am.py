##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.FileUtils as progfile
import funcs.Gen_AM as Gen_AM
import argparse

open('utils/__init__.py', 'a').close()

parser = argparse.ArgumentParser(description="args")

parser.add_argument('--src_path',   help='source file path',        default='.')
parser.add_argument('--w_path',     help='gened file path',         default='.')
parser.add_argument('--src_name',   help='source file name',        required=True)
parser.add_argument('--zero_rm',    help='block: yes/no',           default='yes')
parser.add_argument('--dst_append', help='mnemonic mode: yes/no',   default='yes')
parser.add_argument('--gen_type',   help='gen cfg/dfg',             default='dfg')

args = parser.parse_args()

r_file_path = args.src_path
r_file_name = args.src_name

w_file_path = args.w_path

ZERO_REMOVE = True
DST_APPEND  = True
GEN_DFG     = True
if 'cfg' == args.gen_type:
    GEN_DFG     = False

if 'no' == args.zero_rm:
    ZERO_REMOVE = True

if 'yes' == args.dst_append:
    mode = "dst_append"
else:
    mode = "no_dst"

if GEN_DFG:
    prog = progfile.ProgReader( r_file_path=r_file_path, r_file_name=r_file_name)

    for func in prog.funcs:
        name_func = func.name.replace('\n', '')
        #print("Func:{}".format(name_func))

        for bblock in func.bblocks:
            name_bblock = bblock.name.replace('\n', '')
            #print("BBlock:{}".format(name_bblock))

            r_file_name = name_func+"_bblock_"+name_bblock+"_dfg"
            w_file_name = name_func+"_bblock_"+name_bblock
            Gen_AM.AMComposer( ZERO_REMOVE=ZERO_REMOVE, mode=mode, r_file_path=r_file_path, r_file_name=r_file_name, w_file_path=w_file_path, w_file_name=w_file_name )
else:
    r_file_name = r_file_name+"_cfg"
    w_file_name = r_file_name
    Gen_AM.AMComposer( ZERO_REMOVE=ZERO_REMOVE, mode=mode, r_file_path=r_file_path, r_file_name=r_file_name, w_file_path=w_file_path, w_file_name=w_file_name )