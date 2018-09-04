library ieee; 
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  --use ieee.std_logic_unsigned.all;
  
library grlib;
    use grlib.amba.all;
    use grlib.devices.all;
    use grlib.stdlib.all;

library gaisler; 
  use gaisler.misc.all;


entity multiplier32bits is
    generic (
                pindex : integer := 0;
                paddr :  integer := 0;
                pmask :  integer := 16#fff#
            );
    port    (
                rst :  in  std_ulogic;
                clk :  in  std_ulogic;
                apbi : in  apb_slv_in_type;
                apbo : out apb_slv_out_type
            );
end entity multiplier32bits;

architecture rtl of multiplier32bits is

    constant REVISION : integer := 0;
    constant PCONFIG : apb_config_type := (
        0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_MULTIPLIER32, 0, REVISION, 0),
        1 => apb_iobar(paddr, pmask));

    type registers is record
            reg : std_logic_vector(31 downto 0);
    end record;

    signal a, a_in : registers;
    signal b, b_in : registers;
    signal c, c_in : registers;


    begin
        comb :  process(rst, a, b, c, apbi)
                variable a_readdata : std_logic_vector(31 downto 0);
                variable a_tempv    : registers;

                variable b_readdata : std_logic_vector(31 downto 0);
                variable b_tempv    : registers;

                variable c_readdata : std_logic_vector(31 downto 0);
                --variable c_tempv    : registers;
				variable c_tempv    : std_logic_vector(63 downto 0);



                begin
                    a_tempv := a;
                    b_tempv := b;
                    c_tempv := a.reg*b.reg;
                -- read register
                    a_readdata := (others => '0');
                    b_readdata := (others => '0');
                    c_readdata := (others => '0');
                    case apbi.paddr(4 downto 2) is
                        when "000" => a_readdata := a.reg(31 downto 0);
                        when "001" => b_readdata := b.reg(31 downto 0);
                        when "010" => c_readdata := c.reg(31 downto 0);
                        when others => null;
                    end case;
                -- write registers
                    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
                    case apbi.paddr(4 downto 2) is
                        when "000" => a_tempv.reg := apbi.pwdata;
                        when "001" => b_tempv.reg := apbi.pwdata;
                        when others => null;
                    end case;
                    end if;
                -- system reset
                    if rst = '0' then 
                    a_tempv.reg := (others => '0');
                    b_tempv.reg := (others => '0');
                    c_tempv     := (others => '0');
                    end if;
					
                    a_in <= a_tempv;
                    b_in <= b_tempv;
                    c_in.reg <= c_tempv(31 downto 0);
                    case apbi.paddr(4 downto 2) is
                        when "000" => apbo.prdata <= a_readdata; -- drive apb read bus
                        when "001" => apbo.prdata <= b_readdata; -- drive apb read bus
                        when "010" => apbo.prdata <= c_readdata; -- drive apb read bus
                        when others => apbo.prdata <= "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
                    end case;
                end process;

        apbo.pirq <= (others => '0'); -- No IRQ
        apbo.pindex <= pindex;        -- VHDL generic
        apbo.pconfig <= PCONFIG;      -- Config constant
        -- registers
        regs : process(clk)
            begin
                if rising_edge(clk) then 
                a <= a_in; 
                b <= b_in;
                c <= c_in;                  
               end if;
            end process;
        -- boot message
        -- pragma translate_off
        bootmsg : report_version
            generic map ("reg_32bits" & tost(pindex) &": Example core rev " & tost(REVISION));
        -- pragma translate_on
end architecture rtl;