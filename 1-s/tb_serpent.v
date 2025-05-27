/*`timescale 1ns/1ps
module tb_serpent;
    reg  [127:0] pt  = 256'hEB1645749E2DB18656AB09D1347FA32B7BC95A8F3F6C4D58DEB9317041A7ED62
; 
    wire [127:0] ct;

    SerpentEncryptTop dut (
        .data_in  (pt),
        .data_out (ct)
    );

    initial begin
        $dumpfile("serpent_tb.vcd");
        $dumpvars(0, dut);

        #10 $display("Ciphertext = %032h", ct); 
        #20 $finish;                             
    end
endmodule*/


`timescale 1ns/1ps
module tb_serpent_pipelined;

    reg  clk = 0;
    always #5 clk = ~clk; // период 10ns

    reg  [127:0] din;
    wire [127:0] dout;

    // Подключаем топ
    SerpentEncryptTopPipelined dut (
        .clk      (clk),
        .data_in  (din),
        .data_out (dout)
    );

    integer i;

    initial begin
        // Подаём 4 разных блока, по одному на такт
        din = 128'h00112233445566778899AABBCCDDEEFF;
        #10;

        din = 128'hDEAD_BEEF_DEAD_BEEF_0123_4567_89AB_CDEF;
        #10;

        //din = 128'hFFFFFFFF_FFFFFFFF_00000000_11111111_55AA55AA;
        //#10;

        //din = 128'h0;
        //#10;

        // Далее, можно подавать "случайные" или оставить 0
        // Посмотрим, что выходит
        for (i=0; i<40; i=i+1) begin
            #10;
            $display("t=%0t, dout=%032h", $time, dout);
        end
        $finish;
    end
endmodule

