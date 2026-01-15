# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import random

# BCH(15, 7) Checksum Mapping
# Generator Polynomial: x^8 + x^7 + x^6 + x^4 + 1 (0x1D1)
bch_checksums = {
    # Decimal Message: Decimal Checksum
    0:   0,    # 0000000 -> 00000000
    1:   209,  # 0000001 -> 11010001
    2:   115,  # 0000010 -> 01110011
    3:   162,  # 0000011 -> 10100010
    4:   230,  # 0000100 -> 11100110
    5:   55,   # 0000101 -> 00110111
    6:   149,  # 0000110 -> 10010101
    10:  110,  # 0001010 -> 01101110
    16:  58,   # 0010000 -> 00111010
    20:  220,  # 0010100 -> 11011100
    22:  175,  # 0010110 -> 10101111
    32:  116,  # 0100000 -> 01110100
    64:  232,  # 1000000 -> 11101000
    127: 255   # 1111111 -> 11111111
}


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    dut._log.info("Test project behavior")

    await test_correction(dut, 22, 175)
    for i, v in bch_checksums.items():
        await test_encode(dut, i, v)
        await test_correction(dut, i, v)


async def reset(dut):
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

async def test_correction(dut, msg, checksum, err1=None, err2=None):
    if err1 is None and err2 is None:
        err1 = random.randint(0, 14)
        err2 = random_exclude(0, 14, {err1})

    await reset(dut)

    dut._log.info(f"Correcting message: {msg:07b}, Checksum: {checksum:08b}")
    msg_with_checksum = (msg << 8) | checksum
    msg_corrupted = msg_with_checksum ^ (1 << err1) ^ (1 << err2)
    dut._log.info(f"Corrupted at positions: {err1}, {err2}, Corrupted message: {msg_corrupted:015b}")
    
    # 111111100000000 = 0x7E00
    # 000000011111111 = 0x00FF
    dut.ui_in.value = (msg_corrupted & 0x7E00) >> 8  # Upper 7 bits
    dut.uio_in.value = msg_corrupted & 0x00FF        # Lower 8 bits

    await ClockCycles(dut.clk, 1)

    msg_out = dut.uo_out.value.to_unsigned()
    checksum_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Corrected message mismatch: expected {msg:07b}, got {msg_out:07b}"
    assert checksum_out == checksum, f"Corrected checksum mismatch: expected {checksum:08b}, got {checksum_out:08b}"


async def test_encode(dut, msg, checksum):
    await reset(dut)

    dut._log.info(f"Encoding message: {msg:07b}")

    dut.ui_in.value = msg + 2 ** 7  # Set encode_enable

    await ClockCycles(dut.clk, 1)

    msg_out = dut.uo_out.value.to_unsigned()
    parity_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Encoded message mismatch: expected {msg:07b}, got {msg_out:07b}"
    assert parity_out == checksum, f"Encoded parity mismatch: expected {checksum:08b}, got {parity_out:08b}"

    dut._log.info(f"Encoded output: {msg_out:07b}, Parity: {parity_out:08b}")


def random_exclude(start, end, exclude):
    choices = [i for i in range(start, end + 1) if i not in exclude]
    return random.choice(choices)

