library ieee;
  use ieee.std_logic_1164.all;
library grlib;
  use grlib.amba.all;
  use grlib.devices.all;
  use grlib.stdlib.all;
--  use grlib.config_types.all;
--  use grlib.config.all;
--  use grlib.devices.all;
library techmap;
  use techmap.gencomp.all;
--library gaisler;   
--library gaisler;    --multiplier32bits;          


package multiplier32 is
    component multiplier32bits is
        generic (
            pindex : integer := 0;
            paddr  : integer := 0;
            pmask  : integer := 16#fff#
        );
        port (
            rst    : in  std_ulogic;
            clk    : in  std_ulogic;
            apbi   : in  apb_slv_in_type;
            apbo   : out apb_slv_out_type
        );
    end component;
end multiplier32;