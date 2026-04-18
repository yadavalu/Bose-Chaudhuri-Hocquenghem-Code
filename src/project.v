/*
 * Copyright (c) 2024 Aadith Yadav Govindarajan
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

  wire [14:0] received_poly_in = {ui_in[6:0], uio_in[7:0]};
  wire mode_encode_in = ui_in[7]; 
  
  wire [7:0] encoder_parity_comb;
  wire error_detected_comb;
  wire [3:0] S1_comb, S3_comb;
  wire [11:0] error_locator_comb;
  wire [3:0] error_pos_1_comb, error_pos_2_comb;

  // Pipeline registers
  reg [14:0] delay_pipe_1, delay_pipe_2, delay_pipe_3;
  
  reg mode_encode_reg1, mode_encode_reg2, mode_encode_reg3;
  
  reg [7:0] encoder_parity_reg1, encoder_parity_reg2, encoder_parity_reg3;

  reg [3:0] S1_reg, S3_reg;
  reg error_detected_reg1, error_detected_reg2, error_detected_reg3;
  reg [11:0] error_locator_reg;
  reg [3:0] error_pos_1_reg, error_pos_2_reg;
  
  // Submodules
  gf16_bch_encoder encoder_inst (
    .message(ui_in[6:0]),
    .parity (encoder_parity_comb)
  );

  gf16_bch_find_error error_finder_inst (
    .received_poly(received_poly_in),
    .error_detected(error_detected_comb) 
  );

  bch_syndrome_calculator syndrome_calc_inst (
    .received_poly(received_poly_in),
    .S1(S1_comb),
    .S3(S3_comb)
  );

  bch_error_locator error_locator_inst (
    .S1(S1_reg),
    .S3(S3_reg),
    .error_locator(error_locator_comb)
  );

  bch_chien_search_roots chien_search_inst (
    .error_locator(error_locator_reg),
    .error_pos_1(error_pos_1_comb),
    .error_pos_2(error_pos_2_comb)
  );

  // Sequential pipeline logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      delay_pipe_1 <= 15'b0; delay_pipe_2 <= 15'b0; delay_pipe_3 <= 15'b0;
      mode_encode_reg1 <= 1'b0; mode_encode_reg2 <= 1'b0; mode_encode_reg3 <= 1'b0;
      encoder_parity_reg1 <= 8'b0; encoder_parity_reg2 <= 8'b0; encoder_parity_reg3 <= 8'b0;
      error_detected_reg1 <= 1'b0; error_detected_reg2 <= 1'b0; error_detected_reg3 <= 1'b0;
      
      S1_reg <= 4'b0; S3_reg <= 4'b0;
      error_locator_reg <= 12'b0;
      error_pos_1_reg <= 4'b0; error_pos_2_reg <= 4'b0;
    end else begin
      // Pipeline syndromes & parity
      delay_pipe_1 <= received_poly_in;
      mode_encode_reg1 <= mode_encode_in;
      encoder_parity_reg1 <= encoder_parity_comb;
      error_detected_reg1 <= error_detected_comb;
      S1_reg <= S1_comb;
      S3_reg <= S3_comb;

      // Pipeline error locators
      delay_pipe_2 <= delay_pipe_1;
      mode_encode_reg2 <= mode_encode_reg1;
      encoder_parity_reg2 <= encoder_parity_reg1;
      error_detected_reg2 <= error_detected_reg1;
      error_locator_reg <= error_locator_comb;

      // Pipeline for Chien search roots
      delay_pipe_3 <= delay_pipe_2;
      mode_encode_reg3 <= mode_encode_reg2;
      encoder_parity_reg3 <= encoder_parity_reg2;
      error_detected_reg3 <= error_detected_reg2;
      error_pos_1_reg <= error_pos_1_comb;
      error_pos_2_reg <= error_pos_2_comb;
    end
  end

  // Output logic
  wire [7:0] error_mask_1 = 8'd1 << (error_pos_1_reg - 8);
  wire [7:0] error_mask_2 = 8'd1 << (error_pos_2_reg - 8);

  wire [6:0] corrected_message = delay_pipe_3[14:8] ^ 
                                 ((error_pos_1_reg >= 8) ? error_mask_1[6:0] : 7'b0) ^
                                 ((error_pos_2_reg >= 8) ? error_mask_2[6:0] : 7'b0);

  assign uio_oe  = mode_encode_reg3 ? 8'b11111111 : 8'b0;
  assign uio_out = mode_encode_reg3 ? encoder_parity_reg3 : 8'b0;

  assign uo_out[6:0] = mode_encode_reg3 ? delay_pipe_3[14:8] : (error_detected_reg3 ? corrected_message : delay_pipe_3[14:8]); 
  assign uo_out[7]   = 1'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, error_mask_1[7], error_mask_2[7], 1'b0};

endmodule


