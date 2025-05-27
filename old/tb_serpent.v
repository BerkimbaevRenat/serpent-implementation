`timescale 1ns/1ps
module tb_serpent;
    reg  [127:0] pt  = 128'h00112233445566778899AABBCCDDEEFF; 
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
endmodule
