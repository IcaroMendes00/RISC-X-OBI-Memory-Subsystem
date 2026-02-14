# RISC-X-OBI-Memory-Subsystem
This repository contains the implementation of a custom memory subsystem for a RISC-V core. The memory architecture was inspired by the PULPino SoC, adopting a modified Harvard model with a unified memory map, and uses the OBI (Open Bus Interface) protocol for direct communication with the processor.

The project consists of the following main hardware modules (RTL):

###sp_ram_obi.sv (Single-Port RAM OBI): Generic synchronous RAM module. It abstracts a register array under an OBI wrapper. It responds instantly to the req signal (zero wait-states for gnt) and delivers the data in the next cycle. It has full write mask support (byte enable), making it ideal for both Instruction Memory (IRAM) and Data Memory (DRAM).

###boot_rom_obi.sv (Boot ROM OBI): Read-only memory module used to store the bootloader or initial firmware. Writing is disabled by hardware, and the content is preloaded via a static file (e.g., .hex or .slm) during simulation initialization.

###pulpino_memory_subsystem.sv (Memory Wrapper/Decoder): The top module of the subsystem. It receives both OBI buses from the processor (Instruction and Data) and acts as a router. Based on the memory map, it decodes the requested address and activates the corresponding physical block (ROM, IRAM, or DRAM), multiplexing the responses back to the kernel.
