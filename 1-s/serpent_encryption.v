`timescale 1ns/1ps
`default_nettype none

module SerpentEncryptCorePipelined (
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
    // 33 register banks preserve the original fully unrolled datapath.
    reg [127:0] pipeline_reg [0:32];
    reg [32:0] valid_pipeline;

    always @(posedge clk) begin
        if (rst)
            valid_pipeline <= 33'b0;
        else
            valid_pipeline <= {valid_pipeline[31:0], in_valid};
    end

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

    assign out_valid = valid_pipeline[32];
    // Payload registers need no reset: invalid output is always masked.
    assign data_out = out_valid ? pipeline_reg[32] : 128'b0;

endmodule
// Byte 0 of the plaintext/ciphertext is bits [7:0] (little-endian words).
// A block is accepted on a rising edge with in_valid && in_ready.
// It appears with out_valid exactly 32 clock periods later. There is no
// output backpressure: a fully occupied pipeline produces one block per cycle.
// rst is synchronous and active high. key_load has priority over data input:
// it registers all expanded subkeys and discards every in-flight block. The
// newly loaded key can accept its first block on the following rising edge.
module SerpentEncryptTopPipelined #(
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

    SerpentEncryptCorePipelined core (
        .clk       (clk),
        .rst       (rst || key_load),
        .in_valid  (in_valid && in_ready),
        .data_in   (data_in),
        .subkeys   (roundKeys),
        .out_valid (out_valid),
        .data_out  (data_out)
    );
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
            SerpentEncryptTopPipelined #(.KEY_BITS(KEY_BITS)) single_block_core (
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
