# 4×4 NoC Design with UVM Testbench

This repository contains a very simple 4×4 Network-on-Chip (NoC) style router written in SystemVerilog (`design.sv`) together with a UVM-based verification environment (`testbench.sv`).

The main purpose of this project is **not** to design NoC, but to serve as a clean, minimal and a **good UVM testbench** for the NoC.

## Overview

- **Design (`design.sv`)**
  - Module: `noc_4x4`
  - Inputs: `src_x`, `src_y`, `dest_x`, `dest_y`, `payload` (all 2-bit).
  - Outputs: 4×4 grid of 2-bit outputs (`out00` … `out33`).
  - Behavior: For each `(dest_x, dest_y)` pair, exactly one output is driven with `payload`; all others are `2'b00`. The design is purely combinational and intentionally simple.

- **Testbench (`testbench.sv`)**
  - Defines a `noc_if` interface to connect DUT, UVM components, and assertions.
  - UVM components are packaged in `noc_pkg`:
    - `noc_transaction`, `noc_sequencer`, `noc_driver`, `noc_monitor`
    - `noc_agent`, `noc_env`, `noc_scoreboard`, `noc_coverage`
    - Sequences for both random and directed testing.
  - `noc_asserts` module uses SystemVerilog Assertions to check that only the selected output matches the payload.
  - Top-level `top` module:
    - Instantiates the DUT and interface.
    - Binds assertions.
    - Starts the UVM test (`noc_test`).
    - Dumps `waves.vcd` for waveform viewing.

## Goal of the Project

- Demonstrate how to:
  - Write UVM testbench using a simple clone of 4x4 NoC.
  - Build a complete UVM environment (driver, monitor, agent, env, scoreboard, coverage, assertions).
  - Add assertions and coverage to strengthen verification.
- Serve as a **learning/reference repository** for students or beginners who want to understand UVM using a compact example.

## Running the Simulation (Example)

You need a SystemVerilog simulator with UVM support (e.g., Questa, VCS, Xcelium).

