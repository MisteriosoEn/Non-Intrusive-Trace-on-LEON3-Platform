library ieee;
  use ieee.std_logic_1164.all;
library grlib;
  use grlib.amba.all;
  use grlib.devices.all;
  use grlib.stdlib.all;
library techmap;
  use techmap.gencomp.all;   


package tracepack is
    component multitrace is
        generic (
            pindex : integer := 0;
            paddr  : integer := 0;
            pmask  : integer := 16#fff#
        );
        port (
            rst    : in  std_ulogic;
            clk    : in  std_ulogic;
            apbi   : in  apb_slv_in_type;
            apbo   : out apb_slv_out_type;
            l3_instr_trace_input :  in std_logic_vector(255 downto 0);  ----this 256bits signal is from the input of the instruction trace buffer within the processor, in this design, only the lower 128bits have valid data
            l3_instr_clock_input :  in std_ulogic  ------pending, need to consider whether we need this clock input
        );
    end component;
end tracepack;