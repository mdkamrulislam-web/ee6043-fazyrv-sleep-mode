## extra pins of the diagnostic wrapper (PYNQ-Z2 RGB LEDs)
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports led4_g]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports led5_r]
set_false_path -to [get_ports {led4_g led5_r}]
## used by top_pynqz2_diag3.sv only
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports -quiet led5_b]
set_false_path -to [get_ports -quiet led5_b]
