.text

main:
    addi $a0, $zero, 4
    j    sum_4

done:
    sw   $v0, 252($zero)

sum_4:
    addi $t0, $zero, 1
    beq  $a0, $t0, base_4
    sw   $a0, 4($zero)
    addi $a0, $a0, -1
    j    sum_3

ret_from_3_at_4:
    lw   $t0, 4($zero)
    add  $v0, $v0, $t0
    j    done

base_4:
    addi $v0, $zero, 1
    j    done

sum_3:
    addi $t0, $zero, 1
    beq  $a0, $t0, base_3
    sw   $a0, 8($zero)
    addi $a0, $a0, -1
    j    sum_2

ret_from_2_at_3:
    lw   $t0, 8($zero)
    add  $v0, $v0, $t0
    j    ret_from_3_at_4

base_3:
    addi $v0, $zero, 1
    j    ret_from_3_at_4

sum_2:
    addi $t0, $zero, 1
    beq  $a0, $t0, base_2
    sw   $a0, 12($zero)
    addi $a0, $a0, -1
    j    sum_1

ret_from_1_at_2:
    lw   $t0, 12($zero)
    add  $v0, $v0, $t0
    j    ret_from_2_at_3

base_2:
    addi $v0, $zero, 1
    j    ret_from_2_at_3

sum_1:
    addi $v0, $zero, 1
    j    ret_from_1_at_2