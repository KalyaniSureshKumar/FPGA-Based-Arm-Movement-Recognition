`timescale 1ns/1ps

module newversion(
    input  wire       clk_50mhz,
    input  wire       rst_n,
    input  wire       arm_sel,    // SW0: up = right arm, down = left arm
    output wire       scl,
    inout  wire       sda,
    output wire [6:0] hex0_action,
    output wire [6:0] hex1_pos,

    // Debug LEDs
    output wire       led_link,   // ON  = sensor answering, reads completing
    output wire       led_err     // ON  = last I2C attempt got a NACK
);

    wire signed [15:0] accel_x, accel_y, accel_z;
    wire sample_valid;
    wire ack_error;
    wire link_ok;
    wire [3:0] fail_code;
    wire [2:0] orientation;
    wire readyOD, readySD;
    wire [2:0] seq_0, seq_1, seq_2;
    wire [2:0] action;

    // Action code -> HEX0 character (000 = invalid -> 0)
    reg [3:0] action_char;
    always @(*) begin
        case (action)
            3'b001:  action_char = 4'hA;   // A
            3'b010:  action_char = 4'hB;   // b
            3'b011:  action_char = 4'hC;   // C
            3'b100:  action_char = 4'hD;   // d
            3'b101:  action_char = 4'hE;   // E
            3'b110:  action_char = 4'hF;   // F
            default: action_char = 4'h0;
        endcase
    end

    i2c_master_streamer i2c_unit (
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .sample_valid(sample_valid),
        .ack_error(ack_error),
        .link_ok(link_ok),
        .fail_code(fail_code)
    );

    orientation_detection od_unit (
        .right_arm(arm_sel),
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .sample_valid(sample_valid),
        .orientation(orientation),
        .readyOD(readyOD)
    );

    sequence_detection sd_unit (
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .orientation(orientation),
        .readyOD(readyOD),
        .seq_0(seq_0),
        .seq_1(seq_1),
        .seq_2(seq_2),
        .readySD(readySD)
    );

    action_detection ad_unit (
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .seq_0(seq_0),
        .seq_1(seq_1),
        .seq_2(seq_2),
        .readySD(readySD),
        .action(action)
    );

    assign led_link = link_ok;
    assign led_err  = (fail_code != 4'd0) & ~link_ok;

    // HEX0: action (A / b / C / d / E / F) when the sensor link is good, otherwise the I2C fail code
    // (1..6, see i2c_master.v header). HEX1: orientation as before.
    hex_decoder hex_act_dec (
        .code(link_ok ? action_char : fail_code),
        .seg(hex0_action)
    );

    hex_decoder hex_pos_dec (
        .code({1'b0, orientation}),
        .seg(hex1_pos)
    );

endmodule