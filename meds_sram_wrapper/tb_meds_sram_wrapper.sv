module tb_meds_sram_wrapper();

    localparam DW    = 64;
    localparam DEPTH = 1024;
    localparam ADDR_W = $clog2(DEPTH);

    logic clk, rst_ni;
    logic req, we;
    logic [ADDR_W-1:0] addr;
    logic [DW/8-1:0] be;
    logic [DW-1:0] wdata, rdata;

    int error_count = 0;

    logic [DW-1:0] ref_mem [0:DEPTH-1];

    meds_sram_wrapper #(
        .DW(DW),
        .DEPTH(DEPTH),
        .IMPL(0)
    ) dut (
        .clk_i   (clk),
        .rst_ni  (rst_ni),
        .req_i   (req),
        .we_i    (we),
        .addr_i  (addr),
        .be_i    (be),
        .wdata_i (wdata),
        .rdata_o (rdata)
    );

    always #5 clk = ~clk;

    function logic [DW-1:0] reference_write(
        input logic [DW-1:0] current,
        input logic [DW-1:0] wdata_i,
        input logic [DW/8-1:0] be_i
    );
        logic [DW-1:0] result = current;
        for (int i = 0; i < DW/8; i++) begin
            if (be_i[i]) begin
                result[i*8 +: 8] = wdata_i[i*8 +: 8];
            end
        end
        return result;
    endfunction

    task check(
        input logic [DW-1:0] actual,
        input logic [DW-1:0] expected,
        input string name
    );
        if (actual !== expected) begin
            error_count++;
            $error("[FAIL] %s: expected %h, got %h at %t",
                   name, expected, actual, $time);
        end else begin
            $display("[PASS] %s: %h", name, actual);
        end
    endtask

    // Fixed: Added #1 delay for race condition
    task write_mem(
        input [ADDR_W-1:0] addr_i,
        input [DW-1:0] data,
        input [DW/8-1:0] be_i
    );
        @(posedge clk);
        req = 1;
        we = 1;
        addr = addr_i;
        wdata = data;
        be = be_i;
        #1;
        @(posedge clk);
        req = 0;
        we = 0;
        #1;
        ref_mem[addr_i] = reference_write(ref_mem[addr_i], data, be_i);
        $display("[%t] WRITE: addr=%h, data=%h, be=%b",
                 $time, addr_i, data, be_i);
    endtask

    // Fixed: Added #1 delay for race condition
    task read_mem(
        input [ADDR_W-1:0] addr_i,
        input string test_name
    );
        @(posedge clk);
        req = 1;
        we = 0;
        addr = addr_i;
        #1;
        @(posedge clk);
        req = 0;
        #1;
        @(posedge clk);
        $display("[%t] READ: addr=%h, got=%h, expected=%h",
                 $time, addr_i, rdata, ref_mem[addr_i]);
        check(rdata, ref_mem[addr_i], test_name);
    endtask

    task reset();
        rst_ni = 0;
        repeat(2) @(posedge clk);
        rst_ni = 1;
        @(posedge clk);
        $display("[%t] Reset complete", $time);
    endtask

    // Initialize all memory to 0
    task init_memory();
        $display("\nInitializing all memory to 0");
        for (int i = 0; i < DEPTH; i++) begin
            write_mem(i, '0, '1);
        end
    endtask

    initial begin
        $timeformat(-9, 2, " ns", 10);

        clk = 0;
        rst_ni = 0;
        req = 0;
        we = 0;
        addr = 0;
        be = 8'hFF;
        wdata = 0;

        for (int i = 0; i < DEPTH; i++) begin
            ref_mem[i] = '0;
        end

        $display("=== meds_sram_wrapper Testbench Started ===");
        reset();
        init_memory();

        // Test 1: Full word write and read
        write_mem(10'h10, 64'hDEADBEEFCAFEBABE, 8'hFF);
        read_mem(10'h10, "Full word write/read");

        // Test 2: Byte-mask write (lower 4 bytes only)
        write_mem(10'h10, 64'hFFFFFFFFAAAAAAAA, 8'b0000_1111);
        read_mem(10'h10, "Byte-mask write (lower 4 bytes)");

        // Test 3: Byte-mask write (upper 4 bytes only)
        write_mem(10'h10, 64'hCAFEBABE12345678, 8'b1111_0000);
        read_mem(10'h10, "Byte-mask write (upper 4 bytes)");

        // Test 4: Multiple addresses with no cross-talk
        write_mem(10'h20, 64'h1111111122222222, 8'hFF);
        read_mem(10'h10, "Address 0x10 unchanged");
        read_mem(10'h20, "Address 0x20 new data");

        // Test 5: Single byte write (byte 0 only)
        // First, write a known value to address 0x40
        write_mem(10'h40, 64'h3333333344444444, 8'hFF);
        read_mem(10'h40, "Before single byte write");

        // Now write only byte 0
        write_mem(10'h40, 64'hFFFFFFFFFFFFFFFF, 8'b0000_0001);
        read_mem(10'h40, "Single byte write (byte 0)");

        // Test 6: Reset behavior
        read_mem(10'h10, "Before reset");
        rst_ni = 0;
        @(posedge clk);
        @(posedge clk);
        check(rdata, '0, "Reset clears rdata_reg");
        rst_ni = 1;
        @(posedge clk);
        read_mem(10'h10, "After reset (memory preserved)");

        $display("\n=========================================");
        if (error_count == 0) begin
            $display("ALL CRITICAL TESTS PASSED");
        end else begin
            $display("%0d CRITICAL TESTS FAILED", error_count);
        end
        $display("=========================================");
        $finish;
    end

endmodule