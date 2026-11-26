## PYNQ-Z2 (xc7z020clg400-1) pins used by top_pynqz2
## (pin names from the PYNQ-Z2 master XDC; all banks are 3.3 V)

## 125 MHz system clock
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports sysclk]

## BTN0 = reset, SW0 = speed switch
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports btn0]
set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 } [get_ports sw0]

## LED0-LED3
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## The button and the switch are not in step with the clock (they go through a
## synchroniser / an asynchronous reset) and the LEDs are only looked at by a
## person, so these pins are not timed.
set_false_path -from [get_ports {btn0 sw0}]
set_false_path -to   [get_ports {led[*]}]

## Configuration bank voltage (removes the CFGBVS/CONFIG_VOLTAGE warning)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
