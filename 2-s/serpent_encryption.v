`timescale 1ns/1ps
`default_nettype none

module SerpentEncryptCorePipelined2R (
    input  wire             clk,
    input  wire             rst,
    input  wire             in_valid,
    input  wire [127:0]     data_in,
    input  wire [127:0]     subkeys [0:32],
    output wire             out_valid,
    output wire [127:0]     data_out
);

    // Subkeys must remain stable while any block is in flight. The top
    // module enforces this by flushing validity whenever a key is loaded.
    // 17 register banks preserve the original fully unrolled datapath.
    reg [127:0] pipeline_reg [0:16];
    reg [16:0] valid_pipeline;

    always @(posedge clk) begin
        if (rst)
            valid_pipeline <= 17'b0;
        else
            valid_pipeline <= {valid_pipeline[15:0], in_valid};
    end


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

    assign out_valid = valid_pipeline[16];
    // Payload registers need no reset: invalid output is always masked.
    assign data_out = out_valid ? pipeline_reg[16] : 128'b0;

endmodule

// Byte 0 of the plaintext/ciphertext is bits [7:0] (little-endian words).
// A block is accepted on a rising edge with in_valid && in_ready.
// It appears with out_valid exactly 16 clock periods later. There is no
// output backpressure: a fully occupied pipeline produces one block per cycle.
// rst is synchronous and active high. key_load has priority over data input:
// it registers all expanded subkeys and discards every in-flight block. The
// newly loaded key can accept its first block on the following rising edge.
module SerpentEncryptTopPipelined2R #(
    parameter integer KEY_BITS = 256
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    key_load,
    input  wire [KEY_BITS-1:0]     key_in,
    input  wire                    in_valid,
    input  wire [127:0]            data_in,
    output reg                     key_ready,
    output wire                    in_ready,
    output wire                    out_valid,
    output wire [127:0]            data_out
);
    wire [127:0] expanded_keys [0:32];
    reg  [127:0] roundKeys [0:32];
    integer k;

    serpent_keys #(.KEY_BITS(KEY_BITS)) key_expander (
        .key_in (key_in),
        .keys   (expanded_keys)
    );

    always @(posedge clk) begin
        if (rst) begin
            key_ready <= 1'b0;
        end else if (key_load) begin
            for (k = 0; k < 33; k = k + 1)
                roundKeys[k] <= expanded_keys[k];
            key_ready <= 1'b1;
        end
    end

    assign in_ready = key_ready && !key_load && !rst;

    SerpentEncryptCorePipelined2R core (
        .clk       (clk),
        .rst       (rst || key_load),
        .in_valid  (in_valid && in_ready),
        .data_in   (data_in),
        .subkeys   (roundKeys),
        .out_valid (out_valid),
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

// Parallel ECB lanes share the key-load and valid controls. All lanes accept
// a packed group together; lane 0 occupies data_in[127:0]. Their readiness
// and output validity are identical, so lane 0 supplies the shared flags.
module SerpentEncryptECB #(
    parameter integer BLOCKS = 2,
    parameter integer KEY_BITS = 256
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        key_load,
    input  wire [KEY_BITS-1:0]         key_in,
    input  wire                        in_valid,
    input  wire [BLOCKS*128-1:0]       data_in,
    output wire                        key_ready,
    output wire                        in_ready,
    output wire                        out_valid,
    output wire [BLOCKS*128-1:0]       data_out
);
    wire [BLOCKS-1:0] lane_key_ready;
    wire [BLOCKS-1:0] lane_in_ready;
    wire [BLOCKS-1:0] lane_out_valid;

    genvar i;
    generate
        if (BLOCKS < 1) begin : INVALID_BLOCK_COUNT
            initial $fatal(1, "BLOCKS must be positive");
        end
        for (i = 0; i < BLOCKS; i = i + 1) begin : GEN_CORE
            SerpentEncryptTopPipelined2R #(.KEY_BITS(KEY_BITS)) single_block_core (
                .clk       (clk),
                .rst       (rst),
                .key_load  (key_load),
                .key_in    (key_in),
                .in_valid  (in_valid),
                .data_in   (data_in[128*i +: 128]),
                .key_ready (lane_key_ready[i]),
                .in_ready  (lane_in_ready[i]),
                .out_valid (lane_out_valid[i]),
                .data_out  (data_out[128*i +: 128])
            );
        end
    endgenerate

    assign key_ready = lane_key_ready[0];
    assign in_ready  = lane_in_ready[0];
    assign out_valid = lane_out_valid[0];
endmodule

`default_nettype wire
