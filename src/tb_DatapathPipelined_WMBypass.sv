`timescale 1ns / 1ps

module tb_DatapathPipelined_WMBypass();

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
    $display("=== STARTING WM BYPASS & MULTIPLE LOAD-STORE PIPELINE TEST ===");
    clk = 0;
    rst = 1;

    // Test program:
    // 0x00: ADDI x1, x0, 100     (0x06400093)
    // 0x04: ADDI x2, x1, 55      (0x03708113)  (x2 = 155)
    // 0x08: SW   x2, 4(x0)       (0x00202223)  (Store x2 into addr 4)
    // 0x0C: LW   x3, 4(x0)       (0x00402183)  (Load back into x3)
    // 0x10: SW   x3, 8(x0)       (0x00302423)  (WM Bypass: store value loaded directly into next store)
    // 0x14: LW   x4, 8(x0)       (0x00802203)  (Load from addr 8 into x4)
    // 0x18: ECALL                (0x00000073)  (Halt)

    uut.the_mem.mem[0] = 32'h06400093; // addi x1, x0, 100
    uut.the_mem.mem[1] = 32'h03708113; // addi x2, x1, 55
    uut.the_mem.mem[2] = 32'h00202223; // sw x2, 4(x0)
    uut.the_mem.mem[3] = 32'h00402183; // lw x3, 4(x0)
    uut.the_mem.mem[4] = 32'h00302423; // sw x3, 8(x0) (WM bypass test)
    uut.the_mem.mem[5] = 32'h00802203; // lw x4, 8(x0)
    uut.the_mem.mem[6] = 32'h00000073; // ecall

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
        $display("--- REGISTER & MEMORY STATE VERIFICATION ---");
        $display("x1 (100): %0d", uut.datapath.rf.regs[1]);
        $display("x2 (155): %0d", uut.datapath.rf.regs[2]);
        $display("x3 (155): %0d", uut.datapath.rf.regs[3]);
        $display("x4 (155): %0d", uut.datapath.rf.regs[4]);
        $display("mem[1] (addr 4, expected 155): %0d", uut.the_mem.mem[1]);
        $display("mem[2] (addr 8, expected 155): %0d", uut.the_mem.mem[2]);
        
        if (uut.datapath.rf.regs[1] == 100 &&
            uut.datapath.rf.regs[2] == 155 &&
            uut.datapath.rf.regs[3] == 155 &&
            uut.datapath.rf.regs[4] == 155 &&
            uut.the_mem.mem[1] == 155 &&
            uut.the_mem.mem[2] == 155) begin
          $display(">>> ALL WM BYPASS & MEMORY TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
          $display(">>> WM BYPASS TEST FAILED! <<<");
        end
        $finish;
      end
    end

    $display("Test timed out before halt reached!");
    $finish;
  end

endmodule
