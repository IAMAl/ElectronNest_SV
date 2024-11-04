##################################################################
##
##	ElectronNest_CP
##	Copyright (C) 2024  Shigeyuki TAKANO
##
##  GNU AFFERO GENERAL PUBLIC LICENSE
##	version 3.0
##
##################################################################

import utils.AMUtils as amutils
import utils.GraphUtils as graphutils
import funcs.Det_Loop as Det_Loop
import argparse

open('utils/__init__.py', 'a').close()

parser = argparse.ArgumentParser(description="args")

parser.add_argument('--src_path',   help='source file path',    default='.')
parser.add_argument('--w_path',     help='gened file path',     default='.')
parser.add_argument('--src_name',   help='source file name',    required=True)
parser.add_argument('--w_name',     help='output file name',    required=True)

args = parser.parse_args()

r_file_path = args.src_path
r_file_name = args.src_name
w_file_path = args.w_path
w_file_name = args.w_name

am_size, am = amutils.Preprocess(r_file_path=r_file_path, r_file_name=r_file_name)

nodes = []
for index in range(len(am)):
    nodes.append(graphutils.Node(am, am_size, index))

edgetab = graphutils.EdgeTab(am_size)

CyclicEdges = Det_Loop.CycleDetector( am_size=am_size, am=am, nodes=nodes, edgetab=edgetab)
CyclicEdges = Det_Loop.TranslateNode(r_file_name=r_file_name, CyclicEdges=CyclicEdges)

if len(CyclicEdges) > 0:
    print("Cycle: {} in Graph {}".format(CyclicEdges, r_file_name))
else:
    print("No Cycles in Graph {}".format(r_file_name))

openfile = w_file_path +'/'+ w_file_name+"_loop.txt"
with open(openfile, "w") as cfg_cycle_file:
    cfg_cycle_file.writelines(str(CyclicEdges))