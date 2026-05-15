main:
    addi $a0, $zero, 5
    addi $a1, $zero, 7

    j proc1

return_from_proc1:
    sw $v0, 252($zero)


# -------------------
# proc1
# computes a0+a1
# then "calls" proc2
# -------------------
proc1:
    add $t0, $a0, $a1

    j proc2

return_from_proc2:
    add $v0, $t1, $zero
    j return_from_proc1


# -------------------
# proc2
# doubles t0
# -------------------
proc2:
    add $t1, $t0, $t0
    j return_from_proc2