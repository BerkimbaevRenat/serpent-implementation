`timescale 1ns/1ps

module SerpentEncryptCorePipelined2R (
    input  wire             clk,
    input  wire [127:0]     data_in,
    input  wire [127:0]     subkeys [0:32],
    output wire [127:0]     data_out
);

    reg [127:0] pipeline_reg [0:16];

    always @(posedge clk) begin
        pipeline_reg[0] <= data_in;
    end

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : STAGE_2ROUNDS

            wire [127:0] stage_in = pipeline_reg[i];

            localparam integer R0 = 2*i;
            localparam integer R1 = 2*i + 1;

            wire [127:0] after_r0;

            wire [127:0] mix0 = stage_in ^ subkeys[R0];

            wire [31:0] x0_0 = mix0[ 31:  0];
            wire [31:0] x1_0 = mix0[ 63: 32];
            wire [31:0] x2_0 = mix0[ 95: 64];
            wire [31:0] x3_0 = mix0[127: 96];

            wire [31:0] s0_0, s1_0, s2_0, s3_0;
            generate_sbox #(R0) sbox_r0 (
                .x0(x0_0), .x1(x1_0), .x2(x2_0), .x3(x3_0),
                .y0(s0_0), .y1(s1_0), .y2(s2_0), .y3(s3_0)
            );

            wire [127:0] s0_out = {s3_0, s2_0, s1_0, s0_0};

            wire [127:0] l0_out;
            Serpent_LT lt0(.in_state(s0_out), .out_state(l0_out));

            assign after_r0 = l0_out;

            wire [127:0] after_r1;
            if (R1 == 31) begin : LAST_ROUND

                wire [127:0] mix_last = after_r0 ^ subkeys[31];

                wire [31:0] li0 = mix_last[ 31:  0];
                wire [31:0] li1 = mix_last[ 63: 32];
                wire [31:0] li2 = mix_last[ 95: 64];
                wire [31:0] li3 = mix_last[127: 96];

                wire [31:0] f0, f1, f2, f3;
                Serpent_S7 sbox_last (
                    .x0(li0), .x1(li1), .x2(li2), .x3(li3),
                    .y0(f0),  .y1(f1),  .y2(f2),  .y3(f3)
                );

                assign after_r1 = {f3,f2,f1,f0} ^ subkeys[32];
            end
            else begin : NORMAL_ROUND

                wire [127:0] mix1 = after_r0 ^ subkeys[R1];
                wire [31:0] x0_1 = mix1[ 31:  0];
                wire [31:0] x1_1 = mix1[ 63: 32];
                wire [31:0] x2_1 = mix1[ 95: 64];
                wire [31:0] x3_1 = mix1[127: 96];

                wire [31:0] s0_1, s1_1, s2_1, s3_1;
                generate_sbox #(R1) sbox_r1 (
                    .x0(x0_1), .x1(x1_1), .x2(x2_1), .x3(x3_1),
                    .y0(s0_1), .y1(s1_1), .y2(s2_1), .y3(s3_1)
                );

                wire [127:0] s1_out = {s3_1, s2_1, s1_1, s0_1};

                wire [127:0] l1_out;
                Serpent_LT lt1(.in_state(s1_out), .out_state(l1_out));

                assign after_r1 = l1_out;
            end

            always @(posedge clk) begin
                pipeline_reg[i+1] <= after_r1;
            end

        end
    endgenerate

    assign data_out = pipeline_reg[16];

endmodule

module SerpentEncryptTopPipelined2R (
    input  wire             clk,
    input  wire [127:0]     data_in,
    output wire [127:0]     data_out
);

    localparam [255:0] key256 =
        256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;

    wire [127:0] roundKeys [0:32];

    serpent_keys key_expander (
        .key256 (key256),
        .keys   (roundKeys)
    );

    SerpentEncryptCorePipelined2R core2r (
        .clk       (clk),
        .data_in   (data_in),
        .subkeys   (roundKeys),
        .data_out  (data_out)
    );

endmodule

module generate_sbox #(parameter integer R = 0)(
    input  wire [31:0] x0, x1, x2, x3,
    output wire [31:0] y0, y1, y2, y3
);
    localparam integer SEL = (R % 8);

    generate
        if (SEL == 0) Serpent_S0 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                   .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 1) Serpent_S1 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 2) Serpent_S2 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 3) Serpent_S3 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 4) Serpent_S4 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 5) Serpent_S5 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else if (SEL == 6) Serpent_S6 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
        else               Serpent_S7 s(.x0(x0), .x1(x1), .x2(x2), .x3(x3),
                                        .y0(y0), .y1(y1), .y2(y2), .y3(y3));
    endgenerate
endmodule

module SerpentEncryptECB #(
    parameter integer BLOCKS = 2
)(
    input  wire [BLOCKS*128-1 : 0] data_in,
    output wire [BLOCKS*128-1 : 0] data_out
);

    genvar i;
    generate
        for (i = 0; i < BLOCKS; i = i + 1) begin : GEN_CORE

            wire [127:0] block_in  = data_in  [128*(i+1)-1 : 128*i];
            wire [127:0] block_out;

            SerpentEncryptTopPipelined2R single_block_core (
                .data_in  (block_in),
                .data_out (block_out)
            );

            assign data_out [128*(i+1)-1 : 128*i] = block_out;
        end
    endgenerate

endmodule
