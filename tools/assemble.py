#!/usr/bin/env python3

import argparse
import ast
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
REGISTER_RE = re.compile(r"^[Rr]([0-7])$")
LOW_REF_RE = re.compile(r"^<([A-Za-z_][A-Za-z0-9_]*)_low>$")
HIGH_REF_RE = re.compile(r"^<([A-Za-z_][A-Za-z0-9_]*)_high>$")
LO_CALL_RE = re.compile(r"^lo\(([A-Za-z_][A-Za-z0-9_]*)\)$", re.IGNORECASE)
HI_CALL_RE = re.compile(r"^hi\(([A-Za-z_][A-Za-z0-9_]*)\)$", re.IGNORECASE)


class AsmError(Exception):
    pass


@dataclass
class ParsedLine:
    lineno: int
    original: str
    label: Optional[str]
    mnemonic: Optional[str]
    operands: List[str]


def strip_comment(line: str) -> str:
    if "//" in line:
        return line.split("//", 1)[0]
    return line


def split_operands(text: str) -> List[str]:
    if not text:
        return []
    return [part.strip() for part in text.split(",") if part.strip()]


def parse_line(lineno: int, original: str) -> ParsedLine:
    text = strip_comment(original).strip()
    if not text:
        return ParsedLine(lineno, original.rstrip("\n"), None, None, [])

    label = None
    if ":" in text:
        head, tail = text.split(":", 1)
        candidate = head.strip()
        if LABEL_RE.match(candidate):
            label = candidate
            text = tail.strip()
        else:
            raise AsmError(f"line {lineno}: invalid label '{candidate}'")

    if not text:
        return ParsedLine(lineno, original.rstrip("\n"), label, None, [])

    parts = text.split(None, 1)
    mnemonic = parts[0].upper()
    operands = split_operands(parts[1] if len(parts) > 1 else "")
    return ParsedLine(lineno, original.rstrip("\n"), label, mnemonic, operands)


def parse_register(token: str, lineno: int) -> int:
    match = REGISTER_RE.match(token)
    if not match:
        raise AsmError(f"line {lineno}: expected register, got '{token}'")
    return int(match.group(1))


def parse_char_literal(token: str, lineno: int) -> int:
    try:
        value = ast.literal_eval(token)
    except Exception as exc:  # pragma: no cover - defensive
        raise AsmError(f"line {lineno}: invalid character literal {token!r}") from exc
    if not isinstance(value, str) or len(value) != 1:
        raise AsmError(f"line {lineno}: character literal must decode to one character")
    return ord(value)


def parse_int_token(token: str, lineno: int, labels: Dict[str, int]) -> int:
    token = token.strip()

    match = LOW_REF_RE.match(token)
    if match:
        label = match.group(1)
        if label not in labels:
            raise AsmError(f"line {lineno}: unknown label '{label}'")
        return labels[label] & 0xFF

    match = HIGH_REF_RE.match(token)
    if match:
        label = match.group(1)
        if label not in labels:
            raise AsmError(f"line {lineno}: unknown label '{label}'")
        return (labels[label] >> 8) & 0xFF

    match = LO_CALL_RE.match(token)
    if match:
        label = match.group(1)
        if label not in labels:
            raise AsmError(f"line {lineno}: unknown label '{label}'")
        return labels[label] & 0xFF

    match = HI_CALL_RE.match(token)
    if match:
        label = match.group(1)
        if label not in labels:
            raise AsmError(f"line {lineno}: unknown label '{label}'")
        return (labels[label] >> 8) & 0xFF

    if LABEL_RE.match(token) and token in labels:
        return labels[token]

    if token.startswith("'") and token.endswith("'"):
        return parse_char_literal(token, lineno)

    try:
        return int(token, 0)
    except ValueError as exc:
        raise AsmError(f"line {lineno}: invalid immediate '{token}'") from exc


def mask8(value: int) -> int:
    return value & 0xFF


def require_imm8(token: str, lineno: int, labels: Dict[str, int]) -> int:
    return mask8(parse_int_token(token, lineno, labels))


def encode_instruction(line: ParsedLine, labels: Dict[str, int]) -> int:
    mnem = line.mnemonic
    ops = line.operands
    n = line.lineno

    if mnem == "NOP":
        if ops:
            raise AsmError(f"line {n}: NOP takes no operands")
        return 0x0000

    if mnem == "HALT":
        if ops:
            raise AsmError(f"line {n}: HALT takes no operands")
        return 0x07FF

    if mnem in {"RAND", "MOVR"}:
        if len(ops) != 1:
            raise AsmError(f"line {n}: {mnem} expects 1 operand")
        rt = parse_register(ops[0], n)
        return 0x0800 | rt

    if mnem == "ADDI":
        if len(ops) != 2:
            raise AsmError(f"line {n}: ADDI expects 'rT, imm'")
        rt = parse_register(ops[0], n)
        imm = require_imm8(ops[1], n, labels)
        return 0x1000 | (imm << 3) | rt

    if mnem == "SUBI":
        if len(ops) != 2:
            raise AsmError(f"line {n}: SUBI expects 'rT, imm'")
        rt = parse_register(ops[0], n)
        imm = require_imm8(ops[1], n, labels)
        return 0x1800 | (imm << 3) | rt

    if mnem == "ADD":
        if len(ops) != 3:
            raise AsmError(f"line {n}: ADD expects 'rT, rA, rB'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        rb = parse_register(ops[2], n)
        return 0x2000 | (ra << 6) | (rb << 3) | rt

    if mnem == "SUB":
        if len(ops) != 3:
            raise AsmError(f"line {n}: SUB expects 'rT, rA, rB'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        rb = parse_register(ops[2], n)
        return 0x2800 | (ra << 6) | (rb << 3) | rt

    if mnem == "MOVL":
        if len(ops) != 2:
            raise AsmError(f"line {n}: MOVL expects 'rT, imm'")
        rt = parse_register(ops[0], n)
        imm = require_imm8(ops[1], n, labels)
        return 0x3000 | (imm << 3) | rt

    if mnem == "MOVH":
        if len(ops) != 2:
            raise AsmError(f"line {n}: MOVH expects 'rT, imm'")
        rt = parse_register(ops[0], n)
        imm = require_imm8(ops[1], n, labels)
        return 0x3800 | (imm << 3) | rt

    if mnem == "BR":
        if len(ops) != 1:
            raise AsmError(f"line {n}: BR expects 'rT'")
        rt = parse_register(ops[0], n)
        return 0x4000 | rt

    if mnem == "BEQ":
        if len(ops) != 3:
            raise AsmError(f"line {n}: BEQ expects 'rT, rA, rB'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        rb = parse_register(ops[2], n)
        return 0x4800 | (ra << 6) | (rb << 3) | rt

    if mnem == "BNE":
        if len(ops) != 3:
            raise AsmError(f"line {n}: BNE expects 'rT, rA, rB'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        rb = parse_register(ops[2], n)
        return 0x4A00 | (ra << 6) | (rb << 3) | rt

    if mnem == "BEQI":
        if len(ops) != 3:
            raise AsmError(f"line {n}: BEQI expects 'rT, rA, imm'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        imm = require_imm8(ops[2], n, labels)
        return 0x8000 | ((imm & 0xF8) << 6) | (ra << 6) | ((imm & 0x07) << 3) | rt

    if mnem == "STRI":
        if len(ops) != 2:
            raise AsmError(f"line {n}: STRI expects 'rA, imm'")
        ra = parse_register(ops[0], n)
        imm = require_imm8(ops[1], n, labels)
        return 0xF000 | (((imm >> 6) & 0x03) << 9) | (ra << 6) | (imm & 0x3F)

    if mnem == "LDR":
        if len(ops) != 2:
            raise AsmError(f"line {n}: LDR expects 'rT, rA'")
        rt = parse_register(ops[0], n)
        ra = parse_register(ops[1], n)
        return 0xF800 | (ra << 6) | rt

    if mnem == "STR":
        if len(ops) != 2:
            raise AsmError(f"line {n}: STR expects 'rA, rT'")
        ra = parse_register(ops[0], n)
        rt = parse_register(ops[1], n)
        return 0xF808 | (ra << 6) | rt

    raise AsmError(f"line {n}: unsupported mnemonic '{mnem}'")


def parse_source(path: Path) -> List[ParsedLine]:
    return [parse_line(idx, line) for idx, line in enumerate(path.read_text().splitlines(True), 1)]


def first_pass(lines: List[ParsedLine]) -> Dict[str, int]:
    labels: Dict[str, int] = {}
    pc = 0
    for line in lines:
        if line.label:
            if line.label in labels:
                raise AsmError(f"line {line.lineno}: duplicate label '{line.label}'")
            labels[line.label] = pc
        if line.mnemonic:
            pc += 2
    return labels


def assemble(lines: List[ParsedLine], labels: Dict[str, int]) -> List[Tuple[ParsedLine, int, int]]:
    output = []
    pc = 0
    for line in lines:
        if not line.mnemonic:
            continue
        word = encode_instruction(line, labels)
        output.append((line, pc, word & 0xFFFF))
        pc += 2
    return output


def format_output(items: List[Tuple[ParsedLine, int, int]]) -> str:
    parts = ["@0"]
    for line, pc, word in items:
        hi = (word >> 8) & 0xFF
        lo = word & 0xFF
        parts.append(f"// {line.original.strip()}")
        parts.append(f"{hi:08b} {lo:08b}")
    return "\n".join(parts) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble the project ISA into .bin format")
    parser.add_argument("source", type=Path, help="assembly source file")
    parser.add_argument("output", type=Path, nargs="?", help="output .bin path")
    args = parser.parse_args()

    out_path = args.output
    if out_path is None:
        out_path = args.source.with_suffix(".bin")

    try:
        lines = parse_source(args.source)
        labels = first_pass(lines)
        items = assemble(lines, labels)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(format_output(items))
    except AsmError as exc:
        print(f"assembler error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
