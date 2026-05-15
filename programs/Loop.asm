# loop_test.asm
# A memory-intensive test demonstrating temporal locality

# Array Base Address = 100
# Initialize Array Data (Manually simulating data in memory)
addi $t0, $0, 100   # base ptr = 100
addi $t1, $0, 5
sw   $t1, 0($t0)    # mem[100] = 5
addi $t1, $0, 10
sw   $t1, 4($t0)    # mem[104] = 10
addi $t1, $0, 15
sw   $t1, 8($t0)    # mem[108] = 15
addi $t1, $0, 20
sw   $t1, 12($t0)   # mem[112] = 20

# Setup loop counter
addi $s0, $0, 5     # outer loop = 5 iterations
addi $s1, $0, 0     # total_sum = 0

outer_loop:
    beq $s0, $0, done
    
    # Reset pointer
    addi $t0, $0, 100
    
    # Fetch from array (Will miss on first pass, hit on subsequent passes)
    lw $t2, 0($t0)  # load mem[100]
    add $s1, $s1, $t2
    
    lw $t2, 4($t0)  # load mem[104]
    add $s1, $s1, $t2
    
    lw $t2, 8($t0)  # load mem[108]
    add $s1, $s1, $t2
    
    lw $t2, 12($t0) # load mem[112]
    add $s1, $s1, $t2
    
    # Decrement loop counter
    addi $s0, $s0, -1
    
    j outer_loop

done:
    # Halt via Memory-Mapped I/O
    addi $t7, $0, 1
    sw   $t7, 252($0)