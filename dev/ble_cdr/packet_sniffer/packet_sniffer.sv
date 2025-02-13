//! This file generated by [rtl-generator](https://github.com/brandonhippe/rtl-generator.git), written by Brandon Hippe
//!
//! ## Generator Arguments
// #{(param_table)}
//! 
//! | Argument | Value |
//! | :------: | :---: |
//!  
// #{/(param_table)}

// Included Modules:
// #{/(included_modules)}
// INCLUDED MODULES GO HERE
// #{/(included_modules)}


module packet_sniffer #(
    parameter PACKET_LEN_MAX = 376,
    parameter PREAMBLE_LEN = 8,
    parameter ACC_ADDR_LEN = 32,
    parameter DEWHITEN_POLY = 7'h04,
    parameter CRC_POLY = 24'h00065A,
    parameter CRC_INIT = 24'h555555
) (
    input logic symbol_clk,
    resetn,
    en,
    input logic symbol_in,

    output logic packet_detected,
    output logic [PACKET_LEN_MAX-PREAMBLE_LEN-1:0] packet_out,
    output logic [$clog2(PACKET_LEN_MAX)-1:0] packet_len,

    input logic [ACC_ADDR_LEN-1:0] acc_addr,
    input logic [5:0] channel
);

  localparam BUFFER_LEN = PACKET_LEN_MAX - PREAMBLE_LEN;
  logic [BUFFER_LEN-1:0] rx_buffer;
  logic state, nextState;  // 0: waiting for access address, 1: receiving pdu
  logic [$clog2(PACKET_LEN_MAX)-1:0] bit_counter;
  logic acc_addr_matched, packet_finished;
  logic dewhitened;
  logic crc_pass;

  // Packet detection and receive buffer
  initial begin
    rx_buffer = 0;
  end

  always_ff @(posedge symbol_clk or negedge resetn) begin
    if (~resetn) begin
      rx_buffer <= 0;
    end else begin
      rx_buffer <= {rx_buffer[BUFFER_LEN-2:0], state ? dewhitened : symbol_in};
    end
  end

  always_ff @(posedge packet_detected or negedge resetn) begin
    if (~resetn) begin
      packet_out <= 0;
      packet_len <= 0;
    end else begin
      packet_out <= rx_buffer;
      packet_len <= bit_counter + PREAMBLE_LEN + ACC_ADDR_LEN;
    end
  end

  // Control State Machine

  initial begin
    state = 1'b0;
    bit_counter = 0;
  end

  always_comb begin
    packet_detected = crc_pass & (bit_counter[2:0] == 3'b0);
    packet_finished = bit_counter == PACKET_LEN_MAX - PREAMBLE_LEN - ACC_ADDR_LEN;

    case (state)
      1'b0: begin
        nextState = acc_addr_matched & en;
      end
      1'b1: begin
        nextState = (~(packet_detected | packet_finished) & en);
      end
    endcase
  end

`ifndef MATCHED_FILTER_CLOCK_RECOVERY
  always_ff @(negedge symbol_clk or negedge resetn) begin
    if (~resetn) begin
      state <= 1'b0;
    end else if (en) begin
      state <= nextState;
    end
  end
`else
  always_ff @(posedge symbol_clk or negedge resetn) begin
    if (~resetn) begin
      state <= 1'b0;
    end else if (en) begin
      state <= nextState;
    end
  end
`endif

  always_ff @(posedge symbol_clk or negedge resetn) begin
    if (~resetn) begin
      bit_counter <= 0;
    end else if (en) begin
      if (state) begin
        bit_counter <= bit_counter + 1;
      end else begin
        bit_counter <= 0;
      end
    end
  end

  // Matching access address
  assign acc_addr_matched = (rx_buffer[ACC_ADDR_LEN-1:0] == acc_addr);

  // Dewhitening
  dewhiten dw (
      .clk(symbol_clk),
      .rst(acc_addr_matched | ~state | ~resetn),
      .en(state),
      .symbol_in(symbol_in),
      .symbol_out(dewhitened),
      .dewhiten_init(channel),
      .dewhiten_poly(DEWHITEN_POLY)
  );

  // CRC
  crc #(
      .CRC_LEN(24)
  ) chk (
      .clk(symbol_clk),
      .rst(acc_addr_matched | ~state | ~resetn),
      .en(state),
      .dewhitened(dewhitened),
      .crc_pass(crc_pass),
      .crc_init(CRC_INIT),
      .crc_poly(CRC_POLY)
  );

endmodule


module dewhiten (
    input  logic clk,
    rst,
    en,
    input  logic symbol_in,
    output logic symbol_out,

    input logic [5:0] dewhiten_init,
    input logic [6:0] dewhiten_poly
);

  localparam DEWHITEN_LEN = 7;
  logic [DEWHITEN_LEN-1:0] dewhiten_lfsr, lfsr_next;

  always_comb begin
    symbol_out = symbol_in ^ dewhiten_lfsr[0];
    lfsr_next = {dewhiten_lfsr[0], dewhiten_lfsr[DEWHITEN_LEN-1:1]} ^ ({DEWHITEN_LEN{dewhiten_lfsr[0]}} & dewhiten_poly);
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      dewhiten_lfsr <= {1'b1, dewhiten_init};
    end else begin
      dewhiten_lfsr <= (en) ? lfsr_next : dewhiten_lfsr;
    end
  end

endmodule


module crc #(
    parameter CRC_LEN = 24
) (
    input logic clk,
    rst,
    en,
    input logic dewhitened,

    output logic crc_pass,

    input logic [CRC_LEN-1:0] crc_init,
    crc_poly
);

  logic [CRC_LEN-1:0] crc_lfsr, lfsr_next;
  logic msb;

  always_comb begin
    msb = crc_lfsr[CRC_LEN-1] ^ dewhitened;
    lfsr_next = {crc_lfsr[CRC_LEN-2:0], msb} ^ ({CRC_LEN{msb}} & crc_poly);
    crc_pass = crc_lfsr == 0;
  end

  always_ff @(negedge clk or posedge rst) begin
    if (rst) begin
      crc_lfsr <= crc_init;
    end else begin
      crc_lfsr <= (en) ? lfsr_next : crc_lfsr;
    end
  end

endmodule
