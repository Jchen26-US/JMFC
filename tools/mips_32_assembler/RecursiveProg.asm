        addi $a0, $zero, 5      # n = 5
        addi $sp, $zero, 1000   # fake stack pointer (memory address)

        addi $v0, $zero, 1      # result = 1

        j CHECK

# -------------------------
# LOOP ENTRY (recursive call simulation)
# -------------------------
LOOP:
        sw   $a0, 0($sp)        # push n
        addi $sp, $sp, -4

        addi $a0, $a0, -1       # n = n - 1

# -------------------------
CHECK:
        addi $t0, $zero, 1
        beq  $a0, $zero, BASE   # if n == 0 go base (still uses branch)
        beq  $a0, $t0, BASE     # if n == 1 go base

        j LOOP

# -------------------------
# BASE CASE
# -------------------------
BASE:
        beq  $sp, $zero, DONE   # stack empty? finish

        lw   $t1, 0($sp)        # pop n
        addi $sp, $sp, 4

        mul  $v0, $v0, $t1      # v0 *= n

        j BASE

# -------------------------
# END
# -------------------------
DONE:
        sw   $v0, 252($zero)    # store result
        j DONE                  # infinite halt loop