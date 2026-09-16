`timescale 1ns/1ps
// Standalone smoke test. Full regression: python3 tests/run_tests.py
// Author-published NESSIE Serpent-256, set 3 vector 0: zero key/plaintext.
// External ciphertext bytes: 49672BA898D98DF95019180445491089
module tb_serpent_pipelined;
    localparam LATENCY = 16;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, key_load = 0, in_valid = 0;
    reg [255:0] key_in = 0;
    reg [127:0] data_in = 0;
    wire key_ready, in_ready, out_valid;
    wire [127:0] data_out;
    integer i;
    SerpentEncryptTopPipelined2R #(.KEY_BITS(256)) dut (
        .clk(clk), .rst(rst), .key_load(key_load), .key_in(key_in),
        .in_valid(in_valid), .data_in(data_in), .key_ready(key_ready),
        .in_ready(in_ready), .out_valid(out_valid), .data_out(data_out));
    initial begin
        repeat (2) begin
            @(posedge clk); #1;
            if (key_ready !== 0 || out_valid !== 0 || data_out !== 0)
                $fatal(1, "Reset failed");
        end
        @(negedge clk); rst = 0; key_load = 1;
        @(posedge clk); #1;
        if (key_ready !== 1 || out_valid !== 0) $fatal(1, "Key load failed");
        @(negedge clk); key_load = 0; in_valid = 1;
        #1;
        if (in_ready !== 1) $fatal(1, "Input not ready after key load");
        @(posedge clk); #1;
        if (out_valid !== 0) $fatal(1, "Premature output on acceptance edge");
        @(negedge clk); in_valid = 0;
        for (i = 1; i <= LATENCY; i = i + 1) begin
            @(posedge clk); #1;
            if (i < LATENCY && (out_valid !== 0 || data_out !== 0))
                $fatal(1, "Premature output at cycle %0d", i);
        end
        if (out_valid !== 1 || data_out !== 128'h8910494504181950f98dd998a82b6749)
            $fatal(1, "NESSIE KAT failed: got %032h valid=%b", data_out, out_valid);
        @(posedge clk); #1;
        if (out_valid !== 0 || data_out !== 0) $fatal(1, "Bubble output failed");
        $display("PASS NESSIE Serpent-256 smoke test, latency=%0d", LATENCY);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
