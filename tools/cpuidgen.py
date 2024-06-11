#!/usr/bin/env python3
#
# cpuidgen.py — Generate formatted CPUID leaves bitfields
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

import argparse, os, sys, traceback

from pathlib  import Path, PurePath
from saxonche import PySaxonProcessor, PySaxonApiError
from typing   import Optional

TOOL_NAME: str = Path(__file__).stem

DESCRIPTION  = 'Generate CPUID data structures in different output formats'
KCPUID_HELP  = 'Generate a linux-kernel "kcpuid" CSV file'
KHEADER_HELP = 'Generate a linux-kernel C header for the given CPUID_LEAF'
EPILOG  =   f'''example invocations:
  {TOOL_NAME} --kcpuid
  {TOOL_NAME} --kheader 7
  {TOOL_NAME} --kheader 0x12
  {TOOL_NAME} --kheader 0x80000001
'''

KCPUID_XSLT = 'kcpuid.xslt'
KHEADER_XSLT = 'kheader.xslt'

class CPUIDError(RuntimeError):
    '''Custom exception for CPUID generation errors.  This exception is
    'expected': the application's top-most layer should always catch it
    and print its associated value _without_ printing any stack trace.
    '''
    pass

class SaxonCTransformer:
    '''Perform XSLT transformations through SaxonC.'''

    def __init__(self, xslt_dir: Path) -> None:
        self.xslt_dir = xslt_dir
        self.processor = PySaxonProcessor().new_xslt30_processor()

    @staticmethod
    def indent_saxonc_error_messages(text: str) -> str:
        lines = text.split('\n')
        indented_lines = ['    ' + line for line in lines]
        return '\n'.join(indented_lines)

    @staticmethod
    def read_xslt_file(xslt_file: Path) -> str:
        try:
            with xslt_file.open('r') as file:
                return file.read()
        except IOError as e:
            raise CPUIDError(f'Failed to read XSLT file: {e}')

    def transform(self, xslt_name: str, xml_file: Optional[Path] = None) -> str:
        xslt_path = self.xslt_dir / xslt_name
        xslt_data = SaxonCTransformer.read_xslt_file(xslt_path)
        try:
            executable = self.processor.compile_stylesheet(stylesheet_text=xslt_data)
            if xml_file:
                executable.set_global_context_item(file_name=str(xml_file))
            if output := str(executable.call_template_returning_string()):
                return output
            raise CPUIDError(f'{xslt_name} produced no output')
        except PySaxonApiError as e:
            raise CPUIDError('XSLT processing failed:\n' +
                             f'{SaxonCTransformer.indent_saxonc_error_messages(str(e))}')

class CPUIDGen:
    '''CPUID leaf/leaves bitfield generator (different formats).'''

    def __init__(self, db_path: Path) -> None:
        self.xml_dir = db_path / 'xml'
        self.transformer = SaxonCTransformer(db_path / 'xslt')

    def generate_kcpuid_csv(self) -> str:
        return self.transformer.transform(KCPUID_XSLT)

    def generate_leaf_kheader(self, leaf: int) -> str:
        xml_file_name = f'leaf_{leaf:02x}.xml'
        xml_file_path = self.xml_dir / xml_file_name
        if not xml_file_path.exists():
            raise CPUIDError(f'CPUID leaf "{leaf:#x}" is not described in the XML database')
        return self.transformer.transform(KHEADER_XSLT, xml_file_path)

def run_cpuid_generation(parsed_args: argparse.Namespace, db_directory: Path) -> str:
    generator = CPUIDGen(db_directory)

    if parsed_args.kcpuid:
        return generator.generate_kcpuid_csv()
    elif parsed_args.kheader is not None:
        return generator.generate_leaf_kheader(parsed_args.kheader)
    else:
        raise CPUIDError('No action specified.  Please use --kcpuid or --kheader.')

def parse_script_arguments() -> argparse.Namespace:
    def parse_kheader_argument(arg: str) -> int:
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
    parser.add_argument('--kcpuid', '-k', action='store_true', help=KCPUID_HELP)
    parser.add_argument('--kheader', '-l', type=parse_kheader_argument, metavar='CPUID_LEAF', help=KHEADER_HELP)
    return parser.parse_args()

def main() -> None:
    parsed_args = parse_script_arguments()
    db_directory = Path(__file__).resolve().parents[1] / 'db'

    try:
        output = run_cpuid_generation(parsed_args, db_directory)
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
