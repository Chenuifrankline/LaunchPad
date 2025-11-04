.section .data
.syntax unified

.equ RCGC_GPIO_R, 0x400FE608 // control register that enables clocks for GPIO ports (A-F) 
.equ RCGC_GPIO_PORT_A, 0x01 // Offsets for the differnt ports
.equ RCGC_GPIO_PORT_B, 0x02
.equ RCGC_GPIO_PORT_C, 0x04
.equ RCGC_GPIO_PORT_D, 0x08
.equ RCGC_GPIO_PORT_E, 0x10
.equ RCGC_GPIO_PORT_F, 0x20

.equ GPIO_PORT_F_DATA_R, 0x400253FC // Address of the data registers of port F    // Read/write pin values
.equ GPIO_PORT_F_DEN_R,  0x4002551C                                               //Enable digital function
.equ GPIO_PORT_F_DIR_R,  0x40025400                                               //Set input/output direction.
.equ GPIO_PORT_F_PUR_R,  0x40025510                                               //Pull-up resistor (important for buttons)

.equ GPIO_PORT_D_DATA_R, 0x400253FC
.equ GPIO_PORT_D_DEN_R,  0x4002551C
.equ GPIO_PORT_D_DIR_R,  0x40025400
.equ GPIO_PORT_D_PUR_R,  0x40025510

//Define bitmasks for specific GPIO pins.
.equ PIN0, 0x01 // Switch 2
.equ PIN1, 0x02 // red
.equ PIN2, 0x04 // blue
.equ PIN3, 0x08 // green
.equ PIN4, 0x10 // Switch 1
.equ PIN5, 0x20
.equ PIN6, 0x40
.equ PIN7, 0x80
.equ ALL_PINS, 0xFF

.section .text
.global main
.align

main:   
//program entry point.. Button  not pressed data register is alway =1

init_hardware:
    // Enable clock for GPIO Port F
    ldr r0, =RCGC_GPIO_R       
    ldr r1, [r0]               
    orr r1, r1, RCGC_GPIO_PORT_F  // Enable clock for Port F
    str r1, [r0]                // Write updated value back to the register

    // Enable pull-up resistor for switch (PIN4)
    ldr r0, =GPIO_PORT_F_PUR_R  
    ldr r1, [r0]               
    orr r1, r1, PIN4            // Enable pull-up for Switch (PIN4)
    str r1, [r0]                // Write back the updated value

    // Enable digital functionality for LEDs and Switch
    ldr r3, =GPIO_PORT_F_DEN_R  
    ldr r4, [r3]               
    orr r4, r4, PIN1 | PIN2 | PIN3 | PIN4  // Enable digital functionality for LEDs and switch
    str r4, [r3]                // Write back the updated value

    // Set pins for LEDs (Red, Blue, Green) as outputs
    ldr r3, =GPIO_PORT_F_DIR_R  
    ldr r4, [r3]              
    orr r4, r4, PIN1 | PIN2 | PIN3  // Set Red, Blue, Green as outputs
    str r4, [r3]                // Write back the updated direction

    // Set LEDs to magenta (Red + Blue ON)
    ldr r3, =GPIO_PORT_F_DATA_R  
    ldr r4, [r3]                 
    orr r4, r4, PIN1 | PIN2      // Set Red and Blue LEDs to ON (Magenta)
    str r4, [r3]                 // Write back the updated data value

    // Set r7 to a specific bit pattern for later use (Animation or Delay)
    mov r7, #0x80                // Set r7 to 0x80  bit 7 is ON, and all other bits are OFF


endless_loop:
 //    
 // delay = desired_time_in_seconds × CPU_clock_speed_in_Hz / cycles_per_iteration
 //   ldr r0, =0x51616         // Load the value for a 1-second delay 
 //   mov r1, #0
 //   bl main_loop

    // Wait for 1 second
    ldr r0, = 0x51616         // Load the value for 1-second delay 
    mov r1, #0
    bl main_loop

    // Check if button is pressed (PIN4)
    ldr r0, =GPIO_PORT_F_DATA_R 
    ldr r1, [r0]                 
    and r2, r1, PIN4             // Mask out all but the button pin (PIN4)
    cmp r2, PIN4                 // Compare if button is pressed (PIN4 should be 1 when not pressed)
    beq handle_btn_not_pressed   // If button not pressed, jump to handle_btn_not_pressed
    b handle_btn_pressed         // If button pressed, jump to handle_btn_pressed

handle_btn_not_pressed:
    // Turn OFF Green LED to make color Magenta (Red + Blue ON)
    ldr r3, =GPIO_PORT_F_DATA_R  // Load address of data register
    ldr r4, [r3]                 // Read current data value
    //and,,tst
    bic r4, r4, PIN3             // Clear bit 3 (Green LED OFF)
    str r4, [r3]                 // Write back updated data value

    // Shift bit pattern in r7 to the left (for animation)
    lsl r7, r7, #1               // Shift left by 1 bit
    cmp r7, #0                   // Compare if r7 reached 0
    bne endless_loop             // If not 0, continue looping
    mov r7, #0x01                // Reset r7 to 0x01 when it reaches 0
    b endless_loop               // Continue looping

handle_btn_pressed:
    // Turn on all LEDs (White: Red + Blue + Green)
    ldr r3, =GPIO_PORT_F_DATA_R  // Load address of data register
    ldr r4, [r3]                 // Read current data value
    orr r4, r4, PIN1 | PIN2 | PIN3  // Set all LEDs (Red, Blue, Green) ON
    str r4, [r3]                 // Write back updated data value

    // Shift bit pattern in r7 to the right (for animation)
    lsr r7, r7, #1               // Shift right by 1 bit
    cmp r7, #0                   // Compare if r7 reached 0
    bne endless_loop             // If not 0, continue looping
    mov r7, #0x80000000          // Reset r7 to 0x80000000 when it reaches 0
    b endless_loop               // Continue looping

main_loop:
    // Delay loop for 1 second (approximately)
    sub r0, r0, #1               // Decrement r0 by 1
    cmp r0, r1                   // Compare r0 with r1
    bne main_loop                // If not zero, repeat the loop
    bx lr                        // Return from the loop when done
.end