# 5-Stage Pipelined RISC-V SoC (RV32IM) on Xilinx Arty-Z7-20

Dự án thiết kế, mô phỏng và thực thi phần cứng hoàn chỉnh cho bài tập lớn môn **Introduction to SoC (Semester 251)** — Khoa Khoa học & Kỹ thuật Máy tính, Trường Đại học Bách Khoa - ĐHQG TP.HCM (HCMUT).

Target Board: **Digilent Arty-Z7-20** (`xc7z020clg400-1`)  
EDA Tool: **AMD Xilinx Vivado Design Suite 2024.2**

---

## 1. Cấu Trúc Thư Mục Dự Án

```
assSoC/
├── src/                                  # Toàn bộ mã nguồn HDL & Testbench
│   ├── DatapathPipelined.sv              # Top-level đường dẫn dữ liệu 5 tầng RV32IM
│   ├── cla.sv                            # Bộ cộng CLA 32-bit & mạch trừ bù 2 (thay thế toán tử '-')
│   ├── divider_unsigned_pipelined.sv     # Bộ chia pipelined không dùng toán tử cấm ('/', '%')
│   ├── RvDisassembler.sv                 # Bộ dịch ngược mã máy phục vụ mô phỏng
│   ├── tb_DatapathPipelined.sv           # Testbench 1: RV32I ALU, Bypass, Branch Taken, Load-use
│   ├── tb_DatapathPipelined_Division.sv  # Testbench 2: RV32M DIV, REM, Div2Use Stall
│   ├── tb_DatapathPipelined_WMBypass.sv  # Testbench 3: WM Bypassing cho lệnh Store
│   ├── tb_RiscvSystem_Top.sv             # Testbench mô phỏng toàn bộ SoC trên board
│   └── system/                           # Tích hợp ngoại vi & ràng buộc chân Arty-Z7
│       ├── RiscvSystem.sv                # Top-level SoC kết hợp CPU, MMCM, Mem, OLED
│       ├── Arty-Z7-20.xdc                # File ràng buộc chân FPGA Arty-Z7-20
│       ├── mmcm.v                        # Clock Wizard tạo xung nhịp 25 MHz
│       ├── OledDevice.sv, OLEDCtrl.v     # Điều khiển màn hình OLED qua giao tiếp SPI
│       ├── SpiCtrl.v, debouncer.v...     # Module giao tiếp ngoại vi
│       └── ip/                           # Xilinx IP cores (charLib, rom, pixel_buffer)
│
├── vivado_output/                        # Kết quả tổng hợp & thực thi Vivado
│   ├── RiscvSystem_ArtyZ7.bit            # File Bitstream sẵn sàng nạp lên board
│   ├── post_synth_utilization.txt        # Báo cáo sử dụng tài nguyên sau tổng hợp
│   ├── post_route_utilization.txt        # Báo cáo sử dụng tài nguyên (LUT, FF) sau Place & Route
│   ├── post_route_timing_summary.txt     # Báo cáo tần số xung nhịp & slack thời gian
│   └── post_route_drc.txt                # Báo cáo kiểm tra luật thiết kế phần cứng (DRC)
│
├── run_all_tests.bat                     # Script 1-click chạy toàn bộ mô phỏng
├── run_vivado.tcl                        # Script tự động chạy Synthesis -> Route -> Bitstream
├── dump_wave.tcl                         # Script xuất giản đồ sóng VCD
├── sim_waveform.vcd                      # Giản đồ sóng mô phỏng (Waveform VCD)
├── sim_tb.wdb                            # Cơ sở dữ liệu waveform để mở trên Vivado GUI
├── REPORT_ASSIGNMENT_SOC.pdf             # Báo cáo đồ án chính thức (PDF)
├── REPORT_ASSIGNMENT_SOC.md              # Báo cáo chi tiết định dạng Markdown
└── Assignment.pdf                        # Đề bài gốc của môn học
```

---

## 2. Đặc Tả Kỹ Thuật (Architecture Highlights)

1. **Tuân thủ quy định không dùng toán tử cấm:**
   - Không sử dụng các toán tử `/`, `%` hoặc `-` trong toàn bộ phần cứng.
   - Phép trừ (`SUB`) được thực hiện thông qua module `cla` 32-bit theo thuật toán cộng số bù 2 ($A + \sim B + 1$).
   - Phép chia (`DIV`, `DIVU`) và lấy dư (`REM`, `REMU`) sử dụng kiến trúc không lặp pipelined 2 tầng trong `divider_unsigned_pipelined`.
2. **Mạng Forwarding (Bypassing):**
   - **MX Bypass:** Chuyển dữ liệu từ tầng Memory sang Execute.
   - **WX Bypass:** Chuyển dữ liệu từ tầng Writeback sang Execute.
   - **WD Bypass:** Chuyển trực tiếp dữ liệu ghi từ Writeback sang Decode khi ghi và đọc cùng thanh ghi trong cùng chu kỳ.
   - **WM Bypass:** Chuyển trực tiếp dữ liệu từ Writeback vào dữ liệu ghi bộ nhớ (`dmem`) ở tầng Memory cho lệnh Store (`sw`).
3. **Phát hiện xung đột & Điều khiển Pipeline:**
   - **Load-Use Stall:** Dừng 1 chu kỳ khi lệnh trong Decode phụ thuộc vào kết quả Load đang trong Execute (`CYCLE_LOAD2USE`).
   - **Divide-to-Use Stall:** Dừng Decode khi lệnh kế tiếp cần kết quả từ bộ chia đang hoạt động (`CYCLE_DIV2USE`).
   - **Branch Flush:** Đánh giá rẽ nhánh ở tầng Execute; khi nhánh được kích hoạt (`branch taken`), tự động flush (chèn bubble) 2 lệnh đang ở Fetch và Decode (`CYCLE_TAKEN_BRANCH`).
4. **Cổng Trace:**
   - Xuất đầy đủ các cổng phục vụ kiểm thử chu kỳ: `trace_writeback_pc`, `trace_writeback_insn`, `trace_writeback_cycle_status`.

---

## 3. Hướng Dẫn Chạy Mô Phỏng (Simulation)

### Cách 1: Chạy tự động bằng 1 cú click (Khuyên dùng)
Mở PowerShell / Command Prompt tại thư mục dự án và chạy:
```cmd
.\run_all_tests.bat
```
Hoặc double-click trực tiếp file `run_all_tests.bat` trong Windows File Explorer. Script sẽ tự động:
1. Biên dịch toàn bộ file nguồn SystemVerilog bằng `xvlog`.
2. Chạy **Test 1:** Kiểm tra ALU, MX/WX/WD bypass, Load-use stall, Branch flush.
3. Chạy **Test 2:** Kiểm tra RV32M Division & Remainder, Div2use stall.
4. Chạy **Test 3:** Kiểm tra WM bypass (Store data forwarding).
5. Xuất file waveform `sim_waveform.vcd`.

### Cách 2: Chạy từng Testbench thủ công với Vivado xsim

#### Bước 1: Biên dịch thư viện
```cmd
D:\OTHER\Vivado\2024.2\bin\xvlog.bat -sv src/DatapathPipelined.sv src/tb_DatapathPipelined.sv src/tb_DatapathPipelined_Division.sv src/tb_DatapathPipelined_WMBypass.sv -i src
```

#### Bước 2: Chạy Testbench 1 (ALU, Bypasses & Control Hazards)
```cmd
D:\OTHER\Vivado\2024.2\bin\xelab.bat tb_DatapathPipelined -s sim_tb -debug typical
D:\OTHER\Vivado\2024.2\bin\xsim.bat sim_tb -R
```

#### Bước 3: Chạy Testbench 2 (Phép Chia & Lấy Dư)
```cmd
D:\OTHER\Vivado\2024.2\bin\xelab.bat tb_DatapathPipelined_Division -s sim_div -debug typical
D:\OTHER\Vivado\2024.2\bin\xsim.bat sim_div -R
```

#### Bước 4: Chạy Testbench 3 (WM Bypassing)
```cmd
D:\OTHER\Vivado\2024.2\bin\xelab.bat tb_DatapathPipelined_WMBypass -s sim_wm -debug typical
D:\OTHER\Vivado\2024.2\bin\xsim.bat sim_wm -R
```

---

## 4. Hướng Dẫn Xem Giản Đồ Sóng (Waveform)

### Mở bằng Vivado Waveform GUI:
```cmd
D:\OTHER\Vivado\2024.2\bin\vivado.bat -gui sim_tb.wdb
```
- Trong cửa sổ **Scope**, tìm đường dẫn `/tb_DatapathPipelined/uut/datapath`.
- Kéo các tín hiệu pipeline quan trọng vào cửa sổ Waveform:
  - `clk`, `rst`
  - `f_pc_current`, `decode_state`, `execute_state`, `memory_state`, `writeback_state`
  - `trace_writeback_pc`, `trace_writeback_cycle_status`
  - `loadStall`, `divStall`, `branch_bool`

### Mở bằng GTKWave (nếu có cài đặt):
```cmd
gtkwave sim_waveform.vcd
```

---

## 5. Hướng Dẫn Biên Dịch Phần Cứng & Nạp Lên FPGA Arty-Z7

### Chạy lại Synthesis & Implementation trong Vivado:
```cmd
D:\OTHER\Vivado\2024.2\bin\vivado.bat -mode batch -source run_vivado.tcl -nojournal -nolog
```

### Nạp Bitstream lên Board Arty-Z7-20:
1. Cắm cáp micro-USB kết nối cổng JTAG/UART của board Arty-Z7 vào máy tính.
2. Bật công tắc nguồn của board.
3. Mở **Vivado Hardware Manager** và chọn **Auto Connect**.
4. Chọn file bitstream: `vivado_output/RiscvSystem_ArtyZ7.bit`.
5. Bấm **Program Device**.

### Quan sát phản hồi trên board:
- **LED[0]:** Trạng thái Reset (sáng khi Reset đang giữ).
- **LED[1]:** Xung nhịp MMCM Locked (sáng khi xung clock 25 MHz ổn định).
- **LED[2]:** Báo hiệu CPU Halted (sáng khi chương trình thực thi xong lệnh `ECALL`).
- **SWITCH[0]:** Công tắc gạt Reset phần cứng (active-low).

---

## 6. Thông Số Đạt Được Sau Thực Thi (Implementation Results)

- **Tài nguyên Logic (LUT):** `8,931 / 53,200` (16.79%)
- **Thanh ghi (Registers):** `1,995 / 106,400` (1.88%)
- **F7 Muxes:** `259 / 26,600` (0.97%)
- **F8 Muxes:** `128 / 13,300` (0.96%)
- **Tần số hoạt động cực đại ($F_{\max}$):** $\approx 16.41\text{ MHz}$
- **Trạng thái DRC:** `0 Errors` (Đã pass toàn bộ điều kiện tạo bitstream).

---

## 7. Hồ Sơ Nộp Bài
Khi gửi email nộp bài cho thầy theo cú pháp:
- **Tiêu đề email:** `[Introduction to SoC] [MSSV] Practice #no.`
- **Địa chỉ gửi:** `hoangtt@uec.ac.jp`  
- **CC:** `anhpkn@hcmut.edu.vn`, `tnthinh@hcmut.edu.vn`
- **File đính kèm:**
  1. `src/DatapathPipelined.sv`
  2. Báo cáo đồ án: `REPORT_ASSIGNMENT_SOC.pdf`
  3. Báo cáo tài nguyên & tần số: `vivado_output/post_route_utilization.txt` và `vivado_output/post_route_timing_summary.txt`
  4. File bitstream nạp board: `vivado_output/RiscvSystem_ArtyZ7.bit`
