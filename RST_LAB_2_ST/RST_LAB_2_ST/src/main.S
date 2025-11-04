.section .data
.syntax unified
.thumb

// definiert BIT0 bis BIT31
.altmacro
.macro define_bit a
    .equ BIT\a, (1 << \a)
.endm

.set i, 0
.rept 32
    define_bit %i
    .set i,i+1
.endr

.equ RCGC_GPIO_R, 0x400FE608
.equ RCGC_GPIO_PORT_A, BIT0
.equ RCGC_GPIO_PORT_B, BIT1
.equ RCGC_GPIO_PORT_C, BIT2
.equ RCGC_GPIO_PORT_D, BIT3
.equ RCGC_GPIO_PORT_E, BIT4
.equ RCGC_GPIO_PORT_F, BIT5

.equ LED_R, BIT1
.equ LED_B, BIT2
.equ LED_G, BIT3

.equ GPIO_PORT_F_BASE,   0x40025000
.equ GPIO_DATA_OFF,       0x3FC
.equ GPIO_DIR_OFF,        0x400
.equ GPIO_PUR_OFF,        0x510
.equ GPIO_DEN_OFF,        0x51C
.equ GPIO_PORT_F_DATA_R, GPIO_PORT_F_BASE + GPIO_DATA_OFF
.equ GPIO_PORT_F_DIR_R,  GPIO_PORT_F_BASE + GPIO_DIR_OFF
.equ GPIO_PORT_F_PUR_R,  GPIO_PORT_F_BASE + GPIO_PUR_OFF
.equ GPIO_PORT_F_DEN_R,  GPIO_PORT_F_BASE + GPIO_DEN_OFF

.equ ST_BASE,           0xE000E000
.equ ST_CTRL_OFF,       0x10
.equ ST_RELOAD_OFF,     0x14
.equ ST_CURRENT_OFF,    0x18
.equ ST_CTRL_R,         ST_BASE + ST_CTRL_OFF
.equ ST_RELOAD_R,       ST_BASE + ST_RELOAD_OFF
.equ ST_CURRENT_R,      ST_BASE + ST_CURRENT_OFF 
.equ ST_CTRL_ENABLE,    BIT0
.equ ST_CTRL_INTEN,     BIT1
.equ ST_CTRL_CLK_SRC,   BIT2
.equ ST_CTRL_COUNT,     BIT16

s:                            //Anzahl der Sekunden seit Start
.word 0
ms:                           // Anzahl der Millisekunden seit der letzten vollen Sekunde
.word 0

.section .text
.global main
.global sys_tick_handler
.align

init_hardware:
// GPIO Port F aktivieren
ldr r0, =RCGC_GPIO_R
ldr r1, [r0]
orr r1, r1, #RCGC_GPIO_PORT_F
str r1, [r0]

// LED-Pin als Ausgang konfigurieren
ldr r0, =GPIO_PORT_F_DIR_R
ldr r1, [r0]
orr r1, r1, #BIT1  
str r1, [r0]

// Digitale Funktion aktivieren
ldr r0, =GPIO_PORT_F_DEN_R
ldr r1, [r0]
orr r1, r1, #BIT1
str r1, [r0]

// SysTick mit Systemtakt aktivieren
ldr r0, =ST_CTRL_R
ldr r1, [r0]
orr r1,r1, #(ST_CTRL_ENABLE | ST_CTRL_CLK_SRC)
str r1, [r0]
   
 
// Reload-Wert für 1ms bei 16MHz setzen
ldr r0, =ST_RELOAD_R
ldr r1, =16000-1 // (16.000.000 Hz / 1000) 
str r1, [r0]


bx lr  // return to the caller address to continue execution


main:
bl init_hardware 
bl check_op_time
bl sys_tick_handler
//bl check_stack


main_loop:

poll_systick:// checkin the counter ob er ist fertig (reicht 0) oder nicht 
    ldr r0, =ST_CTRL_R
    ldr r1, [r0]
    tst r1, #ST_CTRL_COUNT //macht ein and operation zwichen r1 und St-ctrl-count um die countflag(bit nummer 16) zu sehen ,weil er andert wenn die counter wird 0 
    // das inhalt andert nicht aber nurr die Z (zero flag)                                  ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
     
    
    beq poll_systick  // uberprufen ob  z=1 (counter nicht erreicht die null ) und dann zuruck zu poll systick         
    bl sys_tick_handler // aufruf fur systick handler ,die adresse von zuruck geht in r1 direkt
    b main_loop


//.thumb_func
sys_tick_handler: 
push {r0, r1, lr}// we push lr to save the return address or the value r1,r0 lr (link register)

    ldr r0, =ms
    ldr r1, [r0]
    add r1,r1, #1 //fugen die value in r1 (ms) mit  ein  1 das heist fugen die r1 value mit 1ms
    str r1, [r0]

    cmp r1, #1000 // 1000 ms --> 1 s LED jede Sekunde ihren Zustand [An/Aus] wechselt wejn sie reicht 1000
    blt skip_state // wenn wert weniger als 1000 geht in die skip state  to vermeiden die anderung von situation  led ++++++++++++++++++++

    mov r1, #0 // machen die ms wieder 0 
    str r1, [r0]  // store 0 in ms 

    ldr r0, =s // counter con sekunde zeit anfang 
    ldr r1, [r0]
    add r1,r1, #1 // vergroseren der wert von s mit 1s 
    str r1, [r0]  

    ldr r0, =GPIO_PORT_F_DATA_R // fur LED
    ldr r1, [r0]
    eor r1, r1,#BIT1  //  xor um die situation von Led  zu wechseln (wenn on wird off und wenn off wird on )  ++++++++++++ 
    str r1, [r0]

skip_state:

    pop {r0, r1, lr} // machen die registern zuruck von stack zu ihre initial zustand 
    bx lr // zuruck zu adresse von  r1 (vor aufruf bl systick handler)
// 
check_stack:
    ldr r1, =0x1D34A          
    ldr r2, =0x1A24F
    ldr r3, =0x1B34C
   push {r1, r2,r3} // machen die 3 werte in stack             
    nop
    pop {r1, r2,r3} // bekommen die werte zuruck von stack zu registers             
    bx lr // zuruck zu return loop mit nutzung von lr
check_op_time:
    // 2 ticks per
    check_op_time:
    // 2 ticks per
    ldr r4,=ST_CURRENT_R
    ldr r3, [r4]
    
    nop // ausfuhrung zeit  : Ein einzelner nop-Befehl braucht genau einen Taktzyklus (bei ARM Cortex-M-Prozessoren).
// Das entspricht bei 16 MHz Takt: 1 / 16.000.000 s = 62,5 ns
    nop // jede nop befehl dauert 1 taktzyklus weil Prozessor keine Operation durchführt, aber den Befehl trotzdem in seiner Pipeline verarbeiten muss.

//Dies ist der schnellste Befehl in der Liste, weil keine Daten geladen, gespeichert oder verarbeitet werden müssen.
    nop
    nop
    nop

    nop

    
    nop

    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop

    nop
 
 ldr r5, [r4]
// ausführung zeit = 2 ticks
ldr r3, [r4]

    ldr r0, [sp] // load the value von die wert im adresse stack pointer sp zu r0 
    ldr r0, [sp]// ausführung zeit :ldr = Load Register

//Diese Instruktion lädt einen 32-Bit-Wert (Wort) aus dem Speicher in das Register r0.

//[sp] bedeutet: Lade von der Adresse, die im Stack Pointer (sp) gespeichert ist.

//Stack liegt normalerweise im SRAM (interner RAM
    ldr r0, [sp] // der Prozessor zuerst die Adresse aus sp lesen muss, dann auf den Speicher zugreifen und schließlich den Wert in r0 laden.

//RAM-Zugriff braucht etwas Zeit → daher ca. 2 Takte.
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]
    ldr r0, [sp]

ldr r5, [r4]
 // ausführung zeit = 2 ticks per

 ldr r3, [r4]
    str r0, [sp, #-4] // hier wir loader die wert von r0 zu stack (-4: weil stack store von die hoch adrese bis unten in speicher ) 
    //und jedes mal die pusch verringert der wert sp mit 4 weil er store in jedes word =4bits 
//In diesem Fall wird der Stack Pointer sp um 4 Bytes 
    str r0, [sp, #-4]// [sp, #-4]: Das ist die Speicheradresse, an die der Wert aus r0 gespeichert wird. 
    str r0, [sp, #-4] //str r0, [sp, #-4] ≈ 2 Ticks
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    str r0, [sp, #-4]
    
ldr r5, [r4]

//(die Größe eines Wortes) nach unten verschoben (da negative Verschiebung) und diese neue Adresse wird verwendet.


    //ausführung zeit von (str r0, [sp, #-4]! ) ≈ 3–4 Ticks
    str r0, [sp, #-4]! // lade der wert von r0 in sp-4 und imemr macht ein inkrementation von sp 

    str r0, [sp, #-4]!//!: Das Ausrufezeichen bedeutet, dass die Adressierung im "Pre-Decrement" Modus erfolgt, was bedeutet, dass die Adresse sp vor dem Speichern um 4 
    // Bytes verringert wird.
    str r0, [sp, #-4]!// speichert den Wert an sp - 4 und reduziert anschließend den Stack Pointer sp um 4 (also sp = sp - 4). dauert 2 taktzyklus 
// und dann Das Ausrufezeichen ! bedeutet, dass sp aktualisiert wird. dauert 1 taktzyklus 
// so zusammmen ist die zeit 2+1 = 3 ticks

    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!
    str r0, [sp, #-4]!

ldr r5, [r4]

   ldr r1, =0x51
    ldr r0, =0x3        //Ergebnis in r2

    // 1 ticks per weil sie ist eine einfache operation die er alu effizient sie einfuhren und 
    //auch beeinflusst nicht mit austausch von operatoren weil sie ist kommutativ 
     ldr r3, [r4]
    mul r2, r0, r1   
    
    mul r2, r0, r1 
    mul r2, r0, r1 
    mul r2, r1, r0
 ldr r5, [r4]
    // 6 bis 12  ticks per ++++++

       ldr r3, [r4]
    sdiv r2, r1, r0  
    //in division es ist beeinflusst bei die austausch ,das hangt ab von die prozessor ,es gibt alte prozessoren nehmen mehre schritten um die division ausfuhren 
    // aber beeinflusst nicht so viel auf die zeit von ausführung 
    // Einige Prozessoren können schneller sein, wenn eine kleinere Zahl durch eine größere Zahl geteilt wird,
    //da der Prozessor die Division möglicherweise effizienter verarbeitet, wenn der Divisor (der Nenner) größer ist. Dieser Unterschied ist jedoch in den meisten Fällen in der Regel sehr klein

    sdiv r2, r1, r0 
    sdiv r2, r1, r0  
    sdiv r2, r1, r0 

    sdiv r2, r1, r0     // Dies liegt daran das sdiv mehrere
                        // Instruktionen benötigt als MUL   -> außerdem wird signed und unsigned berücksichtigt
    sdiv r2, r1, r0
ldr r5, [r4]
  
   //Ausführungszeit pro Register:ede push-Operation benötigt 2 Ticks für ein Register und Takt mehr für jedes zusätzliches register 
    //Einen Tick für die Decrementierung des Stack Pointers (SP) und 
//Einen Tick für das Speichern des Registerwertes im Stack
    push {r1} 
    push {r1}
    push {r1}
    push {r1} 

    // 8 ticks per
    push {r1, r2}  
    push {r1, r2} 
    push {r1, r2} 
    push {r1, r2} 

.end
// erklarung welche befehl dauert langer und warum :Der Befehl nop ist der schnellste, da er keine Operation durchführt.

//ldr r0, [sp] und str r0, [sp, #-4] sind in der Regel gleich schnell (etwa 2 Takte), mit einer kleinen zusätzlichen Möglichkeit bei ldr, dass es etwas länger dauert, wenn der Cache-Miss eintritt.

//*Der Befehl str r0, [sp, #-4]! könnte theoretisch minimal länger dauern,
//weil er den Stack Pointer zusätzlich dekrementiert, aber in der Praxis ist der Unterschied vernachlässigbar, es sei denn, es gibt andere Architekturdetails, die dies beeinflussen.                  //returns to where the function was called in main


.end
