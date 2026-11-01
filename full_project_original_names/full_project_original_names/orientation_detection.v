`timescale 1ns/1ps

module orientation_detection (
    input  wire              clk,
    input  wire              rst_n,
    input  wire signed [15:0] accel_x,
    input  wire signed [15:0] accel_y,
    input  wire signed [15:0] accel_z,
    input  wire              sample_valid,
    input  wire              right_arm,   // no longer used (+X = 5, -X = 6 always); kept so the top module needs no change
    output reg  [2:0]        orientation,
    output reg               readyOD
);

    localparam signed [15:0] G_LOWER = 16'sd8192;
    localparam signed [15:0] G_UPPER = 16'sd24576;

    wire signed [16:0] x_ext = {accel_x[15], accel_x};
    wire signed [16:0] y_ext = {accel_y[15], accel_y};
    wire signed [16:0] z_ext = {accel_z[15], accel_z};

    wire [16:0] abs_x = (x_ext < 0) ? -x_ext : x_ext;
    wire [16:0] abs_y = (y_ext < 0) ? -y_ext : y_ext;
    wire [16:0] abs_z = (z_ext < 0) ? -z_ext : z_ext;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            orientation <= 3'd0;
            readyOD     <= 1'b0;

        end

        else if (sample_valid) begin

            readyOD <= 1'b1;

            if ((abs_y >= abs_x) && (abs_y >= abs_z)) begin
                if ((y_ext <= -G_LOWER) && (y_ext >= -G_UPPER)) begin
		     orientation <= 3'd1;
		end
                else if ((y_ext >= G_LOWER) && (y_ext <= G_UPPER)) begin
                      orientation <= 3'd3;
                end
                else begin
                      orientation <= 3'd0;
                end
            end

            else if ((abs_z >= abs_x) && (abs_z >= abs_y)) begin
                if ((z_ext >= G_LOWER) && (z_ext <= G_UPPER)) begin
		      orientation <= 3'd2;
		end

                else if ((z_ext <= -G_LOWER) && (z_ext >= -G_UPPER)) begin
		       orientation <= 3'd4;
                 end

                else begin
                       orientation <= 3'd0;

                end
            end

            else if ((abs_x >= abs_y) && (abs_x >= abs_z)) begin
                if ((x_ext >= G_LOWER) && (x_ext <= G_UPPER)) begin
                    orientation <= 3'd5;   // +X axis
                end
                else if ((x_ext <= -G_LOWER) && (x_ext >= -G_UPPER)) begin
                    orientation <= 3'd6;   // -X axis
                end
                else begin
                    orientation <= 3'd0;
                end
            end
	else begin
    			orientation <= 3'd0;
		end

	end
	
        else begin

            readyOD <= 1'b0;

        end
    end

endmodule