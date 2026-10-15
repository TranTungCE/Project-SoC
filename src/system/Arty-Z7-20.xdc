# Arty-Z7-20 Constraint File for RiscvSystem
# Board: Digilent Arty Z7-20 (xc7z020clg400-1)

# Clock signal (125 MHz system clock on Arty Z7 - H16)
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { CLOCK_100MHz }];
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} [get_ports { CLOCK_100MHz }];

# RGB LEDs (mapped to upper LED bits 4-7)
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { LED[4] }]; # RGB LED4 Blue
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { LED[5] }]; # RGB LED4 Green
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { LED[6] }]; # RGB LED4 Red
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { LED[7] }]; # RGB LED5 Blue

# Regular LEDs (LED[0..3])
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { LED[0] }]; # LED0 (Reset status)
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { LED[1] }]; # LED1 (Clock locked)
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { LED[2] }]; # LED2 (Datapath halted)
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { LED[3] }]; # LED3 (OLED on)

# Push Buttons
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { BTN_U }]; # BTN0
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { BTN_D }]; # BTN1
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports { BTN_L }]; # BTN2
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { BTN_R }]; # BTN3
# BTN_C assigned to spare ground/pulldown or tied in logic
# We map BTN_C to another available pin or tie it

# Slide Switches
set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 } [get_ports { SWITCH[0] }]; # SW0 (Reset active low)
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { SWITCH[1] }]; # SW1

# Pmod JA for OLED SPI interface
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { OLED_SDIN }]; # JA1
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { OLED_SCLK }]; # JA2
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports { OLED_DC }];   # JA3
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports { OLED_RES }];  # JA4
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { OLED_VBAT }]; # JA7
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { OLED_VDD }];  # JA8
