`timescale 1ns/1ps

module SerpentEncryptCorePipelined (
    input  wire             clk,
    input  wire [127:0]     data_in,
    input  wire [127:0]     subkeys [0:32],
    output wire [127:0]     data_out
);

    reg [127:0] pipeline_reg [0:32];
    always @(posedge clk) begin
        pipeline_reg[0] <= data_in;
    end

    genvar r;
    generate

        for (r = 0; r < 31; r = r + 1) begin : ROUND_STAGE
            wire [127:0] state_in = pipeline_reg[r];
            wire [127:0] mix      = state_in ^ subkeys[r];

            wire [31:0] x0 = mix[ 31:  0];
            wire [31:0] x1 = mix[ 63: 32];
            wire [31:0] x2 = mix[ 95: 64];
            wire [31:0] x3 = mix[127: 96];

            wire [31:0] s0, s1, s2, s3;
            if      (r % 8 == 0) Serpent_S0 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 1) Serpent_S1 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 2) Serpent_S2 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 3) Serpent_S3 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 4) Serpent_S4 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 5) Serpent_S5 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else if (r % 8 == 6) Serpent_S6 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));
            else                 Serpent_S7 sb(.x0(x0),.x1(x1),.x2(x2),.x3(x3), .y0(s0),.y1(s1),.y2(s2),.y3(s3));

            wire [127:0] s = {s3, s2, s1, s0};

            wire [127:0] l;
            Serpent_LT lt(.in_state(s), .out_state(l));

            always @(posedge clk) begin
                pipeline_reg[r+1] <= l;
            end
        end
    endgenerate

    wire [127:0] last_in = pipeline_reg[31] ^ subkeys[31];

    wire [31:0] li0 = last_in[ 31:  0];
    wire [31:0] li1 = last_in[ 63: 32];
    wire [31:0] li2 = last_in[ 95: 64];
    wire [31:0] li3 = last_in[127: 96];

    wire [31:0] f0, f1, f2, f3;
    Serpent_S7 sbox_last(.x0(li0), .x1(li1), .x2(li2), .x3(li3),
                         .y0(f0), .y1(f1), .y2(f2), .y3(f3));

    wire [127:0] final_block = {f3, f2, f1, f0} ^ subkeys[32];

    always @(posedge clk) begin
        pipeline_reg[32] <= final_block;
    end

    assign data_out = pipeline_reg[32];

endmodule
module SerpentEncryptTopPipelined (
    input  wire             clk,
    input  wire [127:0]     data_in,
    output wire [127:0]     data_out
);

    localparam [255:0] key256 = 256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;

    wire [127:0] roundKeys [0:32];
    serpent_keys key_expander (
        .key256 (key256),
        .keys   (roundKeys)
    );

    SerpentEncryptCorePipelined core_pipelined (
        .clk       (clk),
        .data_in   (data_in),
        .subkeys   (roundKeys),
        .data_out  (data_out)
    );

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

            SerpentEncryptTopPipelined single_block_core (
                .data_in  (block_in),
                .data_out (block_out)
            );

            assign data_out [128*(i+1)-1 : 128*i] = block_out;
        end
    endgenerate

endmodule
