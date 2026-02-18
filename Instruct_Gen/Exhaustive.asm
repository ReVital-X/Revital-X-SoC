# =========================
# R-TYPE TESTS
# =========================

add   x1,  x2,  x3
sub   x4,  x5,  x6
xor   x7,  x8,  x9
or    x10, x11, x12
and   x13, x14, x15
sll   x16, x17, x18
srl   x19, x20, x21
sra   x22, x23, x24
slt   x25, x26, x27
sltu  x28, x29, x30


# =========================
# I-TYPE ARITHMETIC
# =========================

addi  x1,  x2,  0
addi  x3,  x4,  1
addi  x5,  x6, -1
addi  x7,  x8, 2047       # max positive 12-bit
addi  x9,  x10, -2048     # min negative 12-bit

xori  x11, x12, 15
ori   x13, x14, 31
andi  x15, x16, 63

slti  x17, x18, -5
sltiu x19, x20, 5


# =========================
# SHIFT IMMEDIATE
# =========================

slli  x21, x22, 1
slli  x23, x24, 31

srli  x25, x26, 1
srli  x27, x28, 31

srai  x29, x30, 1
srai  x31, x1, 31


# =========================
# LOAD TESTS
# =========================

lb    x2,  0(x3)
lh    x4,  4(x5)
lw    x6,  8(x7)
lbu   x8,  12(x9)
lhu   x10, 16(x11)

# Negative offset loads
lw    x12, -4(x13)


# =========================
# JALR TEST
# =========================

jalr  x14, 0(x15)
jalr  x16, 4(x17)
jalr  x18, -4(x19)