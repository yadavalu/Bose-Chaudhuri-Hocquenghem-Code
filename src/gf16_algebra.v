/*
 * Copyright (c) 2026 Aadith Yadav Govindarajan
 * SPDX-License-Identifier: Apache-2.0
 */

`include "bch_lookup.vh"

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

  wire _unused = &{ full_remainder[14:8], 1'b0 };

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

  wire _unused = &{ final_remainder[14:8], 1'b0 };

endmodule

module bch_syndrome_calculator (
  input wire [14:0] received_poly,
  output wire [3:0] S1,
  output wire [3:0] S3
);

  reg [3:0] s1_reg;
  reg [3:0] s3_reg;
  reg [7:0] overflow;
  integer i;

  always @(*) begin 
    s1_reg = 4'd0;
    s3_reg = 4'd0;
    overflow = 8'd0;

    for (i = 0; i < 15; i = i + 1) begin
      if (received_poly[i]) begin
        s1_reg = s1_reg ^ alpha_power(i[3:0]);
        overflow = (8'd3 * i[7:0]) % 8'd15;
        s3_reg = s3_reg ^ alpha_power(overflow[3:0]);
      end
    end
  end

  assign S1 = s1_reg;
  assign S3 = s3_reg;

  wire _unused = &{ overflow[7:4], 1'b0 };

endmodule

module bch_error_locator (
  input wire [3:0] S1,
  input wire [3:0] S3,
  output wire [11:0] error_locator
);

  reg [3:0] sigma_1, sigma_2;
  wire [3:0] s1_pow, s1_inv_pow, numerator;

  // Galois Field arithmetic:
  // + = ^
  // * = +
  // ** = *

  assign s1_pow = value_to_power(S1);
  assign s1_inv_pow = (15 - s1_pow) % 15;  // GF(16) inverse
  wire [7:0] exponent;
  assign exponent = (s1_pow * 8'd3) % 15;
  // only calculate numerator to handle div bz 0
  assign numerator = S3 ^ alpha_power(exponent[3:0]);  // 8'd3 to avoid truncation and force wider bit width

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

  wire _unused = &{ exponent[7:4], 1'b0 };

endmodule

module bch_chien_search_roots (
  input wire [11:0] error_locator,
  output wire [3:0] error_pos_1,
  output wire [3:0] error_pos_2
);

  wire [3:0] sigma_2 = error_locator[11:8];
  wire [3:0] sigma_1 = error_locator[7:4];
  wire [3:0] sigma_0 = error_locator[3:0]; // 4'd1

  integer i;
  reg [3:0] pos1_reg;
  reg [3:0] pos2_reg;
  reg pos1_found;
  reg [3:0] term1_val, term2_val;
  reg [7:0] term1_help1, term2_help1, term1_help2, term2_help2;
  reg [3:0] eval;

  always @(*) begin 
    pos1_reg = 4'b0;
    pos2_reg = 4'b0;
    pos1_found = 1'b0;
    term1_val = 4'b0;
    term2_val = 4'b0;
    term1_help1 = 8'b0;
    term1_help2 = 8'b0;
    term2_help1 = 8'b0;
    term2_help2 = 8'b0;
    eval = 4'b0;

    for (i = 0; i <= 14; i = i + 1) begin 
      if (sigma_1 == 4'd0) begin
        term1_val = 4'd0;
      end else begin
        term1_help1 = {4'b0, value_to_power(sigma_1)};
        term1_help2 = (term1_help1 + 8'd15 - i[7:0]) % 8'd15;
        term1_val = alpha_power(term1_help2[3:0]);
      end

      if (sigma_2 == 4'd0) begin
        term2_val = 4'd0;
      end else begin
        term2_help1 = {4'b0, value_to_power(sigma_2)};
        term2_help2 = (term2_help1 + 8'd2 * (8'd15 - i[7:0])) % 8'd15;
        term2_val = alpha_power(term2_help2[3:0]);
      end

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

  wire _unused = &{ term1_help2[7:4], term2_help2[7:4], 1'b0 };

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

