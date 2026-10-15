`timescale 1ns / 1ps

module tb_DatapathPipelined_Division();

  reg clk;
  reg rst;
  wire halt;
  wire [31:0] trace_writeback_pc;
  wire [31:0] trace_writeback_insn;
  wire [31:0] trace_writeback_cycle_status;

  RiscvProcessor uut (
    .clk(clk),
    .rst(rst),
    .halt(halt),
    .trace_writeback_pc(trace_writeback_pc),
    .trace_writeback_insn(trace_writeback_insn),
    .trace_writeback_cycle_status(trace_writeback_cycle_status)
  );

  always #5 clk = ~clk;

  initial begin
    $display("=== STARTING RV32M DIVISION & REMAINDER PIPELINE TEST ===");
    clk = 0;
    rst = 1;

    // Test program:
    // 0x00: ADDI x1, x0, 100     (0x06400093)
    // 0x04: ADDI x2, x0, 7       (0x00700113)
    // 0x08: DIV  x3, x1, x2      (0x0220c1b3)  -- 100 / 7 = 14 (0x0E)
    // 0x0C: ADDI x4, x3, 1       (0x00118213)  -- DIV2USE stall (x4 = 15)
    // 0x10: REM  x5, x1, x2      (0x0220e2b3)  -- 100 % 7 = 2
    // 0x14: ECALL                (0x00000073)  -- Halt

    uut.the_mem.mem[0] = 32'h06400093; // addi x1, x0, 100
    uut.the_mem.mem[1] = 32'h00700113; // addi x2, x0, 7
    uut.the_mem.mem[2] = 32'h0220c1b3; // div x3, x1, x2
    uut.the_mem.mem[3] = 32'h00118213; // addi x4, x3, 1
    uut.the_mem.mem[4] = 32'h0220e2b3; // rem x5, x1, x2
    uut.the_mem.mem[5] = 32'h00000073; // ecall

    #20;
    rst = 0;

    repeat (60) begin
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
        $display("x1 (100): %0d", uut.datapath.rf.regs[1]);
        $display("x2 (7): %0d", uut.datapath.rf.regs[2]);
        $display("x3 (100 / 7 = 14): %0d", uut.datapath.rf.regs[3]);
        $display("x4 (14 + 1 = 15): %0d", uut.datapath.rf.regs[4]);
        $display("x5 (100 %% 7 = 2): %0d", uut.datapath.rf.regs[5]);
        
        if (uut.datapath.rf.regs[3] == 14 &&
            uut.datapath.rf.regs[4] == 15 &&
            uut.datapath.rf.regs[5] == 2) begin
          $display(">>> ALL DIVISION / REMAINDER TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
          $display(">>> DIVISION TESTS FAILED! <<<");
        end
        $finish;
      end
    end

    $display("Test timed out before halt reached!");
    $finish;
  end

endmodule
