//====================== IF ======================
interface noc_if;
  logic [1:0] src_x, src_y, dest_x, dest_y, payload;
  logic [1:0] outputs [0:3][0:3];
endinterface

//====================== UVM PKG =================
package noc_pkg;
  timeunit 1ns; timeprecision 1ps;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //--------------- Transaction ------------------
  class noc_transaction extends uvm_sequence_item;
    rand bit [1:0] src_x, src_y, dest_x, dest_y, payload;
    logic [1:0] outputs [0:3][0:3];

    `uvm_object_utils_begin(noc_transaction)
      `uvm_field_int(src_x, UVM_ALL_ON)
      `uvm_field_int(src_y, UVM_ALL_ON)
      `uvm_field_int(dest_x, UVM_ALL_ON)
      `uvm_field_int(dest_y, UVM_ALL_ON)
      `uvm_field_int(payload, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="noc_transaction"); super.new(name); endfunction
  endclass

  //--------------- Driver -----------------------
  class noc_driver extends uvm_driver#(noc_transaction);
    `uvm_component_utils(noc_driver)
    virtual noc_if vif;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual noc_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","Could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        `uvm_info("DRIVER",$sformatf("Drive dest (%0d,%0d)",req.dest_x,req.dest_y),UVM_HIGH)
        vif.src_x   <= req.src_x;
        vif.src_y   <= req.src_y;
        vif.dest_x  <= req.dest_x;
        vif.dest_y  <= req.dest_y;
        vif.payload <= req.payload;
        #10ns; // allow combinational to settle
        seq_item_port.item_done();
      end
    endtask
  endclass

  //--------------- Monitor ----------------------
 class noc_monitor extends uvm_monitor;
  `uvm_component_utils(noc_monitor)
  virtual noc_if vif;
  uvm_analysis_port#(noc_transaction) ap;

  function new(string n, uvm_component p); 
    super.new(n,p); 
    ap = new("ap", this); 
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual noc_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","Could not get virtual interface")
  endfunction

  // declare once at block start; assign inside the loop
  task run_phase(uvm_phase phase);
    noc_transaction item;  // <— moved here
    forever @(vif.src_x or vif.src_y or vif.dest_x or vif.dest_y or vif.payload) begin
      #1ps;
      item = noc_transaction::type_id::create("item", this);
      item.src_x   = vif.src_x;
      item.src_y   = vif.src_y;
      item.dest_x  = vif.dest_x;
      item.dest_y  = vif.dest_y;
      item.payload = vif.payload;
      item.outputs = vif.outputs;
      ap.write(item);
    end
  endtask
endclass

  //--------------- Agent ------------------------
  class noc_agent extends uvm_agent;
    `uvm_component_utils(noc_agent)
    noc_driver driver;
    noc_monitor monitor;
    uvm_sequencer#(noc_transaction) sequencer;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      driver    = noc_driver   ::type_id::create("driver", this);
      monitor   = noc_monitor  ::type_id::create("monitor", this);
      sequencer = uvm_sequencer#(noc_transaction)::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  //--------------- Scoreboard -------------------
  class noc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(noc_scoreboard)
    uvm_analysis_imp#(noc_transaction, noc_scoreboard) analysis_export;

    function new(string n, uvm_component p); super.new(n,p); analysis_export=new("analysis_export",this); endfunction

    function void write(noc_transaction item);
      bit [1:0] x = item.dest_x, y = item.dest_y;
      bit [1:0] expected, actual;
      bit error = 0;

      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          actual   = item.outputs[i][j];
          expected = ((i==x) && (j==y)) ? item.payload : 2'b00;
          if (actual !== expected) begin
            `uvm_error("SCOREBOARD",
              $sformatf("Mismatch at [%0d][%0d]: exp=%b got=%b", i, j, expected, actual))
            error = 1;
          end
        end
      end

      if (!error)
        `uvm_info("SCOREBOARD", $sformatf("Packet to (%0d,%0d) PASS", x, y), UVM_LOW)
    endfunction
  endclass

  //--------------- Env --------------------------
  class noc_env extends uvm_env;
    `uvm_component_utils(noc_env)
    noc_agent agent;
    noc_scoreboard scoreboard;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent      = noc_agent     ::type_id::create("agent", this);
      scoreboard = noc_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agent.monitor.ap.connect(scoreboard.analysis_export);
    endfunction
  endclass

  //--------------- Sequence ---------------------
  class noc_sequence extends uvm_sequence#(noc_transaction);
    `uvm_object_utils(noc_sequence)
    function new(string name="noc_sequence"); super.new(name); endfunction

    task body();
      repeat (20) begin
        noc_transaction req = noc_transaction::type_id::create("req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("SEQ","Randomize failed")
        finish_item(req);
      end
    endtask
  endclass

  //--------------- Test -------------------------
  class noc_test extends uvm_test;
    `uvm_component_utils(noc_test)
    noc_env env;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = noc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      noc_sequence seq = noc_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.sequencer);
      #100ns;
      phase.drop_objection(this);
    endtask
  endclass
endpackage : noc_pkg

//====================== TOP ======================
`timescale 1ns/1ps
module top;
  timeunit 1ns; timeprecision 1ps;

  import uvm_pkg::*;  `include "uvm_macros.svh"
  import noc_pkg::*;

  noc_if vif();

  // Initialize IF to avoid Xs on first sample
  initial begin
    vif.src_x = 0; vif.src_y = 0; vif.dest_x = 0; vif.dest_y = 0; vif.payload = 0;
    foreach (vif.outputs[i,j]) vif.outputs[i][j] = 2'b00;
  end

  // DUT instance comes from design.sv
  noc_4x4 dut (
    .src_x(vif.src_x), .src_y(vif.src_y),
    .dest_x(vif.dest_x), .dest_y(vif.dest_y),
    .payload(vif.payload),
    .out00(vif.outputs[0][0]), .out01(vif.outputs[0][1]),
    .out02(vif.outputs[0][2]), .out03(vif.outputs[0][3]),
    .out10(vif.outputs[1][0]), .out11(vif.outputs[1][1]),
    .out12(vif.outputs[1][2]), .out13(vif.outputs[1][3]),
    .out20(vif.outputs[2][0]), .out21(vif.outputs[2][1]),
    .out22(vif.outputs[2][2]), .out23(vif.outputs[2][3]),
    .out30(vif.outputs[3][0]), .out31(vif.outputs[3][1]),
    .out32(vif.outputs[3][2]), .out33(vif.outputs[3][3])
  );

  initial begin
    uvm_config_db#(virtual noc_if)::set(null, "uvm_test_top.*", "vif", vif);
    run_test("noc_test");
  end
endmodule
