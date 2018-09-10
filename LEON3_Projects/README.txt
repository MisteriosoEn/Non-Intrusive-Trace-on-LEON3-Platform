LEON3:
This is the LEON3 Vivado project without any configuration. 
It is directly created by the source code and scripts provided by Cobham Gaisler.


LEON_with_traceinterface:
leon3 design that has a trace interface and a pcore to capture one trace information
the pcore is in a standalone library


LEON_with_pcore:
leon3 design that has a simple pcore to test its APB interface and to test wether the leon3 platform is in good status
the pcore is in lib "gaisler"library
The address mapping of the registers of this pcore is listed in the slides and documentation


LEON_with_multitrace:
leon3 design that has a trace interface and a pcore to capture multiple trace information
the pcore is in the standalone library "trace"
this design doesn't have a Ethernet module. You can add it into the desgin by using xgrlib tool.

To use xgrlib tool, you will need cygwin and Xsever, and issue "make xgrlib" command in design/leon3-your-FPGA-boardname directory.
Details are in the documentation.


LEON_multitrace_with_buf:
leon3 design that has a trace interface and a pcore to capture multiple trace information
the pcore is in the standalone library "trace"
trace pcore has a BUFG on trace clock input

this design doesn't have a Ethernet module. 