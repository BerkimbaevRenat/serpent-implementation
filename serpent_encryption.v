`timescale 1ns/1ps
module SerpentEncryptCore (
    input  wire [127:0]               plaintext,
    input  wire [127:0]               subkeys [0:32],
    output wire [127:0]               ciphertext
);
    wire [127:0] state [0:32];
    assign state[0] = plaintext;

    genvar r;
    generate
        for (r = 0; r < 31; r = r + 1) begin : ROUND
            wire [127:0] mix = state[r] ^ subkeys[r];

            wire [31:0] x0 = mix[ 31:  0];
            wire [31:0] x1 = mix[ 63: 32];
            wire [31:0] x2 = mix[ 95: 64];
            wire [31:0] x3 = mix[127: 96];

            wire [31:0] s0, s1, s2, s3;
            if      (r % 8 == 0) begin : SB0
                Serpent_S0 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 1) begin : SB1
                Serpent_S1 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 2) begin : SB2
                Serpent_S2 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 3) begin : SB3
                Serpent_S3 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 4) begin : SB4
                Serpent_S4 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 5) begin : SB5
                Serpent_S5 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else if (r % 8 == 6) begin : SB6
                Serpent_S6 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            else begin : SB7
                Serpent_S7 sb (.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                               .y0(s0), .y1(s1), .y2(s2), .y3(s3));
            end
            wire [31:0] l0, l1, l2, l3;
            Serpent_LT lt (.x0(s0), .x1(s1), .x2(s2), .x3(s3),
                           .y0(l0), .y1(l1), .y2(l2), .y3(l3));
            assign state[r+1] = {l3, l2, l1, l0};
        end
    endgenerate
    wire [127:0] last_in  = state[31] ^ subkeys[31];

    wire [31:0] li0 = last_in[ 31:  0];
    wire [31:0] li1 = last_in[ 63: 32];
    wire [31:0] li2 = last_in[ 95: 64];
    wire [31:0] li3 = last_in[127: 96];

    wire [31:0] f0, f1, f2, f3;
    Serpent_S7 sbox_last (.x0(li0), .x1(li1), .x2(li2), .x3(li3),
                          .y0(f0),  .y1(f1),  .y2(f2),  .y3(f3));

    assign ciphertext = {f3, f2, f1, f0} ^ subkeys[32];
endmodule

module SerpentEncryptTop (
    //input  wire [255:0] key256,
    input  wire [127:0] data_in,
    output wire [127:0] data_out
);
    intial begin
    static reg [255:0] key256 = 256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;
    wire [127:0] roundKeys [0:32];

    serpent_keys key_expander (
        .key256 (key256),
        .keys   (roundKeys)
    );

    SerpentEncryptCore core (
        .plaintext  (data_in),
        .subkeys    (roundKeys),
        .ciphertext (data_out)
    );

    `ifndef SYNTHESIS
    reg [127:0] last_ct = 128'hX;
    always @(*) begin
        if (data_out !== last_ct) begin
            $display("[%0t] Serpent CT = %032h", $time, data_out);
            last_ct = data_out;
        end
    end
`endif
    end
endmodule
