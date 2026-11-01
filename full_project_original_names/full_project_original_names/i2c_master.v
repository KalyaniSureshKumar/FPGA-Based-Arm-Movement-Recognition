`timescale 1ns/1ps

//=============================================================================
// i2c_master_streamer  (patched)
//
// Same protocol/timing as your version, plus:
//   * Every ACK (7 of them) is checked. On a NACK the master sends a clean
//     STOP, waits ~50 ms, and retries from the wake-up write. It no longer
//     "reads" garbage and reports sample_valid.
//   * fail_code tells you WHICH ACK failed (0 = none yet):
//        1 = sensor did not ACK its address during wake-up   (INIT_ACK1)
//        2 = no ACK for register 0x6B                        (INIT_ACK2)
//        3 = no ACK for data 0x00                            (INIT_ACK3)
//        4 = no ACK for address (write) before the read      (READ_ACK1)
//        5 = no ACK for register 0x3B                        (READ_ACK2)
//        6 = no ACK for address (read)                       (READ_ACK3)
//     Code 1 means the sensor is not answering at all (power / wiring / pin).
//   * link_ok = 1 while full 6-byte reads are completing with all ACKs good.
//   * ack_error is sticky (set on first NACK, cleared only by reset).
//   * ~50 ms wait after reset before the first transaction (the MPU6050 needs
//     time after power-up before its registers respond).
//=============================================================================

module i2c_master_streamer (
    input  wire              clk,
    input  wire              rst_n,

    output wire              scl,
    inout  wire              sda,

    output reg signed [15:0] accel_x,
    output reg signed [15:0] accel_y,
    output reg signed [15:0] accel_z,

    output reg               sample_valid,
    output reg               ack_error,
    output reg               link_ok,
    output reg [3:0]         fail_code
);

    parameter DIVIDER      = 250;        // 50 MHz / (2*100 kHz)
    parameter RETRY_CYCLES = 2_500_000;  // 50 ms at 50 MHz

    // Open-drain: 1'b0 = pull low, 1'bz = release (external pull-up -> high)
    reg scl_drive_low;
    reg sda_drive_low;

    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    reg [15:0] counter;
    reg [2:0]  bit_count;
    reg [2:0]  byte_count;
    reg [7:0]  tx_byte;
    reg [7:0]  raw_bytes [0:5];
    reg [19:0] stream_timer;
    reg [21:0] retry_timer;
    reg        ack_bad;      // NACK seen in the current ACK slot

    reg [4:0] state;

    localparam IDLE        = 5'd0;
    localparam INIT_START  = 5'd1;
    localparam INIT_ADDR   = 5'd2;
    localparam INIT_ACK1   = 5'd3;
    localparam INIT_REG    = 5'd4;
    localparam INIT_ACK2   = 5'd5;
    localparam INIT_DATA   = 5'd6;
    localparam INIT_ACK3   = 5'd7;
    localparam INIT_STOP   = 5'd8;
    localparam WAIT_STREAM = 5'd9;
    localparam READ_START1 = 5'd10;
    localparam READ_ADDRW  = 5'd11;
    localparam READ_ACK1   = 5'd12;
    localparam READ_REG    = 5'd13;
    localparam READ_ACK2   = 5'd14;
    localparam READ_START2 = 5'd15;
    localparam READ_ADDRR  = 5'd16;
    localparam READ_ACK3   = 5'd17;
    localparam READ_DATA   = 5'd18;
    localparam SEND_ACK    = 5'd19;
    localparam READ_STOP   = 5'd20;
    localparam RETRY_WAIT  = 5'd21;
    localparam ERR_STOP    = 5'd22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_drive_low <= 1'b0;
            sda_drive_low <= 1'b0;
            counter       <= 16'd0;
            bit_count     <= 3'd0;
            byte_count    <= 3'd0;
            tx_byte       <= 8'h00;
            accel_x       <= 16'sd0;
            accel_y       <= 16'sd0;
            accel_z       <= 16'sd0;
            sample_valid  <= 1'b0;
            ack_error     <= 1'b0;
            link_ok       <= 1'b0;
            fail_code     <= 4'd0;
            ack_bad       <= 1'b0;
            stream_timer  <= 20'd0;
            retry_timer   <= 22'd0;
            state         <= IDLE;
        end else begin
            sample_valid <= 1'b0;

            case (state)

                // -------------------------------------------------------
                IDLE: begin
                    scl_drive_low <= 1'b0;
                    sda_drive_low <= 1'b0;
                    counter       <= 16'd0;
                    retry_timer   <= 22'd0;
                    state         <= RETRY_WAIT;
                end

                // Bus idle (both released) for ~50 ms, then (re)start
                RETRY_WAIT: begin
                    scl_drive_low <= 1'b0;
                    sda_drive_low <= 1'b0;
                    counter       <= 16'd0;
                    if (retry_timer == RETRY_CYCLES-1) begin
                        retry_timer <= 22'd0;
                        state       <= INIT_START;
                    end else
                        retry_timer <= retry_timer + 1'b1;
                end

                // -------------------------------------------------------
                // Wake-up write: START, D0, 6B, 00, STOP
                // -------------------------------------------------------
                INIT_START: begin
                    scl_drive_low <= 1'b0;
                    sda_drive_low <= 1'b1;               // START
                    if (counter == DIVIDER-1) begin
                        counter   <= 16'd0;
                        tx_byte   <= 8'hD0;
                        bit_count <= 3'd7;
                        state     <= INIT_ADDR;
                    end else counter <= counter + 1'b1;
                end

                INIT_ADDR: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= INIT_ACK1;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                INIT_ACK1: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd1;
                            state     <= ERR_STOP;
                        end else begin
                            tx_byte   <= 8'h6B;
                            bit_count <= 3'd7;
                            state     <= INIT_REG;
                        end
                    end else counter <= counter + 1'b1;
                end

                INIT_REG: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= INIT_ACK2;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                INIT_ACK2: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd2;
                            state     <= ERR_STOP;
                        end else begin
                            tx_byte   <= 8'h00;
                            bit_count <= 3'd7;
                            state     <= INIT_DATA;
                        end
                    end else counter <= counter + 1'b1;
                end

                INIT_DATA: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= INIT_ACK3;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                INIT_ACK3: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd3;
                            state     <= ERR_STOP;
                        end else
                            state     <= INIT_STOP;
                    end else counter <= counter + 1'b1;
                end

                INIT_STOP: begin
                    if (counter == 0) begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                    end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter       <= 16'd0;
                        sda_drive_low <= 1'b0;           // STOP
                        stream_timer  <= 20'd0;
                        state         <= WAIT_STREAM;
                    end else counter <= counter + 1'b1;
                end

                WAIT_STREAM: begin
                    scl_drive_low <= 1'b0;
                    sda_drive_low <= 1'b0;
                    if (stream_timer >= 20'd100) begin
                        stream_timer <= 20'd0;
                        state        <= READ_START1;
                    end else stream_timer <= stream_timer + 1'b1;
                end

                // -------------------------------------------------------
                // Accelerometer read: START, D0, 3B, RESTART, D1, 6 bytes
                // -------------------------------------------------------
                READ_START1: begin
                    scl_drive_low <= 1'b0;
                    sda_drive_low <= 1'b1;               // START
                    if (counter == DIVIDER-1) begin
                        counter   <= 16'd0;
                        tx_byte   <= 8'hD0;
                        bit_count <= 3'd7;
                        state     <= READ_ADDRW;
                    end else counter <= counter + 1'b1;
                end

                READ_ADDRW: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= READ_ACK1;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                READ_ACK1: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd4;
                            state     <= ERR_STOP;
                        end else begin
                            tx_byte   <= 8'h3B;
                            bit_count <= 3'd7;
                            state     <= READ_REG;
                        end
                    end else counter <= counter + 1'b1;
                end

                READ_REG: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= READ_ACK2;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                READ_ACK2: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd5;
                            state     <= ERR_STOP;
                        end else
                            state     <= READ_START2;
                    end else counter <= counter + 1'b1;
                end

                READ_START2: begin
                    // Repeated START: first release SCL while SDA is still
                    // high (setup time), then pull SDA low while SCL is high.
                    if (counter == 0) begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;
                    end
                    if (counter == DIVIDER/2) sda_drive_low <= 1'b1;
                    if (counter == DIVIDER-1) begin
                        counter   <= 16'd0;
                        tx_byte   <= 8'hD1;
                        bit_count <= 3'd7;
                        state     <= READ_ADDRR;
                    end else counter <= counter + 1'b1;
                end

                READ_ADDRR: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    sda_drive_low <= ~tx_byte[bit_count];
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) state <= READ_ACK3;
                        else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                READ_ACK3: begin
                    sda_drive_low <= 1'b0;
                    if (counter == 0) begin scl_drive_low <= 1'b1; ack_bad <= 1'b0; end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4)) begin
                        if (sda != 1'b0) ack_bad <= 1'b1;
                    end
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (ack_bad) begin
                            ack_error <= 1'b1; link_ok <= 1'b0; fail_code <= 4'd6;
                            state     <= ERR_STOP;
                        end else begin
                            bit_count  <= 3'd7;
                            byte_count <= 3'd0;
                            state      <= READ_DATA;
                        end
                    end else counter <= counter + 1'b1;
                end

                READ_DATA: begin
                    sda_drive_low <= 1'b0;               // release: slave drives
                    if (counter == 0) scl_drive_low <= 1'b1;
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == (3*DIVIDER/4))
                        raw_bytes[byte_count][bit_count] <= sda;
                    if (counter == DIVIDER-1) begin
                        counter <= 16'd0;
                        if (bit_count == 0) begin
                            bit_count <= 3'd7;
                            state     <= SEND_ACK;
                        end else bit_count <= bit_count - 1'b1;
                    end else counter <= counter + 1'b1;
                end

                SEND_ACK: begin
                    if (counter == 0) scl_drive_low <= 1'b1;
                    // bytes 0-4: ACK (drive low). byte 5: NACK (release)
                    if (byte_count == 3'd5) sda_drive_low <= 1'b0;
                    else                    sda_drive_low <= 1'b1;
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        scl_drive_low <= 1'b1;
                        counter       <= 16'd0;
                        if (byte_count == 3'd5) begin
                            accel_x      <= {raw_bytes[0], raw_bytes[1]};
                            accel_y      <= {raw_bytes[2], raw_bytes[3]};
                            accel_z      <= {raw_bytes[4], raw_bytes[5]};
                            sample_valid <= 1'b1;
                            link_ok      <= 1'b1;
                            fail_code    <= 4'd0;
                            state        <= READ_STOP;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                            state      <= READ_DATA;
                        end
                    end else counter <= counter + 1'b1;
                end

                READ_STOP: begin
                    if (counter == 0) begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                    end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter       <= 16'd0;
                        sda_drive_low <= 1'b0;           // STOP
                        state         <= WAIT_STREAM;
                    end else counter <= counter + 1'b1;
                end

                // -------------------------------------------------------
                // Abort after a NACK: clean STOP, then wait and retry
                // -------------------------------------------------------
                ERR_STOP: begin
                    if (counter == 0) begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                    end
                    if (counter == DIVIDER/2) scl_drive_low <= 1'b0;
                    if (counter == DIVIDER-1) begin
                        counter       <= 16'd0;
                        sda_drive_low <= 1'b0;           // STOP
                        retry_timer   <= 22'd0;
                        state         <= RETRY_WAIT;
                    end else counter <= counter + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule