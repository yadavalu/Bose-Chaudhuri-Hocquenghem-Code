/*
 * Copyright (c) 2026 Aadith Yadav Govindarajan
 * SPDX-License-Identifier: Apache-2.0
 */

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
            default: value_to_power = 4'd0; 
        endcase
    end
endfunction
