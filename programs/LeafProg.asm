addi $t0, $zero, 5      # t0 = 5
addi $t1, $zero, 7      # t1 = 7
add  $v0, $t0, $t1      # v0 = 12

sw   $v0, 252($zero)    # halt condition for tb