
`timescale 1ns/1ps

module tb_system_simulation;

    localparam integer HOLD_TIME = 15_000_000; 

    reg clk;
    reg rst_n;

    wire scl;
    wire sda;
    wire [6:0] hex0_action;
    wire [6:0] hex1_pos;

    reg signed [15:0] sim_accel_x;
    reg signed [15:0] sim_accel_y;
    reg signed [15:0] sim_accel_z;

    reg slave_drive_low;

    integer pass_count;
    integer fail_count;

    pullup(scl);
    pullup(sda);


    top_mpu6050_arm_recognition uut (
        .arm_sel     (1'b1),   // 1 = right arm, 0 = left arm
        .clk_50mhz   (clk),
        .rst_n       (rst_n),
        .scl         (scl),
        .sda         (sda),
        .hex0_action (hex0_action),
        .hex1_pos    (hex1_pos)
    );


    assign sda = slave_drive_low ? 1'b0 : 1'bz;

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    always @(*) begin
        slave_drive_low = 1'b0;

        if (uut.i2c_unit.state == 5'd18) begin

            case (uut.i2c_unit.byte_count)

                3'd0: slave_drive_low =
                    ~sim_accel_x[8 + uut.i2c_unit.bit_count];

                3'd1: slave_drive_low =
                    ~sim_accel_x[uut.i2c_unit.bit_count];

                3'd2: slave_drive_low =
                    ~sim_accel_y[8 + uut.i2c_unit.bit_count];

                3'd3: slave_drive_low =
                    ~sim_accel_y[uut.i2c_unit.bit_count];

                3'd4: slave_drive_low =
                    ~sim_accel_z[8 + uut.i2c_unit.bit_count];

                3'd5: slave_drive_low =
                    ~sim_accel_z[uut.i2c_unit.bit_count];

                default: slave_drive_low = 1'b0;
            endcase
        end

        else if ((uut.i2c_unit.state == 5'd3)  ||
                 (uut.i2c_unit.state == 5'd5)  ||
                 (uut.i2c_unit.state == 5'd7)  ||
                 (uut.i2c_unit.state == 5'd12) ||
                 (uut.i2c_unit.state == 5'd14) ||
                 (uut.i2c_unit.state == 5'd17)) begin

            slave_drive_low = 1'b1;
        end
    end

       task reset_system;
        begin
            rst_n = 1'b0;
            sim_accel_x = 16'sd0;
            sim_accel_y = 16'sd0;
            sim_accel_z = 16'sd0;
            #200;
            rst_n = 1'b1;
            #10_000;
        end
    endtask

    task apply_position;
        input integer pos;
        begin
            case (pos)
	        1: begin
                    sim_accel_x = 16'sd0;
                    sim_accel_y = -16'sd16384;
                    sim_accel_z = 16'sd0;
                end
                2: begin
                    sim_accel_x = 16'sd0;
                    sim_accel_y = 16'sd0;
                    sim_accel_z = 16'sd16384;
                end
                3: begin
                    sim_accel_x = 16'sd0;
                    sim_accel_y = 16'sd16384;
                    sim_accel_z = 16'sd0;
                end
                 4: begin
                    sim_accel_x = 16'sd0;
                    sim_accel_y = 16'sd0;
                    sim_accel_z = -16'sd16384;
                end
                5: begin
                    sim_accel_x = 16'sd16384;
                    sim_accel_y = 16'sd0;
                    sim_accel_z = 16'sd0;
                end
                6: begin
                    sim_accel_x = 16'sd16384;
                    sim_accel_y = 16'sd0;
                    sim_accel_z = 16'sd0;
                end

                default: begin
                    sim_accel_x = 16'sd0;
                    sim_accel_y = 16'sd0;
                    sim_accel_z = 16'sd0;
                end
            endcase

            #(HOLD_TIME);
        end
    endtask

    task check_orientation;
        input integer expected;
        input [255:0] test_name;
        begin
            if (uut.orientation == expected[2:0]) begin
                $display("PASS: %s | Orientation = %0d", test_name, uut.orientation);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %s | Expected P%0d, got P%0d",
                         test_name, expected, uut.orientation);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_sequence;
        input integer e2;
        input integer e1;
        input integer e0;
        input [255:0] test_name;
        begin
            if ((uut.seq_2 == e2[2:0]) &&
                (uut.seq_1 == e1[2:0]) &&
                (uut.seq_0 == e0[2:0])) begin

                $display("PASS: %s | SEQ = %0d -> %0d -> %0d",
                         test_name, uut.seq_2, uut.seq_1, uut.seq_0);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %s | Expected %0d -> %0d -> %0d, got %0d -> %0d -> %0d",
                         test_name, e2, e1, e0,
                         uut.seq_2, uut.seq_1, uut.seq_0);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_action;
        input [2:0] expected;
        input [255:0] test_name;
        begin
            if (uut.action == expected) begin
                $display("PASS: %s | Action = %b", test_name, uut.action);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %s | Expected Action = %b, got %b",
                         test_name, expected, uut.action);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin

        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display(" COMPREHENSIVE ARM MOVEMENT RECOGNITION VERIFICATION");
        $display("============================================================");

        reset_system;
        apply_position(1);
        check_orientation(1, "Position 1: -Y");

        reset_system;
        apply_position(2);
        check_orientation(2, "Position 2: +Z");

        reset_system;
        apply_position(3);
        check_orientation(3, "Position 3: +Y");

        reset_system;
        apply_position(4);
        check_orientation(4, "Position 4: -Z");

        reset_system;
        apply_position(6);
        check_orientation(6, "Position 6: +X");

        reset_system;
        sim_accel_x = 16'sd0;
        sim_accel_y = 16'sd0;
        sim_accel_z = 16'sd0;
        #HOLD_TIME;
        check_orientation(0, "Invalid: 0g on all axes");

        reset_system;
        apply_position(3);
        apply_position(2);
        apply_position(3);
        check_action(3'b001, "Action A: 3->2->3");

        reset_system;
        apply_position(3);
        apply_position(6);
        apply_position(3);
        check_action(3'b010, "Action B: 3->6->3");

        reset_system;
        apply_position(1);
        apply_position(3);
        apply_position(1);
        check_action(3'b011, "Action C: 1->3->1");

        reset_system;
        apply_position(3);
        apply_position(1);
        apply_position(3);
        check_action(3'b011, "Action C: 3->1->3");

        reset_system;
        apply_position(1);
        apply_position(2);
        apply_position(1);
        check_action(3'b100, "Action D: 1->2->1");

        reset_system;
        apply_position(2);
        apply_position(1);
        apply_position(2);
        check_action(3'b101, "Action E: 2->1->2");

        reset_system;
        apply_position(2);
        apply_position(3);
        apply_position(2);
        check_action(3'b101, "Action E: 2->3->2");

        reset_system;
        apply_position(1);
        apply_position(6);
        apply_position(1);
        check_action(3'b110, "Action F: 1->6->1");

        reset_system;
        apply_position(6);
        apply_position(3);
        apply_position(6);
        check_action(3'b000, "Invalid: 6->3->6");

        reset_system;
        apply_position(1);
        apply_position(4);
        apply_position(1);
        check_action(3'b000, "Invalid: 1->4->1");

        reset_system;
        apply_position(3);
        apply_position(4);
        apply_position(3);
        check_action(3'b000, "Invalid: 3->4->3");

        $display("============================================================");
        $display(" VERIFICATION SUMMARY");
        $display(" PASS = %0d", pass_count);
        $display(" FAIL = %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED - RTL NEEDS CORRECTION");

        $display("============================================================");

        $stop;
    end

endmodule

