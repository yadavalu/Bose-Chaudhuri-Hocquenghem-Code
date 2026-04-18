<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design is a hardware implementation of the Bose-Chaudhuri-Hocquenghem Code (15, 7). This is an error correction code that takes a corrupted 7-bit message and an 8-bit checksum and outputs the original message of 7-bits. The BCH (15, 7) code is capable of correcting up to 2 bitflips. 

The hardware uses pipelining of 3 stages:
(1) Syndrome calculation
(2) Error location
(3) Chien search

Running at 50 MHz clock frequency, there a latency of 3 clock cycles (60 ns) for the first valid output. The throughput is 1 corrupted message (payload) per clock cycle (20 ns). In other words, data can be streamed every clock cycle and the valid output is delayed by 3 clock cycles. 

## How to test

The project has 2 modes: (1) find checksum from message and (2) restore original message from corrupted message and checksum.

When the MSB of the input pins (encode_enable) is high, the lower 7-bits of the input must be the message. The output pins will be driven low and the IO pins will output the associated 8-bit checksum. 

The following illustrates a simple visualisation. Here, the capital letters represents the true message whereas the lower case letters represent the corrupted message. Moreover the letters 'A' through 'G' represent the message, while the letters 'S' through 'Z' represents the checksum. 

```
Inputs:
UI  = 1ABCDEFG

Outputs:
UIO = STUVWXYZ
UO  = 00000000
```

On the other hand, when the encode_enable pin is low, the remaining 7 input pins must be driven by the 7-bit message and the IO pin by the associated 8-bit checksum. The output pins will be the 7-bit recovered message.


```
Inputs:
UI  = 0abcdefg
UIO = stuvwxyz

Outputs:
UO  = 0ABCDEFG
```


## External hardware

No external hardware is required. LEDs may be used to visualise the inputs and outputs.
