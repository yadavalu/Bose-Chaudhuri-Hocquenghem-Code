# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import random

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    reset(dut)

    dut._log.info("Test project behavior")

    await test_encode(dut)

async def reset(dut):
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

async def test_encode(dut):
    reset(dut)

    msg = random.randint(0, 2 ** 7 - 1)

    dut._log.info(f"Encoding message: {msg:07b}")

    dut.ui_in.value = msg << 1 + 1  # Set encode_enable

    await ClockCycles(dut.clk, 1)

    msg_out = dut.uo_out.value.to_unsigned() >> 1
    parity_out = dut.uio_out.value.to_unsigned()

    dut._log.info(f"Encoded output: {msg_out:07b}, Parity: {parity_out:08b}")
