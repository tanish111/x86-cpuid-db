#!/usr/bin/env python3
#
# cpuidgen.py — Generate formatted CPUID leaves bitfields
#
# SPDX-FileCopyrightText: 2023-2024 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

import argparse, os, sys, traceback

from dataclasses import dataclass
from pathlib     import Path, PurePath
from pygit2      import Commit, GitError, Reference, Repository
from saxonche    import PySaxonProcessor, PySaxonApiError
from typing      import NoReturn, Optional, Union

#
# Project configuration globals
#

RELEASE_TAGS_GLOB       = 'v[[:digit:]].[[:digit:]]*'
PROJECT_NAME            = 'x86-cpuid-db'
TOOL_NAME: str          = Path(__file__).stem

PROJECT_DIRECTORY: Path = Path(__file__).resolve().parents[1]
XSLT_DIRECTORY          = PROJECT_DIRECTORY / 'db' / 'xslt'
XML_DIRECTORY           = PROJECT_DIRECTORY / 'db' / 'xml'

KCPUID_XSLT: Path       = XSLT_DIRECTORY / 'kcpuid.xslt'
KHEADER_XSLT            = XSLT_DIRECTORY / 'kheader.xslt'
KHEADERS_XSLT           = XSLT_DIRECTORY / 'kheaders.xslt'
RUSTLEAF_XSLT           = XSLT_DIRECTORY / 'rustleaf.xslt'

KCPUID_CSV_LICENSE      = 'CC0-1.0'
KHEADER_LICENSE         = 'MIT'

#
# Help strings
#

DESCRIPTION   = 'Generate CPUID data structures in different output formats'
KCPUID_HELP   = 'Generate a linux-kernel "kcpuid" CSV file'
KHEADER_HELP  = 'Generate a C linux-kernel header for CPUID_LEAF'
KHEADERS_HELP = 'Generate one large C linux-kernel header for all leaves'
RUSTLEAF_HELP = 'Generate a Rust module for CPUID_LEAF'
EPILOG  =   f'''example invocations:
  {TOOL_NAME} --kcpuid
  {TOOL_NAME} --kheader 7
  {TOOL_NAME} --kheader 0x12
  {TOOL_NAME} --kheader 0x80000001
    {TOOL_NAME} --rustleaf 7
  {TOOL_NAME} --kheaders
'''

class CPUIDError(RuntimeError):
    '''Custom exception for CPUID generation errors.  This exception is
    'expected': the application's top-most layer should always catch it
    and print its associated value _without_ printing any stack trace.
    '''
    pass

@dataclass
class GitRepository:
    '''Higher-level libgit2 operations.'''
    project_dir: Path
    git_tags_glob: str
    tool_name: str

    def _handle_git_error(self, e: GitError, msg: str) -> NoReturn:
        msg += f'\n       {str(e)}'
        raise CPUIDError(msg)

    def __post_init__(self) -> None:
        '''Prepare for libgit2 operations on this repository'''
        try:
            self.repo = Repository(self.project_dir)
        except GitError as e:
            msg  = f'For now, {self.tool_name} must run from its Git repository'
            self._handle_git_error(e, msg)
        self._verify_repo_release_tags()

    def _verify_repo_release_tags(self) -> None:
        '''Verify that the repo has the expected release tags'''
        try:
            self.repo.describe(pattern=self.git_tags_glob)
        except (GitError, KeyError) as e:
            msg  = 'Git repo has no annotated tags, reachable from HEAD, '
            msg += f'which matches the glob(7) pattern "{self.git_tags_glob}"'
            self._handle_git_error(e, msg)

    def describe_working_tree(self) -> Union[str, NoReturn]:
        '''git describe --match=<glob(7)-pattern> --dirty=<suffix>'''
        try:
            return str(self.repo.describe(committish=None,
                                          pattern=self.git_tags_glob,
                                          dirty_suffix='-dirty'))
        except GitError as e:
            msg  = 'Unknown git error while describing project\'s repository'
            self._handle_git_error(e, msg)

@dataclass
class SaxonCTransformer:
    '''Perform XSLT transformations through SaxonC.'''
    project_dir: Path
    xslt_dir: Path
    project_name: str
    project_version: str

    def __post_init__(self) -> None:
        self.saxonproc = PySaxonProcessor()
        self.processor = self.saxonproc.new_xslt30_processor()

    @staticmethod
    def indent_saxonc_error_messages(text: str) -> str:
        lines = text.split('\n')
        indented_lines = ['    ' + line for line in lines]
        return '\n'.join(indented_lines)

    def transform(self, xslt_path: Path, license: str, xml_file: Optional[Path] = None) -> str:
        xslt_file: str = xslt_path.as_posix()
        generator: str = self.project_name + ' ' + self.project_version
        xslt_params = { 'generatedFilesLicense': self.saxonproc.make_string_value(license),
                        'generator': self.saxonproc.make_string_value(generator) }

        try:
            executable = self.processor.compile_stylesheet(stylesheet_file=xslt_file)
            executable.set_initial_template_parameters(False, xslt_params)
            if xml_file:
                executable.set_global_context_item(file_name=str(xml_file))
            output = str(executable.call_template_returning_string())
        except PySaxonApiError as e:
            raise CPUIDError('XSLT processing failed:\n' +
                             f'{SaxonCTransformer.indent_saxonc_error_messages(str(e))}')

        if not output:
            raise CPUIDError(f'{xslt_path.name} produced no output')
        return output

@dataclass
class CPUIDGen:
    '''CPUID leaf/leaves bitfield generator (different formats).'''
    project_dir: Path
    xslt_dir: Path
    xml_dir: Path
    tool_name: str
    tool_version: str

    def __post_init__(self) -> None:
        self.transformer = SaxonCTransformer(self.project_dir, self.xslt_dir,
                                             self.tool_name, self.tool_version)

    def generate_kcpuid_csv(self) -> str:
        return self.transformer.transform(KCPUID_XSLT, KCPUID_CSV_LICENSE)

    def generate_leaves_kheaders(self) -> str:
        return self.transformer.transform(KHEADERS_XSLT, KHEADER_LICENSE)

    def generate_leaf_kheader(self, leaf: int) -> str:
        xml_file_name = f'leaf_{leaf:02x}.xml'
        xml_file_path = self.xml_dir / xml_file_name
        if not xml_file_path.exists():
            raise CPUIDError(f'CPUID leaf "{leaf:#x}" is not described in the XML database')
        return self.transformer.transform(KHEADER_XSLT, KHEADER_LICENSE, xml_file_path)

    def generate_leaf_rust(self, leaf: int) -> str:
        xml_file_name = f'leaf_{leaf:02x}.xml'
        xml_file_path = self.xml_dir / xml_file_name
        if not xml_file_path.exists():
            raise CPUIDError(f'CPUID leaf "{leaf:#x}" is not described in the XML database')
        return self.transformer.transform(RUSTLEAF_XSLT, KHEADER_LICENSE, xml_file_path)

def run_cpuid_generation(parsed_args: argparse.Namespace) -> str:
    gitrepo = GitRepository(PROJECT_DIRECTORY, RELEASE_TAGS_GLOB, TOOL_NAME)
    version = gitrepo.describe_working_tree()
    generator = CPUIDGen(PROJECT_DIRECTORY,XSLT_DIRECTORY, XML_DIRECTORY,
                         PROJECT_NAME, version)

    if parsed_args.kcpuid:
        return generator.generate_kcpuid_csv()
    elif parsed_args.kheaders:
        return generator.generate_leaves_kheaders()
    elif parsed_args.kheader is not None:
        return generator.generate_leaf_kheader(parsed_args.kheader)
    elif parsed_args.rustleaf is not None:
        return generator.generate_leaf_rust(parsed_args.rustleaf)
    else:
        raise CPUIDError('No action specified.  Please use --kcpuid, --kheader, --rustleaf, or --kheaders.')

def parse_script_arguments() -> argparse.Namespace:
    def parse_leaf_argument(arg: str) -> int:
        try:
            return int(arg, 16)
        except ValueError:
            raise argparse.ArgumentTypeError(f'Invalid CPUID_LEAF hex number: "{arg}"')

    parser = argparse.ArgumentParser(
        prog=TOOL_NAME,
        description=DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('--kcpuid',   '-k', action='store_true', help=KCPUID_HELP)
    parser.add_argument('--kheaders', '-s', action='store_true', help=KHEADERS_HELP)
    parser.add_argument('--kheader',  '-l', type=parse_leaf_argument, metavar='CPUID_LEAF', help=KHEADER_HELP)
    parser.add_argument('--rustleaf', '-r', type=parse_leaf_argument, metavar='CPUID_LEAF', help=RUSTLEAF_HELP)
    return parser.parse_args()

def main() -> None:
    parsed_args = parse_script_arguments()

    try:
        output = run_cpuid_generation(parsed_args)
        print(output, end='')
    except CPUIDError as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)
    except Exception as unexpected_error:
        print(f'Unexpected error: {unexpected_error}', file=sys.stderr)
        traceback.print_exc()
        sys.exit(2)

if __name__ == '__main__':
    main()
