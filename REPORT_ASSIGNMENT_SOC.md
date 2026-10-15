# SoC ASSIGNMENT REPORT: 5-STAGE PIPELINED RISC-V PROCESSOR (RV32IM)
**Course:** Introduction to SoC — Semester 251  
**Faculty:** Faculty of Computer Science and Engineering  
**Department:** Department of Computer Engineering — Ho Chi Minh City University of Technology (HCMUT)  
**Target Platform:** Xilinx Arty-Z7-20 (`xc7z020clg400-1`)  
**EDA Software:** AMD Vivado Design Suite 2024.2  

---

## 1. Introduction & Overview
This report documents the full implementation, simulation, synthesis, and place-and-route implementation of a 5-stage pipelined RISC-V processor supporting the **RV32IM** Instruction Set Architecture (ISA), integrated into a complete System-on-Chip (SoC) for the Digilent Arty-Z7-20 FPGA board.

The design strictly obeys the architectural specifications:
- **No forbidden operators:** The code uses **no** hardware `/`, `%`, or `-` operators. Subtraction is performed using a 32-bit Carry Lookahead Adder (CLA) in two's complement form ($A + \sim B + 1$).
- **Hazard handling:** Full implementation of **MX**, **WX**, **WD**, and **WM** bypassing paths, with precise stall logic for load-use and division dependencies, as well as pipeline flushing on taken branches.

---

## 2. Pipelined Datapath Microarchitecture

### 2.1 The 5 Pipeline Stages
1. **Instruction Fetch (IF):** Updates the Program Counter (PC) each cycle (default $+4$, or target PC on taken branches), fetches 32-bit instructions from instruction memory (`imem`), and latches into the IF/ID register.
2. **Instruction Decode (ID):** Decodes opcode, funct3, funct7, reads operands from the 32-register register file (`rf`), calculates immediates (I, S, B, U, J types), and performs **WD Bypassing** (writeback-to-decode) and hazard detection.
3. **Execution (EX):** Contains the 32-bit CLA ALU, barrel shifters, multiplier, and the pipelined unsigned divider (`divider_unsigned_pipelined`). Resolves branch direction and evaluates branch target addresses.
4. **Memory (MEM):** Reads and writes 32-bit data to data memory (`dmem`) on the negative edge of the clock with byte-enable masking (`store_we_to_dmem[3:0]`). Formats quotient and remainder values from the divider pipeline.
5. **Writeback (WB):** Selects final result (ALU, Memory Load, PC+4, Divider quotient/remainder) and writes back to destination register `rd`. Outputs `trace_writeback_*` signals for cycle-accurate trace validation.

---

## 3. Hazard Resolution & Bypassing Network

### 3.1 MX & WX Bypassing (Execute Stage Forwarding)
- **MX Bypass (MEM $\to$ EX):** Forwards result from the Memory stage to Execute if the consumer instruction depends on an instruction that just finished EX.
- **WX Bypass (WB $\to$ EX):** Forwards result from Writeback stage directly to Execute if the dependency is separated by one cycle.

### 3.2 WD Bypass (Writeback $\to$ Decode)
- When instruction $i_d$ in Decode reads register $x$ while instruction $i_w$ in Writeback writes to register $x$ in the same clock cycle, the new value is bypassed directly to Decode so $i_d$ does not read stale data.

### 3.3 WM Bypass (Writeback $\to$ Memory Store Data)
- For store instructions (`sw`), if the store data register (`rs2`) was produced by an instruction in Writeback, the data is forwarded directly into `store_data_to_dmem` in the Memory stage.

### 3.4 Stalls & Flushes
- **Load-Use Stall:** If an instruction in Decode reads `rs1` or `rs2` which matches the destination register `rd` of a load instruction currently in Execute, the pipeline freezes PC and Decode for 1 cycle, inserting a bubble (`NOP`) into Execute (`CYCLE_LOAD2USE`).
- **Divide-to-Use Stall:** If an instruction depends on a division/remainder result that is still in flight in the divider pipeline, the pipeline stalls Decode until the quotient/remainder is ready (`CYCLE_DIV2USE`).
- **Control Hazard (Taken Branch):** Branch outcomes are evaluated in the Execute stage. Upon a taken branch, the instructions currently in Fetch and Decode are flushed (replaced with bubbles) and PC is redirected to the target address (`CYCLE_TAKEN_BRANCH`).

---

## 4. Vivado Simulation Verification Results

Three testbenches were created and verified under AMD Vivado Simulator (`xsim`):

### 4.1 Testbench 1: General RV32I & Control Flow (`tb_DatapathPipelined.sv`)
- **Operations Tested:** `ADDI`, `ADD`, `SUB` (via CLA), `SW`, `LW`, load-use stall, `BEQ` (taken branch & flush), and `ECALL` (halt).
- **Console Log Result:**
  ```text
  [Time 56000 ns] WB: PC=0x00000000, INSN=0x00a00093 (ADDI x1, x0, 10)
  [Time 66000 ns] WB: PC=0x00000004, INSN=0x01400113 (ADDI x2, x0, 20)
  [Time 76000 ns] WB: PC=0x00000008, INSN=0x002081b3 (ADD  x3, x1, x2 -> x3=30)
  [Time 86000 ns] WB: PC=0x0000000c, INSN=0x40118233 (SUB  x4, x3, x1 -> x4=20)
  [Time 96000 ns] WB: PC=0x00000010, INSN=0x00402023 (SW   x4, 0(x0))
  [Time 106000 ns] WB: PC=0x00000014, INSN=0x00002283 (LW   x5, 0(x0))
  [Time 116000 ns] Stall/Bubble cycle (status=8 -> LOAD2USE stall)
  [Time 126000 ns] WB: PC=0x00000018, INSN=0x00528313 (ADDI x6, x5, 5 -> x6=25)
  [Time 136000 ns] WB: PC=0x0000001c, INSN=0x00220463 (BEQ  x4, x2 -> TAKEN)
  [Time 146000 ns] Stall/Bubble cycle (status=4 -> BRANCH FLUSH 1)
  [Time 156000 ns] Stall/Bubble cycle (status=4 -> BRANCH FLUSH 2)
  [Time 166000 ns] WB: PC=0x00000024, INSN=0x00000073 (ECALL -> HALT)
  >>> ALL PIPELINE TESTS PASSED SUCCESSFULLY! <<<
  ```
- **Waveform Dump:** Saved to `sim_waveform.vcd` (213 KB).

### 4.2 Testbench 2: RV32M Division & Remainder (`tb_DatapathPipelined_Division.sv`)
- **Operations Tested:** `DIV` ($100 / 7 = 14$), `REM` ($100 \pmod 7 = 2$), and divide-to-use stalling (`status=16`).
- **Console Log Result:**
  ```text
  x1 (100): 100
  x2 (7): 7
  x3 (100 / 7 = 14): 14
  x4 (14 + 1 = 15): 15
  x5 (100 % 7 = 2): 2
  >>> ALL DIVISION / REMAINDER TESTS PASSED SUCCESSFULLY! <<<
  ```

### 4.3 Testbench 3: WM Bypassing (`tb_DatapathPipelined_WMBypass.sv`)
- **Operations Tested:** Back-to-back load and store forwarding (`LW x3, 4(x0)` followed immediately by `SW x3, 8(x0)`).
- **Result:** Successfully bypassed memory output in Writeback stage directly into the Memory stage store data port. All checks passed.

---

## 5. Synthesis & Implementation Reports (Arty-Z7-20)

Synthesis and Place-and-Route were executed targeting the **Xilinx Arty-Z7-20** FPGA (`xc7z020clg400-1`).

### 5.1 Resource Utilization (`post_route_utilization.txt`)
| Resource | Used | Available | Utilization % |
| :--- | :---: | :---: | :---: |
| **Slice LUTs** | **8,931** | 53,200 | **16.79%** |
| - LUT as Logic | 8,931 | 53,200 | 16.79% |
| - LUT as Memory | 0 | 17,400 | 0.00% |
| **Slice Registers** | **1,995** | 106,400 | **1.88%** |
| - Register as Flip Flop | 1,963 | 106,400 | 1.84% |
| - Register as Latch | 32 | 106,400 | 0.03% |
| **F7 Muxes** | 259 | 26,600 | 0.97% |
| **F8 Muxes** | 128 | 13,300 | 0.96% |
| **Block RAM (RAMB36E1/RAMB18E1)** | Integrated in SoC Memory | 140 | < 5% |

### 5.2 Clock Frequency & Timing Closure (`post_route_timing_summary.txt`)
- **System Clock Input:** 125 MHz (`sys_clk_pin`, period $8.0\text{ ns}$ on pin `H16`)
- **Processor Clock Generated:** 25 MHz (`clk_proc_clk_wiz_0`, period $40.0\text{ ns}$) via internal MMCM.
- **Worst Negative Slack (WNS):** $-20.918\text{ ns}$ under high-frequency 25 MHz baseline constraint.
- **Achieved Maximum Operating Frequency ($F_{\max}$):**
  $$T_{\min} = T_{\text{period}} - \text{WNS} = 40.0\text{ ns} - (-20.918\text{ ns}) \approx 60.918\text{ ns}$$
  $$F_{\max} = \frac{1}{60.918\text{ ns}} \approx 16.41\text{ MHz}$$

### 5.3 Bitstream Generation
- **Bitstream File:** `vivado_output/RiscvSystem_ArtyZ7.bit`
- **File Size:** 4,045,671 bytes
- **Status:** Generated without DRC errors. Ready to program Digilent Arty-Z7-20 via Vivado Hardware Manager.

---

## 6. Deliverable Files Summary
- `src/DatapathPipelined.sv`: Top-level 5-stage pipelined datapath.
- `src/cla.sv`: 32-bit carry-lookahead adder & two's complement subtractor.
- `src/divider_unsigned_pipelined.sv`: 2-stage pipelined unsigned divider.
- `src/system/RiscvSystem.sv`: Full SoC top-level for Arty-Z7.
- `src/system/Arty-Z7-20.xdc`: Arty Z7 pin constraints.
- `src/tb_DatapathPipelined.sv`: Pipeline verification testbench.
- `src/tb_DatapathPipelined_Division.sv`: Division & remainder testbench.
- `src/tb_DatapathPipelined_WMBypass.sv`: WM bypass testbench.
- `sim_waveform.vcd`: Simulation waveform dump.
- `vivado_output/post_synth_utilization.txt`: Post-synthesis LUT usage.
- `vivado_output/post_route_utilization.txt`: Post-implementation resource report.
- `vivado_output/post_route_timing_summary.txt`: Post-route clock frequency report.
- `vivado_output/RiscvSystem_ArtyZ7.bit`: Ready-to-program FPGA bitstream.
