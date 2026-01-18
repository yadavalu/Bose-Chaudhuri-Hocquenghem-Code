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

  // Wires for internal signals
  wire mode_encode;
  assign mode_encode = ui_in[7]; 
  wire [7:0] encoder_parity;
  wire error_detected;

  wire [14:0] received_poly;
  assign received_poly = {ui_in[6:0], uio_in[7:0]};

  wire [3:0] S1, S3;
  wire [11:0] error_locator;
  wire [3:0] error_pos_1, error_pos_2;

  wire [7:0] corrected_message;
  
  // TODO add enable pins to modules that do not need to be run
  gf16_bch_encoder encoder_inst (
    .message(ui_in[6:0]),
    .parity (encoder_parity)
  );

  // Error Finder is also always running in the background
  gf16_bch_find_error error_finder_inst (
    .received_poly(received_poly),
    .error_detected(error_detected) 
  );

  bch_syndrome_calculator syndrome_calc_inst (
    .received_poly(received_poly),
    .S1(S1),
    .S3(S3)
  );

  bch_error_locator error_locator_inst (
    .S1(S1),
    .S3(S3),
    .error_locator(error_locator)
  );

  bch_chien_search_roots chien_search_inst (
    .error_locator(error_locator),
    .error_pos_1(error_pos_1),
    .error_pos_2(error_pos_2)
  );

  assign corrected_message = received_poly[14:8] ^ 
                             ((error_pos_1 >= 8) ? (7'd1 << (error_pos_1 - 8)) : 7'b0) ^  // due to bit arrangement
                             ((error_pos_2 >= 8) ? (7'd1 << (error_pos_2 - 8)) : 7'b0);

  assign uio_oe  = mode_encode ? 8'b11111111   : 8'b0;
  assign uio_out = mode_encode ? encoder_parity : 8'b0;

  assign uo_out[6:0] = mode_encode ? ui_in[6:0] : (error_detected ? corrected_message : ui_in[6:0]); 
  assign uo_out[7]   = 1'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule


module gf16_bch_encoder (
    input  wire [6:0] message,
    output wire [7:0] parity
);

  localparam [8:0] GEN_MASK = 9'b111010001;
  wire [14:0] full_remainder; 

  gf16_divider divider_inst (
      .dividend({message, 8'b0}), 
      .divisor(GEN_MASK),
      .remainder(full_remainder) 
  );

  assign parity = full_remainder[7:0]; 

endmodule

module gf16_bch_find_error (
    input wire [14:0] received_poly,
    output wire error_detected 
);

    localparam [8:0] GEN_MASK = 9'b111010001; 
    
    wire [14:0]  final_remainder;

    gf16_divider divider_inst (
        .dividend(received_poly),
        .divisor(GEN_MASK),
        .remainder(final_remainder)
        //.quotient()
    );

    // Check if remainder is non-zero
    assign error_detected = (final_remainder[7:0] != 8'b0);

endmodule

module bch_syndrome_calculator (
    input wire [14:0] received_poly,
    output wire [3:0] S1,
    output wire [3:0] S3
);

  function [3:0] alpha_power;
    input [3:0] power;
    begin
      case (power)
        4'd0:  alpha_power = 4'd1;
        4'd1:  alpha_power = 4'd2;
        4'd2:  alpha_power = 4'd4;
        4'd3:  alpha_power = 4'd8;
        4'd4:  alpha_power = 4'd3;
        4'd5:  alpha_power = 4'd6;
        4'd6:  alpha_power = 4'd12;
        4'd7:  alpha_power = 4'd11;
        4'd8:  alpha_power = 4'd5;
        4'd9:  alpha_power = 4'd10;
        4'd10: alpha_power = 4'd7;
        4'd11: alpha_power = 4'd14;
        4'd12: alpha_power = 4'd15;
        4'd13: alpha_power = 4'd13;
        4'd14: alpha_power = 4'd9;
        default: alpha_power = 4'd0;
      endcase
    end
  endfunction

  reg [3:0] s1_reg;
  reg [3:0] s3_reg;
  integer i;

  always @(*) begin 
    s1_reg = 4'd0;
    s3_reg = 4'd0;

    for (i = 0; i < 15; i = i + 1) begin
      if (received_poly[i]) begin
        s1_reg = s1_reg ^ alpha_power(i);
        s3_reg = s3_reg ^ alpha_power((3 * i) % 15);
      end
    end
  end

  assign S1 = s1_reg;
  assign S3 = s3_reg;

endmodule

module bch_error_locator (
  input wire [3:0] S1,
  input wire [3:0] S3,
  output wire [11:0] error_locator
);

  function [3:0] alpha_power;
    input [3:0] power;
    begin
      case (power)
        4'd0:  alpha_power = 4'd1;
        4'd1:  alpha_power = 4'd2;
        4'd2:  alpha_power = 4'd4;
        4'd3:  alpha_power = 4'd8;
        4'd4:  alpha_power = 4'd3;
        4'd5:  alpha_power = 4'd6;
        4'd6:  alpha_power = 4'd12;
        4'd7:  alpha_power = 4'd11;
        4'd8:  alpha_power = 4'd5;
        4'd9:  alpha_power = 4'd10;
        4'd10: alpha_power = 4'd7;
        4'd11: alpha_power = 4'd14;
        4'd12: alpha_power = 4'd15;
        4'd13: alpha_power = 4'd13;
        4'd14: alpha_power = 4'd9;
        default: alpha_power = 4'd0;
      endcase
    end
  endfunction

  function [3:0] value_to_power;
    input [3:0] value;
    begin
      case (value)
        4'd1:  value_to_power = 4'd0;
        4'd2:  value_to_power = 4'd1;
        4'd4:  value_to_power = 4'd2;
        4'd8:  value_to_power = 4'd3;
        4'd3:  value_to_power = 4'd4;
        4'd6:  value_to_power = 4'd5;
        4'd12: value_to_power = 4'd6;
        4'd11: value_to_power = 4'd7;
        4'd5:  value_to_power = 4'd8;
        4'd10: value_to_power = 4'd9;
        4'd7:  value_to_power = 4'd10;
        4'd14: value_to_power = 4'd11;
        4'd15: value_to_power = 4'd12;
        4'd13: value_to_power = 4'd13;
        4'd9:  value_to_power = 4'd14;
        default: value_to_power = 4'd0; // Placeholder for error handling
      endcase
    end
  endfunction

  reg [3:0] sigma_1, sigma_2;
  wire [3:0] s1_pow, s1_inv_pow, numerator;

  // Galois Field arithmetic:
  // + = ^
  // * = +
  // ** = *

  assign s1_pow = value_to_power(S1);
  assign s1_inv_pow = (15 - s1_pow) % 15;  // GF(16) inverse
  // only calculate numerator to handle div bz 0
  assign numerator = S3 ^ alpha_power((s1_pow * 8'd3) % 15);  // 8'd3 to avoid truncation and force wider bit width

  always @(*) begin
    sigma_1 = S1;
    
    if (numerator == 0 || S1 == 0) begin  // Avoid searching for zero in value to power 
      sigma_2 = 4'b0;
    end else begin
      sigma_2 = alpha_power((value_to_power(numerator) + s1_inv_pow) % 15);
    end

  end

  // L(x) = sigma_2 * x^2 + sigma_1 * x + 1
  assign error_locator = {sigma_2, sigma_1, 4'b1};

endmodule

module bch_chien_search_roots (
  input wire [11:0] error_locator,
  output wire [3:0] error_pos_1,
  output wire [3:0] error_pos_2
);

  function [3:0] alpha_power;
    input [3:0] power;
    begin
      case (power)
        4'd0:  alpha_power = 4'd1;
        4'd1:  alpha_power = 4'd2;
        4'd2:  alpha_power = 4'd4;
        4'd3:  alpha_power = 4'd8;
        4'd4:  alpha_power = 4'd3;
        4'd5:  alpha_power = 4'd6;
        4'd6:  alpha_power = 4'd12;
        4'd7:  alpha_power = 4'd11;
        4'd8:  alpha_power = 4'd5;
        4'd9:  alpha_power = 4'd10;
        4'd10: alpha_power = 4'd7;
        4'd11: alpha_power = 4'd14;
        4'd12: alpha_power = 4'd15;
        4'd13: alpha_power = 4'd13;
        4'd14: alpha_power = 4'd9;
        default: alpha_power = 4'd0;
      endcase
    end
  endfunction

  function [3:0] value_to_power;
    input [3:0] value;
    begin
      case (value)
        4'd1:  value_to_power = 4'd0;
        4'd2:  value_to_power = 4'd1;
        4'd4:  value_to_power = 4'd2;
        4'd8:  value_to_power = 4'd3;
        4'd3:  value_to_power = 4'd4;
        4'd6:  value_to_power = 4'd5;
        4'd12: value_to_power = 4'd6;
        4'd11: value_to_power = 4'd7;
        4'd5:  value_to_power = 4'd8;
        4'd10: value_to_power = 4'd9;
        4'd7:  value_to_power = 4'd10;
        4'd14: value_to_power = 4'd11;
        4'd15: value_to_power = 4'd12;
        4'd13: value_to_power = 4'd13;
        4'd9:  value_to_power = 4'd14;
        default: value_to_power = 4'd0; // Placeholder for error handling
      endcase
    end
  endfunction

  wire [3:0] sigma_2 = error_locator[11:8];
  wire [3:0] sigma_1 = error_locator[7:4];
  wire [3:0] sigma_0 = error_locator[3:0]; // 4'd1

  integer i;
  reg [3:0] pos1_reg;
  reg [3:0] pos2_reg;
  reg pos1_found;
  reg [3:0] term1_val, term2_val;
  reg [3:0] eval;

  always @(*) begin 
    pos1_reg = 4'b0;
    pos2_reg = 4'b0;
    pos1_found = 1'b0;
    term1_val = 4'b0;
    term2_val = 4'b0;
    eval = 4'b0;

    for (i = 0; i <= 14; i = i + 1) begin 
      if (sigma_1 == 4'd0) term1_val = 4'd0;
      else term1_val = alpha_power((value_to_power(sigma_1) + 15 - i) % 15);

      if (sigma_2 == 4'd0) term2_val = 4'd0;
      else term2_val = alpha_power((value_to_power(sigma_2) + 8'd2 * (15 - i)) % 15);  // 8'd2 to avoid truncation

      eval = sigma_0 ^ term1_val ^ term2_val;
      
      if (eval == 4'd0) begin
        if (pos1_found) begin
          pos2_reg = i[3:0];
        end else begin
          pos1_reg = i[3:0];
          pos1_found = 1'b1;
        end
      end
    end
  end

  assign error_pos_1 = pos1_reg;
  assign error_pos_2 = pos2_reg;

endmodule

module gf16_divider (
  input [14:0] dividend,
  input [8:0] divisor,
  output [14:0] remainder
);

  reg [14:0] rem;
  integer i;

  always @(*) begin
    rem = dividend;

    for (i = 14; i >= 8; i = i - 1) begin
      if (rem[i] == 1'b1) begin
        rem[i -: 9] = rem[i -: 9] ^ divisor;  // [i -: 9] start at i select 9 bits downwards
      end
    end
  end
  assign remainder = rem;

endmodule

