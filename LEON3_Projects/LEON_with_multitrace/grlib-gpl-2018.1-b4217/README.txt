leon3 design with a trace interface and a pcore to capture multiple trace information
the pcore is in a standalone library
this design doesn't have a Ethernet module. You can add it into the desgin by using xgrlib tool.

To use xgrlib tool, you will need cygwin and Xsever, and issue "make xgrlib" command in design/leon3-your-board directory.
Details are in the documentation.