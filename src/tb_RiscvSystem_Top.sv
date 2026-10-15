`timescale 1ns / 1ps

module tb_RiscvSystem_Top();

  reg CLOCK_100MHz;
  reg [1:0] SWITCH;
  reg BTN_U, BTN_D, BTN_L, BTN_R;
  wire [7:0] LED;
  wire OLED_SDIN, OLED_SCLK, OLED_DC, OLED_RES, OLED_VBAT, OLED_VDD;

  // Instantiate top-level SoC
  RiscvSystem uut (
    .CLOCK_100MHz(CLOCK_100MHz),
    .LED(LED),
    .BTN_U(BTN_U),
    .BTN_D(BTN_D),
    .BTN_L(BTN_L),
    .BTN_R(BTN_R),
    .SWITCH(SWITCH),
    .OLED_SDIN(OLED_SDIN),
    .OLED_SCLK(OLED_SCLK),
    .OLED_DC(OLED_DC),
    .OLED_RES(OLED_RES),
    .OLED_VBAT(OLED_VBAT),
    .OLED_VDD(OLED_VDD)
  );

  // 125 MHz clock on Arty-Z7: period = 8ns
  always #4 CLOCK_100MHz = ~CLOCK_100MHz;

  initial begin
    $display("=== STARTING TOP-LEVEL RISCV SYSTEM ON ARTY-Z7 SIMULATION ===");
    CLOCK_100MHz = 0;
    SWITCH = 2'b00; // Reset active (active-low via ~SWITCH[0])
    BTN_U = 0;
    BTN_D = 0;
    BTN_L = 0;
    BTN_R = 0;

    // Load simple test instructions into processor memory
    uut.mem.mem[0] = 32'h00a00093; // addi x1, x0, 10
    uut.mem.mem[1] = 32'h01400113; // addi x2, x0, 20
    uut.mem.mem[2] = 32'h002081b3; // add  x3, x1, x2
    uut.mem.mem[3] = 32'h00000073; // ecall (halt)

    #200;
    SWITCH = 2'b01; // Release reset (SWITCH[0] = 1 -> RESET_SWITCH = 0)
    $display("[Time %0t ns] Reset released. System starting...", $time);

    #5000;
    $display("[Time %0t ns] LED status: 8'b%b", $time, LED);
    $display("LED[0] (Reset): %b", LED[0]);
    $display("LED[1] (Clocks Locked): %b", LED[1]);
    $display("LED[2] (Datapath Halted): %b", LED[2]);
    $display("LED[3] (OLED On): %b", LED[3]);
    $display("Datapath Register x1: %0d", uut.datapath.rf.regs[1]);
    $display("Datapath Register x2: %0d", uut.datapath.rf.regs[2]);
    $display("Datapath Register x3: %0d", uut.datapath.rf.regs[3]);

    if (uut.datapath.rf.regs[1] == 10 &&
        uut.datapath.rf.regs[2] == 20 &&
        uut.datapath.rf.regs[3] == 30) begin
      $display(">>> TOP-LEVEL RISCV SYSTEM TESTBENCH PASSED! <<<");
    end else begin
      $display(">>> TOP-LEVEL TESTBENCH FAILED! <<<");
    end

    $finish;
  end

endmodule
