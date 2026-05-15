addi $v0, $0, 10      # $v0 = 10
addi $v1, $0, 15      # $v1 = 15
mult $v0, $v1         # HiLo = 10 * 15 = 150
mflo $v0              # $v0 = LO = 150
sw   $v0, 84($0)      # MEM[84] = 150
sw   $v0, 252($0)     # MEM[252] = 150 → HALT