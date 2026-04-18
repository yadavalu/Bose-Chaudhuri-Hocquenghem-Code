# SPDX-FileCopyrightText: © 2026 Aadith Yadav Govindarajan
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
    7:   68,
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

    # Set the clock period to 20 ns (50 MHz)
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    dut._log.info("Test project behavior")

    for i, v in bch_checksums.items():
        await test_encode(dut, i, v)
        await test_correction_2_err(dut, i, v)
        await test_correction_1_err(dut, i, v)
        await test_correction_no_err(dut, i, v)

    await test_pipeline_throughput(dut)

async def reset(dut):
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

async def test_pipeline_throughput(dut):
    dut._log.info("Testing continuous pipeline throughput...")
    
    # stream of consecutive test messages
    messages = [1, 2, 3, 4, 5, 6, 7, 10, 16, 20, 22, 32, 64]
    expected_checksums = [bch_checksums[m] for m in messages]
    
    total_cycles = len(messages) + 3

    for i in range(total_cycles):
        if i < len(messages):
            msg = messages[i]
            dut.ui_in.value = msg + 128  # +128 sets the 7th bit (encode mode) to 1
            dut._log.info(f"Cycle {i}: Pushed Message {msg:07b} into Stage 1")
        else:
            # No more messages
            dut.ui_in.value = 0 

        await ClockCycles(dut.clk, 1)

        # Starting validation on Cycle 3
        if i >= 3:
            out_index = i - 3
            expected_msg = messages[out_index]
            expected_parity = expected_checksums[out_index]

            msg_out = dut.uo_out.value.to_unsigned()
            parity_out = dut.uio_out.value.to_unsigned()

            assert msg_out == expected_msg, f"Cycle {i}: Mismatch! Expected {expected_msg}, got {msg_out}"
            assert parity_out == expected_parity, f"Cycle {i}: Parity Mismatch! Expected {expected_parity}, got {parity_out}"
            
            dut._log.info(f"Cycle {i}: Popped Corrected Message {msg_out:07b} from Stage 3")

    dut._log.info("Successfully streamed all messages back-to-back with 1-cycle throughput")

async def test_correction_2_err(dut, msg, checksum, err1=None, err2=None):
    if err1 is None and err2 is None:
        err1 = random.randint(0, 14)
        err2 = random_exclude(0, 14, {err1})

    dut._log.info(f"Correcting message: {msg:07b}, Checksum: {checksum:08b}")
    msg_with_checksum = (msg << 8) | checksum
    msg_corrupted = msg_with_checksum ^ (1 << err1) ^ (1 << err2)
    dut._log.info(f"Corrupted at positions: {err1}, {err2}, Corrupted message: {msg_corrupted:015b}")
    
    dut.ui_in.value = (msg_corrupted & 0x7F00) >> 8  # Upper 7 bits
    dut.uio_in.value = msg_corrupted & 0x00FF        # Lower 8 bits

    await ClockCycles(dut.clk, 4)

    msg_out = dut.uo_out.value.to_unsigned()
    checksum_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Corrected message mismatch: expected {msg:07b}, got {msg_out:07b}"
    dut._log.info(f"Successfully recovered original message: {msg_out:07b}")

async def test_correction_1_err(dut, msg, checksum, err1=None):
    if err1 is None:
        err1 = random.randint(0, 14)

    dut._log.info(f"Correcting message: {msg:07b}, Checksum: {checksum:08b}")
    msg_with_checksum = (msg << 8) | checksum
    msg_corrupted = msg_with_checksum ^ (1 << err1)
    dut._log.info(f"Corrupted at positions: {err1}, Corrupted message: {msg_corrupted:015b}")
    
    dut.ui_in.value = (msg_corrupted & 0x7F00) >> 8  # Upper 7 bits
    dut.uio_in.value = msg_corrupted & 0x00FF        # Lower 8 bits

    await ClockCycles(dut.clk, 4)

    msg_out = dut.uo_out.value.to_unsigned()
    checksum_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Corrected message mismatch: expected {msg:07b}, got {msg_out:07b}"
    dut._log.info(f"Successfully recovered original message: {msg_out:07b}")

async def test_correction_no_err(dut, msg, checksum):
    dut._log.info(f"Flawless message: {msg:07b}, Checksum: {checksum:08b}")
    msg_with_checksum = (msg << 8) | checksum
    
    dut.ui_in.value = msg
    dut.uio_in.value = checksum

    await ClockCycles(dut.clk, 4)

    msg_out = dut.uo_out.value.to_unsigned()
    checksum_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Corrected message mismatch: expected {msg:07b}, got {msg_out:07b}"
    dut._log.info(f"Successfully recovered original message: {msg_out:07b}")

async def test_encode(dut, msg, checksum):
    dut._log.info(f"Encoding message: {msg:07b}")

    dut.ui_in.value = msg + 2 ** 7  # Set encode_enable

    await ClockCycles(dut.clk, 4)

    msg_out = dut.uo_out.value.to_unsigned()
    parity_out = dut.uio_out.value.to_unsigned()

    assert msg_out == msg, f"Encoded message mismatch: expected {msg:07b}, got {msg_out:07b}"
    assert parity_out == checksum, f"Encoded parity mismatch: expected {checksum:08b}, got {parity_out:08b}"
    dut._log.info(f"Encoded output: {msg_out:07b}, Parity: {parity_out:08b}")


def random_exclude(start, end, exclude):
    choices = [i for i in range(start, end + 1) if i not in exclude]
    return random.choice(choices)