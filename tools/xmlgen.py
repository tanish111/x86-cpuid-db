#!/usr/bin/env python3
#
# xmlgen.py — Automate generating Cpuid bitfields XML description
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only
#
# Data Model relationships ("<--" is inheritance, "<══" is composition):
#
#                                                             +––––––––––+
#                                                             | BitRange |  <═════════════╗
#                                                             +––––––––––+                ║
#                           +––––––––––––––––––+                    ^                     ║
#           +––––––––––––>  |    CpuidNode     |  <––––––––––––––+  ║   <––– ... –––+     ║
#           |               +––––––––––––––––––+                 |  ║               |     ║
#           |                  ^          ^                      |  ║               |     ║
#           .                  |          |                      .  .               .     .
#     +–––––––––––+  +––––––––––––––+  +––––––––––––––+  +–––––––––––––––+  +––––––––––––––––––––+
#     | CpuidLeaf |  | CpuidSubleaf |  | CpuidRegister|  | CpuidBitRange |  | CpuidOSFeatureFlag |
#     +–––––––––––+  +––––––––––––––+  +––––––––––––––+  +–––––––––––––––+  +––––––––––––––––––––+
#                                                                               ^            ^
#                                                                               |            |
#                                                                +–––––––––––––––––––+  +–––––––––––––––––+
#                                                                | CpuidLinuxFeature |  | CpuidXenFeature |
#                                                                +–––––––––––––––––––+  +––––––––––––––––-+
#
# Beside the object relationships above, the Cpuid objects link to each
# other in an AST tree form that mirros the XML schema. That is, the
# object tree can be initialized in the form:
#
#     objtree = \
#         CpuidLeaf('0x80000010', [
#             CpuidSubleaf(0, [
#                 CpuidRegister('eax', [
#                     CpuidBitRange(BitRange(0, 5), reserved=True),
#                     CpuidBitRange(BitRange(6, 6), [
#                         CpuidLinuxFeature(proc=False, altid='wxyz'),
#                         CpuidXenFeature(altid='wxyz', supported='!')
#                     ]),
#                     ...
#                 ]),
#                 CpuidRegister('ebx', [
#                     CpuidBitRange(BitRange(0, 0), desc="feature-0"),
#                     CpuidBitRange(BitRange(1, 1), desc="feature-1"),
#                     ...
#                 ])
#             ]),
#             CpuidSubLeaf(1, [ ... ])
#         ])
#
# This way, the tree can be operated upon through a basic visitor design
# pattern. Check "sample_cpuid_tree".
#
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from pathlib import PurePath
from typing import Any, cast, Generator, Optional
from typing import overload, Sequence, Tuple, Union
from typing import Protocol, runtime_checkable

import argparse, bisect, pprint, sys
import xml.etree.ElementTree as ET

class OS(Enum):
    Linux = auto()
    Xen = auto()

@runtime_checkable
class Range(Protocol):
    @property
    def start(self) -> int:
        pass

    @property
    def end(self) -> int:
        pass

    def overlaps(self, other: Range) -> bool:
        pass

@dataclass(order=True)
class BitRange:
    """Generic '@start-@end' bitfield range, where @start <= @end.
       Objects of this dataclass are ordered only by @start.
       This class is compatible with the 'Range' protocol.
    """
    start: int
    end: int = field(compare=False)

    def __post_init__(self) -> None:
        if self.start < 0 or self.end < 0:
            raise ValueError(f'{str(self)}: negative values')
        if self.start > self.end:
            raise ValueError(f'{str(self)}: start > end')

    def overlaps(self, other: Range) -> bool:
        return (other.end >= self.start) and (other.start <= self.end)

    def __contains__(self, bit: int) -> bool:
        return self.start <= bit <= self.end

    def __len__(self) -> int:
        return (self.end - self.start) + 1

    def __iter__(self) -> Generator[int, None, None]:
        for v in range(self.start, len(self)):
            yield v

    def __str__(self) -> str:
        return f'({self.start}, {self.end})'

    @classmethod
    def from_string(cls, input: str) -> BitRange:
        """Generate an instance from input strings like '3-5' or just '3'."""
        split = input.split('-')
        start = int(split[0])
        if len(split) == 1:
            end = start
        elif len(split) == 2:
            end = int(split[1])
        else:
            raise ValueError(f'String "{input}" is not a bit range')
        return cls(start, end)

@dataclass
class CpuidNode:
    children: Sequence[CpuidNode] = field(init=False, default_factory=list)

@dataclass
class CpuidOSFeatureFlag(CpuidNode):
    bitrange: BitRange = field(default_factory= lambda: BitRange(0, 0))

@dataclass
class CpuidLinuxFeature(CpuidOSFeatureFlag):
    feature: bool = True
    altid: str = ""
    proc: bool = True
    procid: str = ""

@dataclass
class CpuidXenFeature(CpuidOSFeatureFlag):
    feature: bool = True
    attrs: str = ""

@dataclass(order=True)
class CpuidBitRange(CpuidNode):
    """BitRange with checks and standard properties for Cpuid
       EAX/EBX/ECX/EDX register bitfields.
       This class is compatible with the 'Range' protocol.
    """
    _bitrange: BitRange = field()
    features: list[CpuidOSFeatureFlag] = field(default_factory=list)
    id: str = ""
    desc: str = ""
    reserved: bool = False
    proc: bool = True

    def __post_init__(self) -> None:
        self.children = self.features
        if self._bitrange.start > 31 or self._bitrange.end > 31:
            raise ValueError(f'Range {self} is outside 4-byte Cpuid reg')

    @property
    def start(self) -> int:
        return self._bitrange.start

    @property
    def end(self) -> int:
        return self._bitrange.end

    def overlaps(self, other: Range) -> bool:
        return self._bitrange.overlaps(other)

    @property
    def bit(self) -> int:
        return self._bitrange.start

    @property
    def len(self) -> int:
        return len(self._bitrange)

    def add_feature(self, c: CpuidOSFeatureFlag) -> None:
        if self.reserved:
            raise ValueError(f'Cannot add feature flag for the ' +
                             f'reserved bit range {self}')
        self.features.append(c)

    def __str__(self) -> str:
        return str(self._bitrange)

@dataclass
class CpuidRegister(CpuidNode, Sequence[CpuidBitRange]):
    """A Cpuid register is represented by a *non-overlapping* sorted
       collection of Cpuid bitfields (CpuidBitRanges).  It also
       implements a Sequence protocol for such an ordered collection.
    """
    name: str = "eax"
    _ranges: list[CpuidBitRange] = field(default_factory=list)
    desc: str = field(default_factory=str)

    def __post_init__(self) -> None:
        self.children = self._ranges

    @overload
    def __getitem__(self, index: int) -> CpuidBitRange:
        ...

    @overload
    def __getitem__(self, index: slice) -> Sequence[CpuidBitRange]:
        ...

    def __getitem__(self, index: Union[int, slice]) -> Union[CpuidBitRange, Sequence[CpuidBitRange]]:
        return self._ranges[index]

    def __len__(self) -> int:
        return len(self._ranges)

    def can_insert(self, other: Range) -> Tuple[bool, Optional[CpuidBitRange]]:
        """Return true if passed range can be inserted, without any
           overlaps to existing ranges. Otherwise false, along with
           the existing conflicting range.
        """
        for range in self._ranges:
            if range.overlaps(other):
                return False, range
        return True, None

    def insert(self, range: CpuidBitRange) -> None:
        can_insert, conflict = self.can_insert(range)
        if not can_insert:
            assert conflict
            raise ValueError(f'Range {range} cannot be inserted, as it ' +
                             f'conflicts with existing range {conflict}')
        bisect.insort(self._ranges, range)

    def get_undefined_ranges(self) -> Sequence[BitRange]:
        """Return all bit ranges that are still undefined. Note that
           a reserved bit range is considered defined.
        """
        undef_regions: list[BitRange] = []
        start=0
        for r in self._ranges:
            if start > 31:
                break
            if start < r.start:
                undef_regions.append(BitRange(start, r.start - 1))
            start = r.end + 1
        if start <= 31:
            undef_regions.append(BitRange(start, 31))
        return undef_regions

    def get_all_ranges(self) -> Sequence[CpuidBitRange]:
        # Return a copy to protect our version
        return self._ranges.copy()

class RegisterOps:
    """Operations on passed Cpuid registers"""

    @staticmethod
    def set_reserved_ranges(reg: CpuidRegister, ranges: Sequence[BitRange]) -> CpuidRegister:
        for r in ranges:
            cpuid_range = CpuidBitRange(r, reserved=True)
            reg.insert(cpuid_range)
        return reg

    @staticmethod
    def to_feature_flags(reg: CpuidRegister) -> CpuidRegister:
        """Define all non-reserved ranges as 1-bit feature flags"""
        for r in reg.get_undefined_ranges():
            while r.start <= r.end:
                reg.insert(CpuidBitRange(BitRange(r.start, r.start)))
                r.start += 1
        return reg

    @staticmethod
    def set_bitranges(reg: CpuidRegister, ranges: Sequence[BitRange]) -> CpuidRegister:
        for r in ranges:
            reg.insert(CpuidBitRange(r))
        return reg

    @staticmethod
    def set_osfeature_ranges(reg: CpuidRegister, target_ranges: Sequence[BitRange], os: OS) -> CpuidRegister:
        """Mark passed range as having linux feature flags"""
        for r in reg.get_all_ranges():
            for t in target_ranges:
                if not r.overlaps(t):
                    continue
                if os == OS.Linux:
                    f = CpuidLinuxFeature(BitRange(r.start, r.end))
                elif os == OS.Xen:
                    f = CpuidXenFeature(BitRange(r.start, r.end))
                else:
                    raise ValueError(f'Unknown OS "{os.name}"')
                r.add_feature(f)
        return reg

@dataclass
class CpuidSubleaf(CpuidNode):
    id: int = 0
    registers: Sequence[CpuidRegister] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.children = self.registers

@dataclass
class CpuidLeaf(CpuidNode):
    id: str = ""
    subleaves: Sequence[CpuidSubleaf]  = field(default_factory=list)

    def __post_init__(self) -> None:
        self.children = self.subleaves

class XmlGenerator:
    """Recurse over the Cpuid object tree and dump an equivalent XML."""
    @staticmethod
    def to_xml(node: CpuidNode, parent: Optional[ET.Element]) -> Optional[ET.ElementTree]:
        if isinstance(node, CpuidLeaf):
            elems = LeafXmlGen(node).to_xml()
        elif isinstance(node, CpuidSubleaf):
            elems = SubleafXmlGen(node).to_xml()
        elif isinstance(node, CpuidRegister):
            elems = RegisterXmlGen(node).to_xml()
        elif isinstance(node, CpuidBitRange):
            elems = BitRangeXmlGen(node).to_xml()
        elif isinstance(node, CpuidLinuxFeature):
            elems = LinuxFeatureXmlGen(node).to_xml()
        elif isinstance(node, CpuidXenFeature):
            elems = XenFeatureXmlGen(node).to_xml()
        else:
            raise ValueError(f'Unknown node type = {type(node)}')

        this_node: ET.Element = elems[-1]
        for child in node.children:
            XmlGenerator.to_xml(child, this_node)

        # Non-root node: add our elements to parent, as subelements
        if parent is not None:
            parent.extend(elems)
            return None

        # Root node: we're done, finalize the XML tree
        return ET.ElementTree(this_node)

@dataclass
class LinuxFeatureXmlGen:
    linux: CpuidLinuxFeature
    def to_xml(self) -> Sequence[ET.Element]:
        return [ET.Element('linux', {'feature': str(self.linux.feature).lower(),
                                     'proc': str(self.linux.proc).lower()})]

@dataclass
class XenFeatureXmlGen:
    xen: CpuidXenFeature
    def to_xml(self) -> Sequence[ET.Element]:
        return [ET.Element('xen', {'feature': str(self.xen.feature).lower(),
                                   'attrs': str(self.xen.attrs)})]

@dataclass
class ReservedBitRangeXmlGen:
    range: CpuidBitRange
    def to_xml(self) -> Sequence[ET.Element]:
        r = self.range
        start = ' Bit' if r.len == 1 else ' Bits'
        bits  = f'{r.start}' if r.len == 1 else f'{r.start}:{r.end}'
        return [ET.Comment(f'{start} {bits} reserved ')]

@dataclass
class BitRangeXmlGen:
    range: CpuidBitRange
    def to_xml(self) -> Sequence[ET.Element]:
        r = self.range
        if r.reserved:
            return ReservedBitRangeXmlGen(r).to_xml()
        element = ET.Element(f'bit{r.bit}', {'len':  str(r.len),
                                             'id':   str(r.id),
                                             'desc': str(r.desc)})
        return [element]

@dataclass
class RegisterXmlGen:
    reg: CpuidRegister
    def to_xml(self) -> Sequence[ET.Element]:
        regdesc = self.reg.desc if self.reg.desc else '...'
        return [ET.Comment(f' {self.reg.name.upper()}: {regdesc} '),
                ET.Element(self.reg.name)]

@dataclass
class SubleafXmlGen:
    subleaf: CpuidSubleaf
    def to_xml(self) -> Sequence[ET.Element]:
        return [ET.Element('subleaf', { 'id': str(self.subleaf.id) })]

@dataclass
class LeafXmlGen:
    leaf: CpuidLeaf
    def to_xml(self) -> Sequence[ET.Element]:
        return [ET.Element('leaf', { 'id' : str(self.leaf.id) })]

def parse_args() -> argparse.Namespace:

    def parse_bitranges(ranges: str) -> Generator[BitRange, None, None]:
        """Parse bitranges argument, syntax: '2,3-5,10,...'."""
        for r in ranges.split(","):
            yield BitRange.from_string(r)

    prog    = PurePath(__file__).name.removesuffix('.py')
    epilog  =  'Bit ranges are in the form "a-b", "a-b,x-y,z", or just "z".\n'
    epilog += f'For example, do: {prog} -f --reserved 1-3,10,21-22 --linux 5,15'
    formatter=argparse.RawDescriptionHelpFormatter

    parser = argparse.ArgumentParser(prog=prog,
                                     description='Cpuid Xml generator',
                                     epilog=epilog,
                                     formatter_class=formatter)

    parser.add_argument('--debug', '-g', help="Debug mode", action='store_true')
    parser.add_argument('--sample', '-s', help='Dump sample Cpuid object tree',
                        action='store_true')
    parser.add_argument('--leaf', '-l', help='Cpuid leaf ID (string)')
    parser.add_argument('--reg', '-r', help='target Cpuid register (a, b, c, or d)',
                        choices=['a', 'b', 'c', 'd'])
    parser.add_argument('--description', '-d', help='Cpuid reg short description')
    parser.add_argument('--feature-flags', '-f',
                        help='Setup reg as 1-bit feature flags (except reserved areas)',
                        action='store_true')
    parser.add_argument('--reserved',
                        help='Reserved bit range(s), to be set with --feature-flags',
                        type=parse_bitranges)
    parser.add_argument('--ranges',
                        help='Bit ranges to be defined (others will be reserved)',
                        type=parse_bitranges)
    parser.add_argument('--linux', help='Bit range(s) with Linux cpufeatures',
                        type=parse_bitranges)
    parser.add_argument('--xen', help='Bit range(s) with Xen cpufeatures',
                        type=parse_bitranges)
    return parser.parse_args()

def build_cpuid_tree(args: argparse.Namespace) -> CpuidLeaf:
    """Build Cpuid object tree through the passed arguments @args"""
    leaf_id = args.leaf if args.leaf else '0x0'
    regname = f'e{args.reg}x' if args.reg else "eax"
    linux_ranges = list(args.linux) if args.linux else []
    xen_ranges = list(args.xen) if args.xen else []

    if args.reserved and not args.feature_flags:
        raise ValueError('"--reserved" parameter requires "--feature-flags" set')

    reg = CpuidRegister(regname, desc=args.description)
    if args.feature_flags:
        reserved_ranges = list(args.reserved) if args.reserved else []
        reg = RegisterOps.set_reserved_ranges(reg, reserved_ranges)
        reg = RegisterOps.to_feature_flags(reg)
    elif args.ranges:
        bit_ranges = list(args.ranges) if args.ranges else []
        reg = RegisterOps.set_bitranges(reg, bit_ranges)
        undefined_ranges = reg.get_undefined_ranges()
        reg = RegisterOps.set_reserved_ranges(reg, undefined_ranges)
    else:
        raise ValueError('"--feature-flags" or "--ranges" must be set')

    reg = RegisterOps.set_osfeature_ranges(reg, linux_ranges, OS.Linux)
    reg = RegisterOps.set_osfeature_ranges(reg, xen_ranges, OS.Xen)
    leaf = \
        CpuidLeaf(leaf_id, [
            CpuidSubleaf(0, [reg])
        ])
    return leaf

sample_cpuid_tree = \
    CpuidLeaf('0x80000010', [
        CpuidSubleaf(0, [
            CpuidRegister('ebx', [
                CpuidBitRange(BitRange(0, 1), desc="abc"),
                CpuidBitRange(BitRange(3, 5), reserved=True),
                CpuidBitRange(BitRange(7, 9), desc="xyz"),
            ])
        ]),
        CpuidSubleaf(1, [
            CpuidRegister('eax', [
                CpuidBitRange(BitRange(3, 3), [
                    CpuidLinuxFeature(proc=False),
                    CpuidXenFeature(attrs="!a")
                ])
            ])
        ])
    ])

def main() -> None:
    args = parse_args()
    cpuid_obj_tree = build_cpuid_tree(args) if not args.sample else sample_cpuid_tree
    pprint.pp(cpuid_obj_tree) if args.debug else None

    xml_tree = XmlGenerator.to_xml(cpuid_obj_tree, None)
    assert xml_tree
    ET.indent(xml_tree)
    xml_tree.write(sys.stdout.buffer)
