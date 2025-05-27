`timescale 1ns/1ps
`default_nettype none
function automatic [31:0] rotl32;
    input [31:0] d;
    input [4:0]  n;            // 5 бит достаточно, т.к. 0-31
begin
    rotl32 = (d << n) | (d >> (32 - n));
end
endfunction

module Serpent_LT
(
    input  wire [127:0] in_state,
    output wire [127:0] out_state
);
    wire [31:0] X0_i, X1_i, X2_i, X3_i;
    assign {X3_i, X2_i, X1_i, X0_i} = in_state;

    wire [31:0] X0_r1 = rotl32(X0_i, 13);
    wire [31:0] X2_r1 = rotl32(X2_i,  3);

    wire [31:0] X1_r1 = ((X1_i ^ X0_r1) ^ X2_r1);
    wire [31:0] X3_r1 = ((X3_i ^ X2_r1) ^ (X0_r1 << 3));

    wire [31:0] X1_r2 = rotl32(X1_r1, 1);
    wire [31:0] X3_r2 = rotl32(X3_r1, 7);

    wire [31:0] X0_r2 = ((X0_r1 ^ X1_r2) ^ X3_r2);
    wire [31:0] X2_r2 = ((X2_r1 ^ X3_r2) ^ (X1_r2 << 7));

    wire [31:0] Y0 = rotl32(X0_r2, 5);
    wire [31:0] Y2 = rotl32(X2_r2,22);
    wire [31:0] Y1 = X1_r2;            
    wire [31:0] Y3 = X3_r2;

    assign out_state = {Y3, Y2, Y1, Y0};
endmodule

`default_nettype wire
