## This constraint file maps the ship game top-level ports to the Basys3 board pins.
## I kept the pin assignments the same and only added comments so it is easier to follow.

## Clock
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset moved to switch SW0
set_property PACKAGE_PIN R2 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## Movement buttons
## Up
set_property PACKAGE_PIN T18 [get_ports btnU]
set_property IOSTANDARD LVCMOS33 [get_ports btnU]

## Down
set_property PACKAGE_PIN U17 [get_ports btnD]
set_property IOSTANDARD LVCMOS33 [get_ports btnD]

## Left
set_property PACKAGE_PIN W19 [get_ports btnL]
set_property IOSTANDARD LVCMOS33 [get_ports btnL]

## Right
set_property PACKAGE_PIN T17 [get_ports btnR]
set_property IOSTANDARD LVCMOS33 [get_ports btnR]

## Center button = fire
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## VGA RGB outputs
## rgb[2] -> vgaRed[3]
set_property PACKAGE_PIN N19 [get_ports {rgb[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[2]}]

## rgb[1] -> vgaGreen[3]
set_property PACKAGE_PIN D17 [get_ports {rgb[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[1]}]

## rgb[0] -> vgaBlue[3]
set_property PACKAGE_PIN J18 [get_ports {rgb[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb[0]}]

## VGA sync
set_property PACKAGE_PIN P19 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]

set_property PACKAGE_PIN R19 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

## Debug/status outputs
set_property PACKAGE_PIN E19 [get_ports comp_sync]
set_property IOSTANDARD LVCMOS33 [get_ports comp_sync]

set_property PACKAGE_PIN U19 [get_ports blank]
set_property IOSTANDARD LVCMOS33 [get_ports blank]

set_property PACKAGE_PIN V19 [get_ports vga_pixel_tick]
set_property IOSTANDARD LVCMOS33 [get_ports vga_pixel_tick]