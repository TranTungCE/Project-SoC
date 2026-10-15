@echo off
set VIVADO_BIN=D:\OTHER\Vivado\2024.2\bin

echo ====================================================================
echo        RISC-V PIPELINED DATAPATH (RV32IM) TEST RUNNER
echo ====================================================================
echo.

echo [1/4] Compiling SystemVerilog source files with xvlog...
call %VIVADO_BIN%\xvlog.bat -sv src/DatapathPipelined.sv src/tb_DatapathPipelined.sv src/tb_DatapathPipelined_Division.sv src/tb_DatapathPipelined_WMBypass.sv -i src
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Compilation failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ====================================================================
echo [2/4] TEST 1: RV32I ALU, BRANCH TAKEN FLUSH, LOAD-USE STALL
echo ====================================================================
call %VIVADO_BIN%\xelab.bat tb_DatapathPipelined -s sim_tb -debug typical
call %VIVADO_BIN%\xsim.bat sim_tb -R

echo.
echo ====================================================================
echo [3/4] TEST 2: RV32M DIVISION, REMAINDER, DIV2USE STALL
echo ====================================================================
call %VIVADO_BIN%\xelab.bat tb_DatapathPipelined_Division -s sim_div -debug typical
call %VIVADO_BIN%\xsim.bat sim_div -R

echo.
echo ====================================================================
echo [4/4] TEST 3: WM BYPASS (STORE DATA FORWARDING FROM WRITEBACK)
echo ====================================================================
call %VIVADO_BIN%\xelab.bat tb_DatapathPipelined_WMBypass -s sim_wm -debug typical
call %VIVADO_BIN%\xsim.bat sim_wm -R

echo.
echo ====================================================================
echo [INFO] Generating VCD waveform for GTKWave / Vivado Waveform Viewer...
echo ====================================================================
call %VIVADO_BIN%\xsim.bat sim_tb -tclbatch dump_wave.tcl

echo.
echo ====================================================================
echo               ALL TESTS EXECUTED SUCCESSFULLY!
echo ====================================================================
pause
