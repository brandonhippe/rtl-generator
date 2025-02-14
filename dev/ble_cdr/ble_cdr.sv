//! This file generated by [rtl-generator](https://github.com/brandonhippe/rtl-generator.git), written by Brandon Hippe
//!
//! ## Generator Arguments
// #{(param_table)}
//!
//! |   Argument   |  Value   |
//! | ------------ | -------- |
//! |  adc_width   |    4     |
//! |   clk_freq   | 16000000 |
//! |     fsym     | 1000000  |
//! | mf_clock_rec |  False   |
//!
// #{/(param_table)}

// Included Modules:
// #{(included_modules)}
`include "packet_sniffer/packet_sniffer.sv"
`include "matched_filter/matched_filter.sv"
`include "clock_recovery/clock_recovery.sv"
`include "preamble_detect/preamble_detect.sv"
// #{/(included_modules)}


module ble_cdr #(
    parameter int SAMPLE_RATE =  /* #{(samples_per_symbol)} */ 16  /* #{/(samples_per_symbol)} */,
    parameter int DATA_WIDTH =  /* #{(adc_width)} */ 4  /* #{/(adc_width)} */,
    parameter int MAX_PACKET_LEN = 376,
    parameter int PREAMBLE_LEN = 8
) (
    input logic clk,
    input logic en,
    input logic resetn,

    input logic [DATA_WIDTH-1:0] i_bpf,
    q_bpf,

    output logic demod_symbol,
    demod_symbol_clk,

    input logic modify_sniffer_settings,
    input logic [31:0] acc_addr,
    input logic [5:0] channel,
    output logic [MAX_PACKET_LEN-PREAMBLE_LEN-1:0] packet_out,
    output logic [$clog2(MAX_PACKET_LEN)-1:0] packet_len,
    output logic packet_detected
);

  localparam int PIPELINE_STAGES = 1;

  // Matched filter stuff
  logic demod_bit;
  matched_filter #(
      .SAMPLE_RATE(SAMPLE_RATE),
      .DATA_WIDTH (DATA_WIDTH)
  ) mf (
      .clk(clk),
      .resetn(resetn),
      .en(en),

      .i_data(i_bpf),
      .q_data(q_bpf),

      .demodulated_bit(demod_bit)
  );

  logic symbol_clk;

  // #{(instantiate_clock_recovery)}
  // Preamble Detection stuff
  logic preamble_detected;
  preamble_detect #(
      .SAMPLE_RATE(SAMPLE_RATE)
  ) pd (
      .clk(clk),
      .resetn(resetn),
      .en(en),

      .data_bit(demod_bit),
      .preamble_detected(preamble_detected)
  );

  // Clock recovery stuff
  clock_recovery #(
      .SAMPLE_RATE(SAMPLE_RATE),
      .DATA_WIDTH (DATA_WIDTH)
  ) cr (
      .clk(clk),
      .resetn(resetn),
      .en(en),

      .i_data(i_bpf),
      .q_data(q_bpf),
      .preamble_detected(preamble_detected),

      .symbol_clk(symbol_clk)
  );
  // #{/(instantiate_clock_recovery)}

  always_comb begin
    demod_symbol = demod_bit;
    demod_symbol_clk = symbol_clk;
  end

  // Packet sniffer stuff
  logic [31:0] latched_acc_addr;
  logic [5:0] latched_channel;
  logic [MAX_PACKET_LEN-PREAMBLE_LEN-1:0] packet_out_reg;
  logic [$clog2(MAX_PACKET_LEN)-1:0] packet_len_reg;
  logic packet_detected_reg;

  always_ff @(posedge clk or negedge resetn) begin
    if (~resetn) begin
      latched_acc_addr <= 32'h6b7d9171;
      latched_channel <= 37;
      packet_out <= 0;
      packet_len <= 0;
      packet_detected <= 0;
    end else begin
      latched_acc_addr <= modify_sniffer_settings ? acc_addr : latched_acc_addr;
      latched_channel <= modify_sniffer_settings ? channel : latched_channel;
      packet_out <= packet_out_reg;
      packet_len <= packet_len_reg;
      packet_detected <= packet_detected_reg;
    end
  end

  packet_sniffer #(
      .PACKET_LEN_MAX(MAX_PACKET_LEN),
      .PREAMBLE_LEN  (PREAMBLE_LEN)
  ) ps (
      .symbol_clk(symbol_clk),
      .resetn(resetn),
      .en(en),

      .symbol_in(demod_bit),

      .packet_detected(packet_detected_reg),
      .packet_len(packet_len_reg),
      .packet_out(packet_out_reg),

      .acc_addr(latched_acc_addr),
      .channel (latched_channel)
  );

endmodule
