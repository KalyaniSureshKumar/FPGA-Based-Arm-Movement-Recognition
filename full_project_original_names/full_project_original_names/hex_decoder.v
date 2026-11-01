`timescale 1ns/1ps

module hex_decoder (
    input  wire [3:0] code,
    output reg  [6:0] seg
);
	always @(*) begin

        case (code)

            4'h0: seg = 7'b1000000; 
            4'h1: seg = 7'b1111001; 
            4'h2: seg = 7'b0100100; 
            4'h3: seg = 7'b0110000; 
            4'h4: seg = 7'b0011001; 
            4'h5: seg = 7'b0010010; 
            4'h6: seg = 7'b0000010;
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b0000011; // b
            4'hC: seg = 7'b1000110; // C
            4'hD: seg = 7'b0100001; // d
            4'hE: seg = 7'b0000110; // E
            

            default: seg = 7'b0111111; // '-' : unknown code (display is never fully blank)

        endcase

    end

endmodule
