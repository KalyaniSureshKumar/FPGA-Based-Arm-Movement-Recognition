# ============================================================
# DE2-115 pin assignments  (project: newversion)
# Import with:  Assignments -> Import Assignments... (select this file)
# Then run a FULL compile and program the new .sof
#
# I/O standards:
#   clock / KEY0 / GPIO (I2C)  : 3.3-V LVTTL
#   HEX0, HEX1, LEDs, SW0      : 2.5 V   (DE2-115 wires these banks at 2.5 V;
#                                          mixing 3.3 V here caused Error 169026)
# ============================================================

# 50 MHz clock
set_location_assignment PIN_Y2 -to clk_50mhz
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_50mhz

# KEY0 = active-low reset
set_location_assignment PIN_M23 -to rst_n
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to rst_n

# SW0 = arm select (up = right arm, down = left arm)
set_location_assignment PIN_AB28 -to arm_sel
set_instance_assignment -name IO_STANDARD "2.5 V" -to arm_sel

# MPU6050 I2C  (GPIO[0] = SCL, GPIO[1] = SDA)
set_location_assignment PIN_AB22 -to scl
set_location_assignment PIN_AC15 -to sda
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to scl
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sda

# HEX0 - ACTION (A / b / C / d / E / F)
set_location_assignment PIN_G18 -to hex0_action[0]
set_location_assignment PIN_F22 -to hex0_action[1]
set_location_assignment PIN_E17 -to hex0_action[2]
set_location_assignment PIN_L26 -to hex0_action[3]
set_location_assignment PIN_L25 -to hex0_action[4]
set_location_assignment PIN_J22 -to hex0_action[5]
set_location_assignment PIN_H22 -to hex0_action[6]
set_instance_assignment -name IO_STANDARD "2.5 V" -to hex0_action[*]

# HEX1 - POSITION
set_location_assignment PIN_M24 -to hex1_pos[0]
set_location_assignment PIN_Y22 -to hex1_pos[1]
set_location_assignment PIN_W21 -to hex1_pos[2]
set_location_assignment PIN_W22 -to hex1_pos[3]
set_location_assignment PIN_W25 -to hex1_pos[4]
set_location_assignment PIN_U23 -to hex1_pos[5]
set_location_assignment PIN_U24 -to hex1_pos[6]
set_instance_assignment -name IO_STANDARD "2.5 V" -to hex1_pos[*]

# Debug LEDs: LEDG0 = link OK, LEDR0 = I2C NACK
set_location_assignment PIN_E21 -to led_link
set_location_assignment PIN_G19 -to led_err
set_instance_assignment -name IO_STANDARD "2.5 V" -to led_link
set_instance_assignment -name IO_STANDARD "2.5 V" -to led_err
