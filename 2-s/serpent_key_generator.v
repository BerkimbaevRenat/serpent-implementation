`timescale 1ns/1ps
`default_nettype none

// Combinational Serpent key expansion. Byte 0 is key_in[7:0]; each
// consecutive group of four bytes forms a little-endian 32-bit word.
module serpent_keys #(
    parameter integer KEY_BITS = 256
)(
    input  wire [KEY_BITS-1:0] key_in,
    output wire [127:0]       keys  [0:32]
);
    localparam [31:0] PHI = 32'h9e3779b9;

    // Serpent padding appends one bit after the supplied short key,
    // then zeroes to 256 bits. A full 256-bit key is used unchanged.
    wire [255:0] key256;
    generate
        if (KEY_BITS == 256) begin : FULL_KEY
            assign key256 = key_in;
        end else if (KEY_BITS == 128 || KEY_BITS == 192) begin : SHORT_KEY
            assign key256 = {{(255-KEY_BITS){1'b0}}, 1'b1, key_in};
        end else begin : INVALID_KEY_SIZE
            assign key256 = 256'b0;
            initial $fatal(1, "KEY_BITS must be 128, 192, or 256");
        end
    endgenerate

    // always_comb executes at time zero even for a constant initial key.
    // Blocking assignments evaluate the full recurrence in one process.
    reg [31:0] w [0:139];
    integer i;
    always_comb begin
        for (i = 0; i < 8; i = i + 1)
            w[i] = key256[i*32 +: 32];
        for (i = 8; i < 140; i = i + 1) begin
            w[i] = w[i-8] ^ w[i-5] ^ w[i-3] ^ w[i-1] ^ PHI ^ (i-8);
            w[i] = (w[i] << 11) | (w[i] >> (32 - 11));
        end
    end

    genvar j;
    generate
        for (j = 0; j < 33; j = j + 1) begin : gen_sboxes
            wire [31:0] x0 = w[4*j + 8];
            wire [31:0] x1 = w[4*j + 1 + 8];
            wire [31:0] x2 = w[4*j + 2 + 8];
            wire [31:0] x3 = w[4*j + 3 + 8];

            wire [31:0] y0, y1, y2, y3;


            // 3, 2, 1, 0, 7, ...; 35-j stays nonnegative for j=0..32.
            localparam integer SBOX = (35 - j) % 8;

            if (SBOX == 0) Serpent_S0 s0 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                         .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 1) Serpent_S1 s1 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 2) Serpent_S2 s2 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 3) Serpent_S3 s3 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 4) Serpent_S4 s4 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 5) Serpent_S5 s5 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (SBOX == 6) Serpent_S6 s6 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else               Serpent_S7 s7 (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                               .y0(y0), .y1(y1), .y2(y2), .y3(y3));

            assign keys[j] = { y3, y2, y1, y0 };
        end
    endgenerate

endmodule

`default_nettype wire
