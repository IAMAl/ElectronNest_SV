##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.IRPaser as irparser
import utils.FileUtils as progfile
import funcs.Gen_DFG as Gen_DFG
import funcs.Gen_CFG as Gen_CFG
import argparse

open('utils/__init__.py', 'a').close()

parser = argparse.ArgumentParser(description="args")

parser.add_argument('--src_path',   help='source file path',        default='.')
parser.add_argument('--w_path',     help='gened file path',         default='.')
parser.add_argument('--src_name',   help='source file name',        required=True)
parser.add_argument('--w_name',     help='gened file name',         default=None)
parser.add_argument('--gen_type',   help='gen type: cdfg/dfg/cfg',  required=True)
parser.add_argument('--block',      help='block: yes/no',           default='no')
parser.add_argument('--nm_mode',    help='mnemonic mode: yes/no',   default='yes')
parser.add_argument('--unique_id',  help='unique id: yes/no',       default='yes')
parser.add_argument('--parse',      help='parsing IR: yes/no',      default='yes')

args = parser.parse_args()


MNEMONIC_MODE   = True
if 'yes' == args.nm_mode:
    MNEMONIC_MODE   = False

UNIQUE_ID       = True
if 'no' == args.unique_id:
    UNIQUE_ID       = False


Gen_DFGraph     = False
Gen_CFGraph     = False
if 'cdfg' == args.gen_type:
    Gen_DFGraph     = True
    Gen_CFGraph     = True
elif 'dfg' == args.gen_type:
    Gen_DFGraph     = True
elif 'cfg' == args.gen_type:
    Gen_CFGraph     = True


r_file_path = args.src_path
r_file_name = args.src_name


w_file_path = args.w_path
if None != args.w_name:
    w_file_name = args.w_name
else:
    w_file_name = r_file_name.split('.')[0]+'.txt'


prog = irparser.IR_Parser( r_file_path, r_file_name )
if 'yes' == args.parse:
    progfile.ProgWriter( prog, w_file_path, w_file_name )

if Gen_DFGraph and 'no' == args.block:
    Gen_DFG.Main_Gen_LLVMtoDFG( prog, w_file_path )

if Gen_DFGraph and 'yes' == args.block:
    Gen_DFG.BlockDataFlowExtractor( prog, MNEMONIC_MODE, UNIQUE_ID )

if Gen_CFGraph:
    Gen_CFG.Main_Gen_LLVMtoCFG( prog, w_file_path )