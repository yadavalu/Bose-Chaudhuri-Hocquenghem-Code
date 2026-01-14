/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_bch_code_15_7_2 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [7:0] encoder_parity;
  wire [6:0] corrected_message; // Placeholder for future decoder
  wire mode_encode;             // 1 = Encode, 0 = Decode

  assign mode_encode = ui_in[7]; // MSB controls mode

  gf16_bch_encoder encoder_inst (
      .message(ui_in[6:0]),
      .parity (encoder_parity)
  );

  assign uio_oe = mode_encode ? 8'b11111111 : 8'b00000000;

  assign uio_out = mode_encode ? encoder_parity : 8'b00000000;

  assign uo_out[6:0] = mode_encode ? ui_in[6:0] : corrected_message;
  assign uo_out[7] = 1'b0; // Unused

  assign corrected_message = ui_in; 


  // Check if error exists
  
  // If message is corrupted

  // Calculate syndrome

  // Error locator polynomial

  // Flip bits accordingly


  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule

module gf16_bch_encoder (
    input  wire [6:0] message, // The 7-bit Message (e.g., "Go" = 0000001)
    output wire [7:0] parity   // The 8-bit Parity to append
);

  // Generator g(x) = x^8 + x^7 + x^6 + x^4 + 1
  // Binary coefficients mask
  localparam [7:0] GEN_MASK = 8'b11010001;

  integer i;
  reg [7:0] remainder;
  reg feedback;

  always @(*) begin
    remainder = 8'b00000000;

    // 2. Loop through every bit of the message (From MSB to LSB)
    //    This effectively simulates 7 clock cycles of an LFSR instantly.
    for (i = 6; i >= 0; i = i - 1) begin
      // LFSR
      feedback = message[i] ^ remainder[7];
      remainder = remainder << 1;
      if (feedback == 1'b1) begin  // If LSB of message is 1
          remainder = remainder ^ GEN_MASK;
      end
    end
  end

  // The final value left in the register is our Parity.
  assign parity = remainder;

endmodule


// GF(16) Lookup Table for Inversion
module gf16_inv (
    input  [3:0] in,
    output reg [3:0] out
);
    // Inverse mapping for Primitive Polynomial x^4 + x + 1
    always @(*) begin
        case (in)
            4'd0:  out = 4'd0;  // 0 has no inverse, return 0 or error flag
            4'd1:  out = 4'd1;
            4'd2:  out = 4'd9;
            4'd3:  out = 4'd14;
            4'd4:  out = 4'd13;
            4'd5:  out = 4'd11;
            4'd6:  out = 4'd7;
            4'd7:  out = 4'd6;
            4'd8:  out = 4'd15;
            4'd9:  out = 4'd2;
            4'd10: out = 4'd12;
            4'd11: out = 4'd5;
            4'd12: out = 4'd10;
            4'd13: out = 4'd4;
            4'd14: out = 4'd3;
            4'd15: out = 4'd8;
            default: out = 4'd0;
        endcase
    end
endmodule
