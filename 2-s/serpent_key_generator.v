module serpent_keys (
    input  wire [255:0]       key256,
    output wire [127:0]       keys  [0:32]
);
    localparam [31:0] PHI = 32'h9e3779b9;

    reg [31:0] w [0:139];
    integer    i;

 
    always @* begin
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


            localparam int SBOX = (j + 3) % 8;

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
