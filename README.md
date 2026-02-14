# RISC-X OBI Memory Subsystem

This repository contains the implementation of a custom memory subsystem for a RISC-V core. The memory architecture was inspired by the PULPino SoC, adopting a modified Harvard model with a unified memory map, and uses the **OBI (Open Bus Interface)** protocol for direct communication with the processor.

## Hardware Modules (RTL)

The project consists of the following main hardware modules:

* **`sp_ram_obi.sv` (Single-Port RAM OBI)**
  * Generic synchronous RAM module that abstracts a register array under an OBI wrapper. 
  * Responds instantly to the `req` signal (zero wait-states for `gnt`) and delivers data in the next cycle. 
  * Features full write mask support (`byte enable`), making it ideal for both Instruction Memory (IRAM) and Data Memory (DRAM).

* **`boot_rom_obi.sv` (Boot ROM OBI)**
  * Read-only memory module used to store the bootloader or initial firmware. 
  * Writing is disabled by hardware, and the content is preloaded via a static file (e.g., `.hex` or `.slm`) during simulation initialization.

* **`pulpino_memory_subsystem.sv` (Memory Wrapper/Decoder)**
  * The top module of the subsystem. 
  * Receives both OBI buses from the processor (Instruction and Data) and acts as a router. 
  * Based on the memory map, it decodes the requested address, activates the corresponding physical block (ROM, IRAM, or DRAM), and multiplexes the responses back to the core.
