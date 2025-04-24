module serpent_keys (
    input  wire [255:0] key256,
    output wire [127:0] keys[32:0]
);
    always @* begin
        //delete static before use
        //static reg [255:0] key256 = 256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;
        static reg [31:0] phi = 32'h9e3779b9;
        reg [31:0] mid_keys[-8:131];
        reg [31:0] tmp, x0, x1, x2, x3, y0, y1, y2, y3;
        static integer i = 0;
        static integer rem = 0;
        //trynna slice key256 and put it to mid_keys[-8, -7, ... , -1]
        for(i = 0; i < 8; i = i + 1) begin
            mid_keys[-8 + i] = key256[i*32 +: 32];
        end
        //soon will be generating new keys
        for(i = 0; i < 132; i = i + 1) begin
            mid_keys[i] = (((((mid_keys[i - 8] ^ mid_keys[i - 5]) ^ mid_keys[i - 3]) ^ mid_keys[i-1]) ^ i) ^phi);
            tmp = mid_keys[i];
            mid_keys[i] = (tmp << 11) | (tmp >> 21);
        end
        //print(otladka)
        for(i = -8; i < 132; i = i+1) begin
            $display("mid_keys[%0d] = %032b", i, mid_keys[i]);
        end
        //generating output keys
        for (i = 0; i < 33; i = i + 1) begin
            rem = (32 + 3 - i) % 8;
            //input
            x0 = mid_keys[4*i];
            x1 = mid_keys[4*i + 1];
            x2 = mid_keys[4*i + 2];
            x3 = mid_keys[4*i + 3];
            //output
            //y0, y1, y2, y3
            if (rem == 0) Serpent_S0 sbox0 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 1) Serpent_S1 sbox1 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 2) Serpent_S2 sbox2 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 3) Serpent_S3 sbox3 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 4) Serpent_S4 sbox4 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 5) Serpent_S5 sbox5 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else if (rem == 6) Serpent_S6 sbox6 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            else Serpent_S7 sbox7 (.x0(x0), .x1(x1), .x2(x2), .x3(x3), .y0(y0), .y1(y1), .y2(y2), .y3(y3));
            assign keys[i] = {y3, y2, y1, y0};
        end
    end
endmodule
