`timescale 1ns / 1ps

module tb_DatapathPipelined();

  reg clk;
  reg rst;
  wire halt;
  wire [31:0] trace_writeback_pc;
  wire [31:0] trace_writeback_insn;
  wire [31:0] trace_writeback_cycle_status;

  // Instantiate Processor top
  RiscvProcessor uut (
    .clk(clk),
    .rst(rst),
    .halt(halt),
    .trace_writeback_pc(trace_writeback_pc),
    .trace_writeback_insn(trace_writeback_insn),
    .trace_writeback_cycle_status(trace_writeback_cycle_status)
  );

  // Clock generation: 10ns period (100MHz)
  always #5 clk = ~clk;

  initial begin
    $display("=== STARTING RISC-V PIPELINED DATAPATH TESTBENCH ===");
    clk = 0;
    rst = 1;

    // Load simple test program into memory:
    // 0x00: ADDI x1, x0, 10      (0x00a00093)
    // 0x04: ADDI x2, x0, 20      (0x01400113)
    // 0x08: ADD  x3, x1, x2      (0x002081b3)  -- MX / WX bypass test
    // 0x0C: SUB  x4, x3, x1      (0x40118233)  -- CLA sub test (x4 should be 20)
    // 0x10: SW   x4, 0(x0)       (0x00402023)  -- Store test
    // 0x14: LW   x5, 0(x0)       (0x00002283)  -- Load test
    // 0x18: ADDI x6, x5, 5       (0x00528313)  -- Load-use stall test (x6 should be 25)
    // 0x1C: BEQ  x4, x2, 8       (0x00220463)  -- Taken branch (jump to 0x24)
    // 0x20: ADDI x7, x0, 99      (0x06300393)  -- Flushed instruction!
    // 0x24: ECALL                (0x00000073)  -- Halt

    uut.the_mem.mem[0] = 32'h00a00093; // addi x1, x0, 10
    uut.the_mem.mem[1] = 32'h01400113; // addi x2, x0, 20
    uut.the_mem.mem[2] = 32'h002081b3; // add x3, x1, x2
    uut.the_mem.mem[3] = 32'h40118233; // sub x4, x3, x1
    uut.the_mem.mem[4] = 32'h00402023; // sw x4, 0(x0)
    uut.the_mem.mem[5] = 32'h00002283; // lw x5, 0(x0)
    uut.the_mem.mem[6] = 32'h00528313; // addi x6, x5, 5
    uut.the_mem.mem[7] = 32'h00220463; // beq x4, x2, +8
    uut.the_mem.mem[8] = 32'h06300393; // addi x7, x0, 99 (flushed)
    uut.the_mem.mem[9] = 32'h00000073; // ecall (halt)

    #20;
    rst = 0;

    // Run for 50 cycles or until halt
    repeat (50) begin
      @(posedge clk);
      #1;
      if (trace_writeback_cycle_status == 2) begin
        $display("[Time %0t ns] WB: PC=0x%08x, INSN=0x%08x", $time, trace_writeback_pc, trace_writeback_insn);
      end else begin
        $display("[Time %0t ns] Stall/Bubble cycle (status=%0d)", $time, trace_writeback_cycle_status);
      end

      if (halt) begin
        $display("Processor reached HALT!");
        #20;
        $display("--- REGISTER STATE VERIFICATION ---");
        $display("x1 (expected 10): %0d", uut.datapath.rf.regs[1]);
        $display("x2 (expected 20): %0d", uut.datapath.rf.regs[2]);
        $display("x3 (expected 30): %0d", uut.datapath.rf.regs[3]);
        $display("x4 (expected 20): %0d", uut.datapath.rf.regs[4]);
        $display("x5 (expected 20): %0d", uut.datapath.rf.regs[5]);
        $display("x6 (expected 25): %0d", uut.datapath.rf.regs[6]);
        $display("x7 (expected  0, branch flushed): %0d", uut.datapath.rf.regs[7]);
        
        if (uut.datapath.rf.regs[1] == 10 &&
            uut.datapath.rf.regs[2] == 20 &&
            uut.datapath.rf.regs[3] == 30 &&
            uut.datapath.rf.regs[4] == 20 &&
            uut.datapath.rf.regs[5] == 20 &&
            uut.datapath.rf.regs[6] == 25 &&
            uut.datapath.rf.regs[7] == 0) begin
          $display(">>> ALL PIPELINE TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
          $display(">>> SOME TESTS FAILED! <<<");
        end
        $finish;
      end
    end

    $display("Test timed out before halt reached!");
    $finish;
  end

endmodule
