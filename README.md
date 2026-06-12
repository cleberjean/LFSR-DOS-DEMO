LFSR Visualization Demo for DOS and 8086 CPU
============================================

Um efeito clássico de *Fade In* e *Fade Out* gráfico escrito em **Assembly x86 puro (16-bits)** para o processador Intel 8086. O programa utiliza um algoritmo **LFSR (Linear Feedback Shift Register)** do tipo Galois para preencher e limpar a tela pixel por pixel de forma pseudo-aleatória, sem repetir coordenadas, simulando um efeito de "chuvisco" ou "estática" controlado.

O projeto roda em **Modo 13h** (320x200 pixels, 256 cores) e foi totalmente otimizado para ambientes DOS genuínos ou emuladores (como DOSBox).

---

## 🛠️ Como Compilar e Executar

### Pré-requisitos
Você precisará do **NASM** (Netwide Assembler) instalado na sua máquina.

### Compilação
Abra o terminal na pasta do projeto e execute o comando abaixo para gerar o executável compacto `.COM`:
```bash
nasm lfsr.asm -o lfsr.com

**How to Run**

The generated file is less than 1 KB. You can execute it directly in:

    A retro PC running native MS-DOS / FreeDOS.

    The DOSBox emulator (simply drag and drop the lfsr.com file into the emulator window or mount its directory as a drive).

    Press the Esc key at any time to terminate the program and return to the DOS prompt.

**How the LFSR Works in This Project**

A Linear Feedback Shift Register is a mathematical structure that generates a sequence of numbers that looks random but is completely deterministic.
The 320x200 Challenge

The screen in Mode 13h has exactly 64,000 pixels (320x200). A standard 16-bit LFSR has a maximum period of 2^16 - 1 = 65,535 unique states. If we plotted all of them, the program would attempt to draw outside the video memory limits (0xA000), breaking the effect or corrupting other data.

To solve this, this code implements a Bound Check inside the Galois generator:

    The LFSR generates the next number using the feedback mask 0xB400.

    If the generated number is greater than 64,000, the code discards the value instantly (ja Get_LFSR_Number) and calculates the next one until it finds a valid index.

    This ensures that we cover exactly the 64,000 pixels on the screen without repetition and without overflowing the memory.

**The "Zero" Problem**

By definition, the value 0 is forbidden in an LFSR because it causes the algorithm to lock into an infinite loop of zeros. However, video memory starts at offset 0.

The Solution: The program generates a sequence from 1 to 64,000. Before plotting the pixel on the screen with the stosb instruction, the destination register (DI) is decremented (dec di). This way, we map the sequence perfectly to the video memory offset range of 0 to 63,999.

**Optimization & Engineering Highlights**

    Exclusive Register Usage (BP): The LFSR seed is permanently kept inside the BP register during critical animation loops. This eliminates the RAM read/write bottleneck, ensuring the maximum frame rate the processor can deliver.

    Color Alchemy via XOR Inversion: The text rendering routine (Draw_Char_Mode_13h) uses the 0x0E mask via the xor bl, bh instruction. This creates an automatic dynamic contrast: the text turns Blue over the full screen (White) and Yellow over the clean screen (Black), without needing a single line change in the character generator logic.

    Vertical Retrace Synchronization (INT 10h): The code monitors the CRT status port (0x03DA) to synchronize plotting with the monitor's electron beam, preventing screen tearing.

    Temporal Synchronization Break: The Pause procedure intentionally adds 4 extra frames beyond the regular 150 frames (2.5 seconds at 60Hz). This asymmetry prevents the system clock and the LFSR cycle from falling into harmonic synchronization, ensuring that the static noise of each cycle feels organic and unpredictable.

**Author**

    Cleber Jean Barranco - cleberjean@hotmail.com

    Developed in: June 2026.
