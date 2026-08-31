<h1 align="center">meds_sram_wrapper</h1>

<p align="center">
  <b>Maktab-e-Digital Systems</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SystemVerilog-blue?style=flat-square&logo=verilog" alt="SystemVerilog">
  <img src="https://img.shields.io/badge/RISC_V-darkblue?style=flat-square&logo=riscv" alt="RISC-V">
</p>

---

**SRAM Wrapper — Memory Abstraction Layer for MEDS-S1**

| **Module** | `meds_sram_wrapper` |
| :--- | :--- |
| **Project** | MEDS-S1 R-03 |
| **Author** | Muhammad Usman |
| **Version** | 1.0 |
| **Status** | ✅ Verified |

---

## 📋 Overview

A parameterized memory wrapper providing a unified interface for all memory arrays in the MEDS-S1 SoC. Supports simulation, FPGA, and ASIC implementations through a single abstraction layer.

> All memory arrays must instantiate this wrapper. No direct memory in core RTL. (NFR-5)

---

## 🔌 Interface

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DW` | 64 | Data width |
| `DEPTH` | 1024 | Number of entries |
| `IMPL` | 0 | 0=Behavioural, 1=BRAM, 2=ASIC |

### Ports

| Port | Direction | Description |
| :--- | :--- | :--- |
| `clk_i` | Input | Clock |
| `rst_ni` | Input | Active-low async reset |
| `req_i` | Input | Request enable |
| `we_i` | Input | Write enable |
| `addr_i` | Input | Address |
| `be_i` | Input | Byte enable mask |
| `wdata_i` | Input | Write data |
| `rdata_o` | Output | Read data (1-cycle latency) |

---

## ⚙️ Operation

- **Write:** `req_i=1`, `we_i=1` → writes `wdata_i` to `addr_i`; only bytes with `be_i[i]=1` updated
- **Read:** `req_i=1`, `we_i=0` → `rdata_o` available next cycle
- **Reset:** `rst_ni=0` → clears `rdata_reg`; memory contents preserved

---

## 🧪 Verification

| Test | Description |
| :--- | :--- |
| 1 | Full word write/read |
| 2 | Lower half byte-mask |
| 3 | Upper half byte-mask |
| 4 | Single byte write |
| 5 | Cross-talk check |
| 6 | Address boundaries |
| 7 | 20 random tests |

**Status:** All tests passed 

---

## 🚀 Quick Usage

```systemverilog
meds_sram_wrapper #(.DW(64), .DEPTH(1024), .IMPL(0)) u_sram (
    .clk_i(clk), .rst_ni(rst_n), .req_i(req), .we_i(we),
    .addr_i(addr), .be_i(be), .wdata_i(wdata), .rdata_o(rdata)
);
```

---

## 📁 Files

- `meds_sram_wrapper.sv` — RTL
- `tb_meds_sram_wrapper.sv` — Testbench

---

## 🔗 References

- MEDS-S1 Spec §17 | INTERFACES.md §8 | NFR-5

---

**✅ Verified — All tests passing**
