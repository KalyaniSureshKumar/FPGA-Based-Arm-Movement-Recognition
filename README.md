Arm-Controlled Movement Recognition Using MPU6050 and FPGA\* is a hardware-based system designed to recognize predefined arm movements by analyzing real-time acceleration data. The system uses an MPU6050 accelerometer and gyroscope sensor to capture arm orientation changes and communicates with the FPGA development board through the I2C protocol.



The acquired acceleration data is processed using Verilog HDL to identify different arm orientations based on the dominant acceleration axis and its polarity. A sequence detection module identifies stable orientation transitions, while an action detection module compares the detected movement sequences with predefined patterns to recognize specific arm movements. The recognized actions are displayed on the FPGA's seven-segment display.



The design incorporates an I2C master controller with sensor initialization, ACK/NACK error detection, communication status monitoring, and automatic retry mechanisms to ensure reliable sensor interfacing. The complete system is implemented on the DE2-115 FPGA development board using Quartus Prime.



This project demonstrates the application of FPGA-based real-time sensor interfacing, digital signal processing, and movement recognition, with potential applications in gesture-controlled systems, assistive technologies, rehabilitation, and human-machine interaction

