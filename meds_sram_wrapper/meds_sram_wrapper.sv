module meds_sram_wrapper #(
  parameter int unsigned DW    = 64,
  parameter int unsigned DEPTH = 1024,
  parameter int unsigned IMPL  = 0   // 0 = behavioural, 1 = FPGA BRAM, 2 = ASIC macro
)(
  input  logic clk_i, rst_ni,
  input  logic req_i, we_i,
  input  logic [$clog2(DEPTH)-1:0] addr_i,
  input  logic [DW/8-1:0]          be_i,
  input  logic [DW-1:0]            wdata_i,
  output logic [DW-1:0]            rdata_o   // registered, 1-cycle latency
);

  // For IMPL = 0: Behavioural Implementation
  if (IMPL == 0) begin: behavioural
    // Memory Array and Read Data Register
    logic [DW-1:0] mem [0:DEPTH-1];
    logic [DW-1:0] rdata_reg;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin 
        rdata_reg <= '0;
      end
      else begin 
        // Write Operation: req_i && we_i, with byte enables
        if (req_i && we_i) begin 
          for (int i = 0; i < (DW >> 3); i++) begin 
            if (be_i[i]) begin 
              mem [addr_i][i*8 +: 8] <= wdata_i[i*8 +: 8];
            end
          end
        end
        // Read Operation: req_i && !we_i
        else if(req_i && !we_i) begin 
          rdata_reg <= mem[addr_i];
        end
      end
    end
    // Assigning Value of Read Data Register, for output
    assign rdata_o = rdata_reg;
  end

  // For IMPL = 1 or 2 (FPGA BRAM and ASIC macro), which are not Implemented Yet
  else begin: not_implemented
    initial $fatal("meds_sram_wrapper: Only IMPL = 0 (bahavioural) is Implemented Yet");
    assign rdata_o = 'x;
  end

endmodule