module tb_meds_sram_wrapper();

    localparam DW = 64;
    localparam DEPTH = 1024;
    localparam ADDR_W = $clog2(DEPTH);

    logic clk_i, rst_ni;
    logic req_i, we_i;
    logic [ADDR_W-1:0] addr_i;
    logic [DW/8-1:0]     be_i;
    logic [DW-1:0]    wdata_i;
    logic [DW-1:0]    rdata_o;

    int error_count = 0;

    logic [DW-1:0] ref_mem [0:DEPTH-1];

    meds_sram_wrapper #(.DW(DW), .DEPTH(DEPTH), .IMPL(0)) DUT (.clk_i(clk_i), .rst_ni(rst_ni), .req_i(req_i), .we_i(we_i),
    .addr_i(addr_i), .be_i(be_i), .wdata_i(wdata_i), .rdata_o(rdata_o));

        initial clk_i = 0;
        always #5 clk_i = ~clk_i;

    function logic [DW-1:0] ref_write (input logic [DW-1:0] curr_data, input logic [DW-1:0] wdata_i, input logic [(DW >> 3)-1:0] be_i);
        logic [DW-1:0] new_data = curr_data;
        for (int i = 0; i < (DW >> 3); i++) begin 
            if (be_i[i]) begin 
                new_data [i*8 +: 8] = wdata_i[i*8 +: 8];
            end
            end
        return new_data;
    endfunction

    task check(input logic [DW-1:0] actual, input logic [DW-1:0] expected);
        if (actual === expected) begin 
        $display("Test Passed: Actual = %h, Expected = %h", actual, expected);
        end 
        else begin 
        error_count += 1;
        $display("Test Failed: Actual = %h, Expected = %h", actual, expected);
        end
    endtask

    task write(input logic [ADDR_W-1:0] addr, input logic [DW-1:0] data, input logic [(DW >> 3)-1:0] be);

        @(posedge clk_i);
        req_i  = 1;
        we_i   = 1;
        addr_i = addr;
        be_i   = be;
        wdata_i= data;
        #1;
        @(posedge clk_i);
        req_i = 0;
        we_i  = 0;
        #1;
        ref_mem [addr] = ref_write(ref_mem [addr], data, be);
        $display("Write @ addr = %h, data = %h, be = %b", addr, data, be);
    endtask

    task read(input logic [ADDR_W-1:0] addr);
        @(posedge clk_i);
        req_i = 1;
        we_i  = 0; 
        addr_i= addr;
        #1;
        @(posedge clk_i);
        req_i = 0;
        #1;
        @(posedge clk_i);
        $display("Read @ addr = %h, actual data = %h, expected data = %h", addr, rdata_o, ref_mem [addr]);
        check(rdata_o, ref_mem[addr]);
    endtask

    task reset_ref_mem(); 
        for (int j = 0; j < DEPTH; j++) begin 
            ref_mem [j] = 'x;
        end
    endtask

    initial begin 
        rst_ni = 0;
        @(posedge clk_i);
        rst_ni = 1;

        // Test#1: Writing Full Word
        $display("Test#1: Writing Full Word");
        write(10'h10, 64'hDEADBEEFDEADBEEF, 8'hFF);
        read (10'h10);

        // Test#2: Writing Lower Half Word
        $display("Test#2: Writing Lower Half Word");
        write(10'h10, 64'hDEADBEEF22222222, 8'h0F);
        read (10'h10);

        // Test#3: Writing Upper Half Word
        $display("Test#3: Writing Upper Half Word");
        write(10'h10, 64'h11111111DEADBEEF, 8'hF0);
        read (10'h10);

        // Test#4: Writing Only 1 Bytes at Different Address
        $display("Test#4: Writing Only 1 Bytes at Different Address");
        write(10'h20, 64'hDEADBEEFDEADBEEF, 8'h01);
        read (10'h20);

        // Test#5: Checking No Cross-Walk at Two Different Address
        $display("Test#5: Test#5: Checking No Cross-Walk at Two Different Address");
        read (10'h10);
        read (10'h20);

        if (error_count === 0) begin 
        $display("All Tests Passed");
        end
        else begin 
        $display("Some Tests Failed (%d tests failed)", error_count);
        end

        $stop;
    end

endmodule