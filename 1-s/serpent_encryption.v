/*`timescale 1ns/1ps
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
            wire [127:0] l;
            wire [127:0] s = {s3, s2, s1, s0};
            
            Serpent_LT lt (.in_state(s), .out_state(l));
            assign state[r+1] = l;
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
    
    localparam [255:0] key256 = 256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;
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

endmodule*/




`timescale 1ns/1ps
module SerpentEncryptCorePipelined (
    input  wire             clk,
    input  wire [127:0]     data_in,          // Каждый такт можно подавать НОВЫЙ блок
    input  wire [127:0]     subkeys [0:32],
    output wire [127:0]     data_out          // Каждый такт - выход для блока, поданного 32 такта назад
);

    // ----------------------------------
    // pipeline_reg[r] хранит состояние
    // перед "раундом" r.
    // Итого нужно 33 регистра (0..32),
    // т.к. после последнего мы получаем data_out.
    // ----------------------------------
    reg [127:0] pipeline_reg [0:32];

    // Подключаем на вход конвейера "data_in":
    always @(posedge clk) begin
        pipeline_reg[0] <= data_in;
    end

    genvar r;
    generate
        // ------------------------------------------
        // 31 РАУНД (0..30) - каждый в своей стадии
        // ------------------------------------------
        for (r = 0; r < 31; r = r + 1) begin : ROUND_STAGE
            // Вычисляем результат раунда r на каждом такте
            wire [127:0] state_in = pipeline_reg[r];
            wire [127:0] mix      = state_in ^ subkeys[r];

            // Разбиваем mix на x0..x3 (4 слова по 32 бита)
            wire [31:0] x0 = mix[ 31:  0];
            wire [31:0] x1 = mix[ 63: 32];
            wire [31:0] x2 = mix[ 95: 64];
            wire [31:0] x3 = mix[127: 96];

            // Выход S-блока
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

            // Линейное преобразование LT
            wire [127:0] l;
            Serpent_LT lt(.in_state(s), .out_state(l));

            // На выходе этой стадии результат записываем в pipeline_reg[r+1]
            always @(posedge clk) begin
                pipeline_reg[r+1] <= l;
            end
        end
    endgenerate

    // ------------------------------------------
    // ФИНАЛЬНЫЙ РАУНД (раунд 31)
    //  XOR c subkeys[31], пропуск через S7, XOR c subkeys[32]
    // ------------------------------------------
    wire [127:0] last_in = pipeline_reg[31] ^ subkeys[31];

    wire [31:0] li0 = last_in[ 31:  0];
    wire [31:0] li1 = last_in[ 63: 32];
    wire [31:0] li2 = last_in[ 95: 64];
    wire [31:0] li3 = last_in[127: 96];

    wire [31:0] f0, f1, f2, f3;
    Serpent_S7 sbox_last(.x0(li0), .x1(li1), .x2(li2), .x3(li3),
                         .y0(f0), .y1(f1), .y2(f2), .y3(f3));

    wire [127:0] final_block = {f3, f2, f1, f0} ^ subkeys[32];

    // Пишем результат финального шага в pipeline_reg[32]
    always @(posedge clk) begin
        pipeline_reg[32] <= final_block;
    end

    // Выход шифра - это содержимое pipeline_reg[32]
    assign data_out = pipeline_reg[32];

endmodule
module SerpentEncryptTopPipelined (
    input  wire             clk,
    input  wire [127:0]     data_in,
    output wire [127:0]     data_out
);

    // Ваш 256-битный ключ (без изменений)
    localparam [255:0] key256 = 256'h0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF_0123_4567_89AB_CDEF;

    // Подключи
    wire [127:0] roundKeys [0:32];
    serpent_keys key_expander (
        .key256 (key256),
        .keys   (roundKeys)
    );

    // Новое конвейерное ядро
    SerpentEncryptCorePipelined core_pipelined (
        .clk       (clk),
        .data_in   (data_in),
        .subkeys   (roundKeys),
        .data_out  (data_out)
    );

endmodule



//===========================================================
// SerpentEncryptECB (пример на параллельный ECB)
//   Параметр BLOCKS: сколько 128-битных блоков шифровать
//===========================================================
module SerpentEncryptECB #(
    parameter integer BLOCKS = 2
)(
    input  wire [BLOCKS*128-1 : 0] data_in,   // входная шина, разбитая на BLOCKS блоков по 128 бит
    output wire [BLOCKS*128-1 : 0] data_out   // выходная шина, тоже разбитая по 128 бит
);

    genvar i;
    generate
        for (i = 0; i < BLOCKS; i = i + 1) begin : GEN_CORE
            // Выделяем "свой" 128-битный фрагмент входа
            wire [127:0] block_in  = data_in  [128*(i+1)-1 : 128*i];
            wire [127:0] block_out;

            // Подключаем ваше уже готовое одно-блочное ядро
            SerpentEncryptTopPipelined single_block_core (
                .data_in  (block_in),
                .data_out (block_out)
            );

            // Записываем результат в общий выход
            assign data_out [128*(i+1)-1 : 128*i] = block_out;
        end
    endgenerate

endmodule
