`timescale 1ns/1ps
module Serpent_Sbox_template #(parameter IDX = 0) (
    output wire [31:0] y0, y1, y2, y3
);
    function automatic [3:0] sbox;
        input [3:0] v;
        begin
            case (IDX)
            0: case (v)
                4'h0: sbox = 4'h3;  4'h1: sbox = 4'h8;  4'h2: sbox = 4'hF;  4'h3: sbox = 4'h1;
                4'h4: sbox = 4'hA;  4'h5: sbox = 4'h6;  4'h6: sbox = 4'h5;  4'h7: sbox = 4'hB;
                4'h8: sbox = 4'hE;  4'h9: sbox = 4'hD;  4'hA: sbox = 4'h4;  4'hB: sbox = 4'h2;
                4'hC: sbox = 4'h7;  4'hD: sbox = 4'h0;  4'hE: sbox = 4'h9;  4'hF: sbox = 4'hC;
            endcase
            1: case (v)
                4'h0: sbox = 4'hF;  4'h1: sbox = 4'hC;  4'h2: sbox = 4'h2;  4'h3: sbox = 4'h7;
                4'h4: sbox = 4'h9;  4'h5: sbox = 4'h0;  4'h6: sbox = 4'h5;  4'h7: sbox = 4'hA;
                4'h8: sbox = 4'h1;  4'h9: sbox = 4'hB;  4'hA: sbox = 4'hE;  4'hB: sbox = 4'h8;
                4'hC: sbox = 4'h6;  4'hD: sbox = 4'hD;  4'hE: sbox = 4'h3;  4'hF: sbox = 4'h4;
            endcase
            2: case (v)
                4'h0: sbox = 4'h8;  4'h1: sbox = 4'h6;  4'h2: sbox = 4'h7;  4'h3: sbox = 4'h9;
                4'h4: sbox = 4'h3;  4'h5: sbox = 4'hC;  4'h6: sbox = 4'hA;  4'h7: sbox = 4'hF;
                4'h8: sbox = 4'hD;  4'h9: sbox = 4'h1;  4'hA: sbox = 4'hE;  4'hB: sbox = 4'h4;
                4'hC: sbox = 4'h0;  4'hD: sbox = 4'hB;  4'hE: sbox = 4'h5;  4'hF: sbox = 4'h2;
            endcase
            3: case (v)
                4'h0: sbox = 4'h0;  4'h1: sbox = 4'hF;  4'h2: sbox = 4'hB;  4'h3: sbox = 4'h8;
                4'h4: sbox = 4'hC;  4'h5: sbox = 4'h9;  4'h6: sbox = 4'h6;  4'h7: sbox = 4'h3;
                4'h8: sbox = 4'hD;  4'h9: sbox = 4'h1;  4'hA: sbox = 4'h2;  4'hB: sbox = 4'h4;
                4'hC: sbox = 4'hA;  4'hD: sbox = 4'h7;  4'hE: sbox = 4'h5;  4'hF: sbox = 4'hE;
            endcase
            4: case (v)
                4'h0: sbox = 4'h1;  4'h1: sbox = 4'hF;  4'h2: sbox = 4'h8;  4'h3: sbox = 4'h3;
                4'h4: sbox = 4'hC;  4'h5: sbox = 4'h0;  4'h6: sbox = 4'hB;  4'h7: sbox = 4'h6;
                4'h8: sbox = 4'h2;  4'h9: sbox = 4'h5;  4'hA: sbox = 4'h4;  4'hB: sbox = 4'hA;
                4'hC: sbox = 4'h9;  4'hD: sbox = 4'hE;  4'hE: sbox = 4'h7;  4'hF: sbox = 4'hD;
            endcase
            5: case (v)
                4'h0: sbox = 4'hF;  4'h1: sbox = 4'h5;  4'h2: sbox = 4'h2;  4'h3: sbox = 4'hB;
                4'h4: sbox = 4'h4;  4'h5: sbox = 4'hA;  4'h6: sbox = 4'h9;  4'h7: sbox = 4'hC;
                4'h8: sbox = 4'h0;  4'h9: sbox = 4'h3;  4'hA: sbox = 4'hE;  4'hB: sbox = 4'h8;
                4'hC: sbox = 4'hD;  4'hD: sbox = 4'h6;  4'hE: sbox = 4'h7;  4'hF: sbox = 4'h1;
            endcase
            6: case (v)
                4'h0: sbox = 4'h7;  4'h1: sbox = 4'h2;  4'h2: sbox = 4'hC;  4'h3: sbox = 4'h5;
                4'h4: sbox = 4'h8;  4'h5: sbox = 4'h4;  4'h6: sbox = 4'h6;  4'h7: sbox = 4'hB;
                4'h8: sbox = 4'hE;  4'h9: sbox = 4'h9;  4'hA: sbox = 4'h1;  4'hB: sbox = 4'hF;
                4'hC: sbox = 4'hD;  4'hD: sbox = 4'h3;  4'hE: sbox = 4'hA;  4'hF: sbox = 4'h0;
            endcase
            7: case (v)
                4'h0: sbox = 4'h1;  4'h1: sbox = 4'hD;  4'h2: sbox = 4'hF;  4'h3: sbox = 4'h0;
                4'h4: sbox = 4'hE;  4'h5: sbox = 4'h8;  4'h6: sbox = 4'h2;  4'h7: sbox = 4'hB;
                4'h8: sbox = 4'h7;  4'h9: sbox = 4'h4;  4'hA: sbox = 4'hC;  4'hB: sbox = 4'hA;
                4'hC: sbox = 4'h9;  4'hD: sbox = 4'h3;  4'hE: sbox = 4'h5;  4'hF: sbox = 4'h6;
            endcase
            default: sbox = 4'h0;
            endcase
        end
    endfunction
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : slice
            wire [3:0] vin  = {x3[i], x2[i], x1[i], x0[i]};
            wire [3:0] vout = sbox(vin);
            assign y0[i] = vout[0];
            assign y1[i] = vout[1];
            assign y2[i] = vout[2];
            assign y3[i] = vout[3];
        end
    endgenerate
endmodule
//Обёртки
module Serpent_S0 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(0)) impl (.*);
endmodule

module Serpent_S1 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(1)) impl (.*);
endmodule

module Serpent_S2 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(2)) impl (.*);
endmodule

module Serpent_S3 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(3)) impl (.*);
endmodule

module Serpent_S4 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(4)) impl (.*);
endmodule

module Serpent_S5 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(5)) impl (.*);
endmodule

module Serpent_S6 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(6)) impl (.*);
endmodule

module Serpent_S7 (input  wire [31:0] x0, x1, x2, x3,
                   output wire [31:0] y0, y1, y2, y3);
    Serpent_Sbox_template #(.IDX(7)) impl (.*);
endmodule