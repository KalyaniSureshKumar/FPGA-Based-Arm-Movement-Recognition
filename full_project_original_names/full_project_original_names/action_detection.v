`timescale 1ns/1ps

// Action codes (3 bits)          HEX0 shows
//   3'b000 = invalid / none         0
//   3'b001 = Action A               A     3->2->3
//   3'b010 = Action B               b     3->6->3
//   3'b011 = Action C               C     1->3->1  and  3->1->3
//   3'b100 = Action D               d     1->2->1
//   3'b101 = Action E               E     2->1->2  and  2->3->2
//   3'b110 = Action F               F     1->6->1  and  1->5->1
// Any other 3-position sequence gives 3'b000 (invalid).

module action_detection (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] seq_0,      // newest position
    input  wire [2:0] seq_1,
    input  wire [2:0] seq_2,      // oldest position
    input  wire       readySD,
    output reg  [2:0] action
);

    wire seq_A;
    wire seq_B;
    wire seq_C;
    wire seq_D;
    wire seq_E;
    wire seq_F;

    // Action A : 3-2-3
    assign seq_A = (seq_2 == 3'd3) && (seq_1 == 3'd2) && (seq_0 == 3'd3);

    // Action B : 3-6-3 and 3-5-3
    assign seq_B = (seq_2 == 3'd3) && (seq_1 == 3'd6) && (seq_0 == 3'd3) ||
				((seq_2 == 3'd3) && (seq_1 == 3'd5) && (seq_0 == 3'd3));


    // Action C : 1-3-1 and 3-1-3
    assign seq_C =
        ((seq_2 == 3'd1) && (seq_1 == 3'd2) && (seq_0 == 3'd3)) ||
        ((seq_2 == 3'd3) && (seq_1 == 3'd2) && (seq_0 == 3'd1));

    // Action D : 1-2-1
    assign seq_D = (seq_2 == 3'd1) && (seq_1 == 3'd2) && (seq_0 == 3'd1);

    // Action E : 2-1-2 and 2-3-2
    assign seq_E =
        ((seq_2 == 3'd2) && (seq_1 == 3'd1) && (seq_0 == 3'd2)) ||
        ((seq_2 == 3'd2) && (seq_1 == 3'd3) && (seq_0 == 3'd2));

  

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            action <= 3'b000;
        end
        else if (readySD) begin
            if      (seq_A) action <= 3'b001;   // A
            else if (seq_B) action <= 3'b010;   // b
            else if (seq_C) action <= 3'b011;   // C
            else if (seq_D) action <= 3'b100;   // d
            else if (seq_E) action <= 3'b101;   // E
            else if (seq_F) action <= 3'b110;   // F
            else            action <= 3'b000;   // invalid / default
        end
    end

endmodule
