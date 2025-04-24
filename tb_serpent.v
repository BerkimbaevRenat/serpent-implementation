`timescale 1ns/1ps
module tb_serpent;
    reg  [127:0] pt  = 128'h00112233445566778899AABBCCDDEEFF; // пример PlainText
    wire [127:0] ct;

    // >>> ваш верхний модуль <<<
    SerpentEncryptTop dut (
        .data_in  (pt),
        .data_out (ct)
    );

    initial begin
        // VCD для просмотра в GTKWave (опция)
        $dumpfile("serpent_tb.vcd");
        $dumpvars(0, dut);

        #10 $display("Ciphertext = %032h", ct); // подождём 10 ns и выведем результат
        #20 $finish;                             // завершить симуляцию
    end
endmodule
