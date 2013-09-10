#! /usr/bin/python
import os
import functools
import fnmatch
from os.path import *
import ntpath
import sys
import shutil
import re
import argparse
import generate_project
from subprocess import *
from errno import *
from common import *

def die(s):
    print(s)
    sys.exit(-1)

parser = argparse.ArgumentParser(description='Execute the specified P Tests')
parser.add_argument("input", metavar='input.p', type=str, help="the P file we are compiling")
parser.add_argument("output", metavar='<output dir>', type=str, help="output dir")

parser.add_argument("--zc", action='store_const', dest='zc', const=True, \
    default=False, help="run ZingCompiler on generated code")
parser.add_argument("--proj", action='store_const', dest='proj', const=True,
    default=False, help="generate a VisualStudio project for generated C Code")
parser.add_argument("--cc", action='store_const', dest='cc', const=True,
    default=False, help="Build Generated C Code")

args = parser.parse_args()

if (args.cc and not args.proj):
    die("Cannot build code without generating VS Project first. Are you missing a --proj?")

scriptDir = dirname(realpath(__file__))
baseDir = realpath(join(scriptDir, ".."))

zc=join(baseDir, "Ext", "Tools", "ZingCompiler", "zc")
zinger=join(baseDir, "Ext", "Tools", "Zinger", "Zinger")
p2f=join(baseDir, "Src", "Compilers", "P2Formula", "bin", "Debug", "P2Formula")
pc=join(baseDir, "Src", "Compilers", "PCompiler", "bin", "Debug", "PCompiler")

stateCoverage=join(baseDir, "Ext", "Tools", "Zinger", "StateCoveragePlugin.dll")
sched=join(baseDir, "Ext", "Tools", "Zinger", "RandomDelayingScheduler.Dll")
cc="MSBuild.exe"

pFile = args.input
out=args.output
name = os.path.splitext(os.path.basename(pFile))[0]

pData=relpath(join(baseDir, "Src", "Formula", "Domains", "PData.4ml"), out)
zingRT=join(baseDir, "Runtime", "Zing", "SMRuntime.zing")
cInclude=relpath(join(baseDir, "Runtime", "Include"), out)
cLib=relpath(join(baseDir, "Runtime", "Libraries"), out)

fmlFile = join(out, name + ".4ml")
zingFile = "output.zing"
zingDll = name + ".dll"
proj = join(out, name + ".vcxproj")
binary = join(out, "Debug", name+ ".exe")

try:
    print("Running P2Formula")
    check_output([p2f, pFile, fmlFile, pData, '/modelName:' + name]);

    print("Running pc")
    check_output([pc, '/doNotErase', fmlFile, '/outputDir:' + out])

    if (args.zc):
        print("Running zc")
        shutil.copy(zingRT, join(out, "SMRuntime.zing"));
        check_output([zc, zingFile, "SMRuntime.zing", '/out:' + zingDll], \
            cwd=out)
        os.remove(join(out, "SMRuntime.zing"));

    if (args.proj):
        mainM = re.search("MainDecl\(New\(MachType\(\"([^\"]*)\"", \
            open(fmlFile).read()).groups()[0]

        print("Main machine is " + mainM)
        print("Generating VS project...")

        generate_project.generateVSProject(out, name, cInclude, cLib, mainM, \
            False)

    if (args.cc):
        print("Building Generated C...")
        outp = check_output([cc, proj]);

        if (buildSucceeded(outp)):
            die("Failed Building the C code:\n" + outp)
    
except CalledProcessError as err:
    print("Failed Compiling: \n")
    print(err.output)