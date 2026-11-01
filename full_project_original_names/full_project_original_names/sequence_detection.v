`timescale 1ns/1ps

module sequence_detection (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] orientation,
    input  wire       readyOD,
    output reg  [2:0] seq_0,
    output reg  [2:0] seq_1,
    output reg  [2:0] seq_2,
    output reg        readySD
);

    reg [2:0] prev_orientation;
    reg [5:0] filter_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_orientation <= 3'd0;
            filter_counter   <= 6'd0;
            seq_0            <= 3'd0;
            seq_1            <= 3'd0;
            seq_2            <= 3'd0;
            readySD          <= 1'b0;
        end
        else begin
            readySD <= 1'b0;

            if (readyOD) begin
                if (orientation == 3'd0) begin
                    prev_orientation <= 3'd0;
                    filter_counter   <= 6'd0;
                end
                else if (orientation != prev_orientation) begin
                    prev_orientation <= orientation;
                    filter_counter   <= 6'd1;
                end
                else begin
                    if (filter_counter < 6'd13) begin
                        filter_counter <= filter_counter + 1'b1;
                    end
                    else begin
                        filter_counter <= 6'd13;
			if (seq_0 != orientation) begin
                            seq_2   <= seq_1;
                            seq_1   <= seq_0;
                            seq_0   <= orientation;
                            readySD <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule


