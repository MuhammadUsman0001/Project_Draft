// Copyright 2026 Maktab-e-Digital Systems Lahore.
// SPDX-License-Identifier: Apache-2.0
//
// s1_icache_datapath : Instruction Cache Datapath            [WIP — R-03]
// Spec: INTERFACES.md §8, SPEC §15
//
// Datapath for the 2-way set-associative instruction cache.
// Handles tag/data array access, hit detection, LRU, and data selection.
//
// Testbench: verif/unit/tb_s1_icache_datapath.sv
// =============================================================================

module s1_icache_datapath #(
    parameter int unsigned CACHE_SIZE_KB   = 16,
    parameter int unsigned LINE_SIZE_BYTES = 64,
    parameter int unsigned ASSOCIATIVITY   = 2,
    parameter int unsigned ADDR_WIDTH      = 40
)(
    // Clock & Reset
    input  logic                        clk_i,
    input  logic                        rst_ni,

    // Request Interface (from Controller)
    input  logic                        req_valid_i,
    input  logic [ADDR_WIDTH-1:0]       req_addr_i,

    // Refill Interface (from Controller)
    input  logic                        refill_we_i,
    input  logic                        refill_way_sel_i,   // 0 = way0, 1 = way1
    input  logic [LINE_SIZE_BYTES<<3-1:0] refill_data_i,
    input  logic [ADDR_WIDTH-1:0]       refill_addr_i,

    // Outputs to Controller
    output logic                        hit_o,
    output logic [ASSOCIATIVITY-1:0]    hit_way_o,
    output logic                        lru_way_o,

    // Output to CPU (via Controller)
    output logic [31:0]                 rsp_data_o
);

    // =========================================================================
    // Derived Parameters
    // =========================================================================
    localparam int unsigned LINE_SIZE_BITS = LINE_SIZE_BYTES * 8;   // 512
    localparam int unsigned OFFSET_BITS    = $clog2(LINE_SIZE_BYTES); // 6
    localparam int unsigned NUM_SETS       = CACHE_SIZE_KB * 1024
                                             / (LINE_SIZE_BYTES * ASSOCIATIVITY);
    localparam int unsigned INDEX_BITS     = $clog2(NUM_SETS);
    localparam int unsigned TAG_BITS       = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int unsigned TAG_ENTRY_WIDTH = TAG_BITS + 1;          // {valid, tag}

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // --- Address Decode ---
    logic [TAG_BITS-1:0]        req_tag;
    logic [INDEX_BITS-1:0]      req_index;
    logic [OFFSET_BITS-1:0]     req_offset;

    logic [TAG_BITS-1:0]        refill_tag;
    logic [INDEX_BITS-1:0]      refill_index;
    logic [OFFSET_BITS-1:0]     refill_offset;

    // --- Tag Array Signals ---
    logic [TAG_ENTRY_WIDTH-1:0] tag0_rdata;
    logic [TAG_ENTRY_WIDTH-1:0] tag1_rdata;
    logic [TAG_ENTRY_WIDTH-1:0] tag0_wdata;
    logic [TAG_ENTRY_WIDTH-1:0] tag1_wdata;
    logic                       tag0_we;
    logic                       tag1_we;

    // --- Data Array Signals ---
    logic [LINE_SIZE_BITS-1:0]  data0_rdata;
    logic [LINE_SIZE_BITS-1:0]  data1_rdata;
    logic [LINE_SIZE_BITS-1:0]  data0_wdata;
    logic [LINE_SIZE_BITS-1:0]  data1_wdata;
    logic                       data0_we;
    logic                       data1_we;

    // --- Comparator Signals ---
    logic                       valid0;
    logic                       valid1;
    logic [TAG_BITS-1:0]        tag0;
    logic [TAG_BITS-1:0]        tag1;
    logic                       tag0_match;
    logic                       tag1_match;

    // --- LRU Signals ---
    logic                       lru_way_q;

    // --- Data Mux Signals ---
    logic [LINE_SIZE_BITS-1:0]  data_raw;
    logic [2:0]                 word_offset;   // OFFSET_BITS-3 (word select)

    // =========================================================================
    // Address Decode
    // =========================================================================
    assign req_tag    = req_addr_i[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];
    assign req_index  = req_addr_i[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    assign req_offset = req_addr_i[OFFSET_BITS-1 : 0];

    assign refill_tag    = refill_addr_i[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];
    assign refill_index  = refill_addr_i[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    assign refill_offset = refill_addr_i[OFFSET_BITS-1 : 0];

    // =========================================================================
    // Tag Arrays (2 Ways) — via meds_s1_sram
    // =========================================================================
    // TODO: Instantiate meds_s1_sram for tag0 and tag1

    // =========================================================================
    // Data Arrays (2 Ways) — via meds_s1_sram
    // =========================================================================
    // TODO: Instantiate meds_s1_sram for data0 and data1

    // =========================================================================
    // Comparator / Hit Detection
    // =========================================================================
    assign valid0 = tag0_rdata[TAG_BITS];
    assign valid1 = tag1_rdata[TAG_BITS];
    assign tag0   = tag0_rdata[TAG_BITS-1:0];
    assign tag1   = tag1_rdata[TAG_BITS-1:0];

    assign tag0_match = valid0 && (tag0 == req_tag);
    assign tag1_match = valid1 && (tag1 == req_tag);

    assign hit_o     = tag0_match || tag1_match;
    assign hit_way_o = {tag1_match, tag0_match};

    // =========================================================================
    // LRU Logic
    // =========================================================================
    // TODO: Implement LRU flip-flop update on hit

    assign lru_way_o = lru_way_q;

    // =========================================================================
    // Refill Write Control
    // =========================================================================
    assign tag0_we    = refill_we_i && !refill_way_sel_i;
    assign tag1_we    = refill_we_i &&  refill_way_sel_i;
    assign data0_we   = refill_we_i && !refill_way_sel_i;
    assign data1_we   = refill_we_i &&  refill_way_sel_i;

    assign tag0_wdata = {1'b1, refill_tag};
    assign tag1_wdata = {1'b1, refill_tag};
    assign data0_wdata = refill_data_i;
    assign data1_wdata = refill_data_i;

    // =========================================================================
    // Data Mux
    // =========================================================================
    assign data_raw    = tag0_match ? data0_rdata : data1_rdata;
    assign word_offset = req_offset[OFFSET_BITS-1:2];   // 4-byte word select
    assign rsp_data_o  = data_raw[word_offset*32 +: 32];

endmodule