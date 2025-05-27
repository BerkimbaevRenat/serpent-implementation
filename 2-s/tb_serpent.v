`timescale 1ns/1ps
module tb_serpent_pipelined;

    reg  clk = 0;
    always #5 clk = ~clk;

    reg  [127:0] din;
    wire [127:0] dout;

    SerpentEncryptTopPipelined2R dut (
        .clk      (clk),
        .data_in  (din),
        .data_out (dout)
    );

    integer i;

    initial begin

        din = 128'h00112233445566778899AABBCCDDEEFF;
        #10;

        din = 128'hDEAD_BEEF_DEAD_BEEF_0123_4567_89AB_CDEF;
        #10;

        for (i=0; i<40; i=i+1) begin
            #10;
            $display("t=%0t, dout=%032h", $time, dout);
        end
        $finish;
    end
endmodule

