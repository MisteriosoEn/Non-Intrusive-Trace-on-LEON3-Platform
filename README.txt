# UCInspire_Project

This repository will contain several versions of LEON3 microprocessor platform.
The platform is realized on Digilent Nexys-Video FPGA board using design tool Xilinx Vivado 2017.2, Vivado 2017.3 and Vivado 2018.2
You may need the necessary to gain access to the Vivado tools.

Some code were supported in Vivado 2017.2 but not supported in the later versions of Vivado (the design tool will report a syntax error), but it just needs some simple changes to adapt to them.

LEON3 microprocessor has a original internal instruction trace interface which located inside the LEON3 CPU. The original trace interface is connected to the instruction trace buffer which is also inside the LEON3 CPU.
The instruction trace buffer is a circular buffer, recording the time-tag, address, result, and other information of every executed instructions. However, these records are stored in this buffer and then are sent to DSU(Debug Support Unit), and cannot be directly sent out for instant error detecting.
As a result, the instruction traces are "buffered", causing a significant time delay.
To realize on-situ trace, in this modified LEON3 Platform, there is a new instruction trace interface. A custome hardware module(Pcore) connected to this new trace interface. The Pcore interfaces with AMBA APB bus. The trace information is directly sent to this Pcore.There is a AHB/APB bridge.

Folder Docs contains some user manuals that related to this project. You may find them helpful when you are dveloping the LEON3 Platform.




This repository will be finished within several days.