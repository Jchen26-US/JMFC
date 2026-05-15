.org 0
Main:
    addi $v0, $zero, 10     # 2002000a
    addi $v1, $zero, 15     # 2003000f

    mult $v0, $v1           # 00430018
    mfhi $t0                # 00004010   # use temp reg (safer than overwriting result)
    mflo $t1                # 00004812

    add  $v0, $t0, $zero    # move HI into v0
    add  $v1, $t1, $zero    # move LO into v1

    sw $v1, 84($zero)       # store result

    sw $v0, 252($zero)      # HALT TRIGGER

End:
    .end