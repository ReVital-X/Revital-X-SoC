import re

# -----------------------------
# Opcode / funct tables
# -----------------------------

R_TYPE = {
    "add":  ("0110011", "000", "0000000"),
    "sub":  ("0110011", "000", "0100000"),
    "xor":  ("0110011", "100", "0000000"),
    "or":   ("0110011", "110", "0000000"),
    "and":  ("0110011", "111", "0000000"),
    "sll":  ("0110011", "001", "0000000"),
    "srl":  ("0110011", "101", "0000000"),
    "sra":  ("0110011", "101", "0100000"),
    "slt":  ("0110011", "010", "0000000"),
    "sltu": ("0110011", "011", "0000000"),
}

I_TYPE = {
    "addi":  ("0010011", "000"),
    "xori":  ("0010011", "100"),
    "ori":   ("0010011", "110"),
    "andi":  ("0010011", "111"),
    "slti":  ("0010011", "010"),
    "sltiu": ("0010011", "011"),
    "slli":  ("0010011", "001"),
    "srli":  ("0010011", "101"),
    "srai":  ("0010011", "101"),
    "lb":    ("0000011", "000"),
    "lh":    ("0000011", "001"),
    "lw":    ("0000011", "010"),
    "lbu":   ("0000011", "100"),
    "lhu":   ("0000011", "101"),
    "jalr":  ("1100111", "000"),
}

# -----------------------------
# Helpers
# -----------------------------

def reg_to_bin(reg):
    return format(int(reg.replace("x", "")), "05b")

def imm_to_bin(value, bits):
    value = int(value)
    if value < 0:
        value = (1 << bits) + value
    return format(value, f"0{bits}b")

def bin_to_hex(binary):
    return format(int(binary, 2), "08x")

# -----------------------------
# Assembler
# -----------------------------

def assemble_line(line):
    line = line.split("#")[0].strip()
    if not line:
        return None

    parts = re.split(r"[,\s()]+", line)
    inst = parts[0]

    # ---------------- R TYPE ----------------
    if inst in R_TYPE:
        opcode, funct3, funct7 = R_TYPE[inst]
        rd  = reg_to_bin(parts[1])
        rs1 = reg_to_bin(parts[2])
        rs2 = reg_to_bin(parts[3])

        binary = funct7 + rs2 + rs1 + funct3 + rd + opcode
        return bin_to_hex(binary)

    # ---------------- I TYPE ----------------
    elif inst in I_TYPE:
        opcode, funct3 = I_TYPE[inst]

        # LOAD / JALR format: rd imm rs1
        if inst in ["lb","lh","lw","lbu","lhu","jalr"]:
            rd  = reg_to_bin(parts[1])
            imm = imm_to_bin(parts[2], 12)
            rs1 = reg_to_bin(parts[3])

        # SHIFT special case
        elif inst in ["slli","srli","srai"]:
            rd  = reg_to_bin(parts[1])
            rs1 = reg_to_bin(parts[2])
            shamt = imm_to_bin(parts[3], 5)

            if inst == "srai":
                imm = "0100000" + shamt
            else:
                imm = "0000000" + shamt

        # Normal I-type
        else:
            rd  = reg_to_bin(parts[1])
            rs1 = reg_to_bin(parts[2])
            imm = imm_to_bin(parts[3], 12)

        binary = imm + rs1 + funct3 + rd + opcode
        return bin_to_hex(binary)

    else:
        raise ValueError(f"Unsupported instruction: {inst}")

# -----------------------------
# File conversion
# -----------------------------

def assemble_file(input_file, output_file):
    with open(input_file, "r") as f:
        lines = f.readlines()

    machine_code = []
    for line in lines:
        hexcode = assemble_line(line)
        if hexcode:
            machine_code.append(hexcode)

    with open(output_file, "w") as f:
        for code in machine_code:
            f.write(code + "\n")

    print(f"Output written to {output_file}")

import os

if __name__ == "__main__":
    base_dir = os.path.dirname(__file__)
    input_path = os.path.join(base_dir, "Exhaustive.asm")
    output_path = os.path.join(base_dir, "output.txt")

    assemble_file(input_path, output_path)