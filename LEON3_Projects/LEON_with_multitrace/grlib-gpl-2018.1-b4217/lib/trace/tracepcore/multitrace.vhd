library ieee; 
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library grlib;
    use grlib.amba.all;
    use grlib.devices.all;
    use grlib.stdlib.all;
library gaisler; 
  use gaisler.misc.all;

entity multitrace is
    generic (
                pindex : integer := 0;
                paddr :  integer := 0;
                pmask :  integer := 16#fff#
            );
    port    (
                rst :  in  std_ulogic;
                clk :  in  std_ulogic;
                apbi : in  apb_slv_in_type;
                apbo : out apb_slv_out_type;
                l3_instr_trace_input :  in std_logic_vector(255 downto 0);  ----this 256bits signal is from the input of the instruction trace buffer within the processor, in this design, only the lower 128bits have valid data
                l3_instr_clock_input :  in std_ulogic                        ----CPU clock
            );
end entity multitrace;

architecture rtl of multitrace is

    ----Plug and Play configuration----
    constant REVISION : integer := 0;
    constant PCONFIG : apb_config_type := (
        0 => ahb_device_reg (VENDOR_TRACE, TRACE_MULTITRACE, 0, REVISION, 0),
        1 => apb_iobar(paddr, pmask));

    -------function declaration--------
    function trace_size(a : integer) return std_logic_vector is  --this function is used for automatically deciding the number of instruction traces by pmask VHDL generic in top design file
    variable result : std_logic_vector(15 downto 0);
    begin        
         case a is
              when 16#800# => result := "0111111111111111";  --32767, let the pcore store 32767 traces   
              when 16#c00# => result := "0011111111111111";  --16383, let the pcore store 16383 traces
              when 16#e00# => result := "0001111111111111";  --8191, let the pcore store 8191 traces
              when 16#f00# => result := "0000111111111111";  --4095, let the pcore store 4095 traces
              when 16#f80# => result := "0000011111111111";  --2047, let the pcore store 2047 traces
              when 16#fc0# => result := "0000001111111111";  --1023, let the pcore store 1023 traces
              when 16#fe0# => result := "0000000111111111";  --511, let the pcore store 511 traces
              when 16#ff0# => result := "0000000011111111";  --255, let the pcore store 255 traces
              when 16#ff8# => result := "0000000001111111";  --127, let the pcore store 127 traces
              when 16#ffc# => result := "0000000000111111";  --63, let the pcore store 63 traces
              when 16#ffe# => result := "0000000000011111";  --31, let the pcore store 31 traces
              when 16#fff# => result := "0000000000001111";  --15, let the pcore store 15 traces
         end case;
         return result;
    end trace_size;
    
    function row_decoding (address : std_logic_vector) return integer is --calculate the row number to fetch the data, then give this 128 bits data to "readdata" variable for apb reading.
    variable result : integer range 1 to 32767;
    begin
         result := to_integer(unsigned(address)) - 512;
         return result;
    end row_decoding;
    
    -------constant declaration--------
    constant TRACESIZE  : std_logic_vector(15 downto 0) := trace_size(pmask);  --TRACESIZE is used to control the counter range
    constant NTRACESIZE : integer := to_integer(unsigned(TRACESIZE)) ;         --NTRACESIZE, the number of stored instruction traces. this constant is used to declare register arrays. need check here.
    
    
    -----------type defining-----------
    type registers is record
            reg : std_logic_vector(31 downto 0); 
    end record;
        
    type trace_registers_array  is array(1 to NTRACESIZE ) of registers;
    
   -------RAM initialize function------
   function init_ram
       return trace_registers_array is
       variable tmp : trace_registers_array;
       begin
           for i in 1 to NTRACESIZE loop
               tmp(i).reg := (others => '0');
           end loop;
       return tmp;
   end init_ram;

    ----signal defining------
    signal a, a_in : registers;
    signal b, b_in : registers;
    signal c, c_in : registers;
    
    ----extending pcore------
    signal ctrl_reg,   ctrl_reg_in         : registers;                ----control register, the pcore will start to store the instruction trace information when the LSb of this reg is '1'. Ths LSb of this control reg will automatically reset to '0' after N clock cycles. N=trace_size.
    
	signal opcode                          : trace_registers_array;    ----store the operation code of the instruction.
	
	signal errmode_instrctrap_progcnter    : trace_registers_array;    ----32bits signal array of combined trace information, including processor error mode(one bit), instruction trap(one bit) and program counter(30 bits).
                                                                       ----in every 32 bits column: the msb(bit 31) is processor error mode. It will be '1' if the traced instruction caued processor error mode.
                                                                       ----                         the second significant bit(bit 30) indicates instruction trap. It will set to '1' if the traced instruction trapped.
                                                                       ----                         the left 30 bits indicate the value of the program counter. In fact the program counter should be 32bits width, but the 2 lsb are always zero. As a result, here we do not use 2 more bits in hardware to store this zero value.   
	
	signal ld_st_param                     : trace_registers_array;    ----instruction result, Store address or Store data.    
	
	signal timetag_multicyc_unusedbit      : trace_registers_array;    ----32 bits signal array of combined trace information, including time tag(30 bits), multi-cycle instruction(one bit) and an unused bit.
                                                                       ----in every 32 bits column: the msb(bit 31) is the unused bit, connected to the l3_instr_trace_input(127). Its value maybe always zero.
																       ----			                the second significant bit(bit 30) indicates the multi-cycle instruction, it will set to '1' on the second and third instance of a multi-cycle instruction(e.g., LDD, ST, or FPOP.)
																       ----			                the lower 30 bits indicate the time tag, i.e., the value of the DSU time tag counter.                                                                																
    ----counter signals------
    signal cnt : std_logic_vector(15 downto 0);
    

    begin
                        
        
    
        counter:process(rst, ctrl_reg.reg, l3_instr_clock_input)    				  --counter from 0 to N, N=trace_size. This counter will enable the registers group by group.
                begin
                     if rising_edge(l3_instr_clock_input) then 
                       if rst = '0' then                							  --reset
                         cnt <= (others => '0');
                       elsif ctrl_reg.reg = "00000000000000000000000000000001" then   --0x0000_0001. when control register is enabled, start to count
                         if cnt = TRACESIZE then   									  --keep counting until it reaches trace_size. When it equals to trace_size, it will enable the last group of register to store the dat. The counter then resets to zero in next trace clock cycle.  
                           cnt <= (others => '0');
                         else
                           cnt <= cnt + 1;
                         end if;
                       else   														  --when the control register is disabled, counter keeps its value zero.
                         cnt <= (others => '0');
                       end if;
                     end if;
                end process;
        
        comb :  process(rst, a, b, c, ctrl_reg, opcode, errmode_instrctrap_progcnter, ld_st_param, timetag_multicyc_unusedbit, cnt, l3_instr_trace_input, apbi)    --apb interface and multiplier
                variable a_readdata : std_logic_vector(31 downto 0);
                variable a_tempv    : registers;

                variable b_readdata : std_logic_vector(31 downto 0);
                variable b_tempv    : registers;

                variable c_readdata : std_logic_vector(31 downto 0);              --in Vivado 2017.3, 32bits vector multiplys 32bits vectors could not pass synthesis, so this code is changed. (in Vivado 2017.2, this code passed syntax check ,synthesis, implementation as well as generating bitstream.)
                variable c_tempv    : std_logic_vector(63 downto 0);    			 --c_tempv and c_readdata are changed to 64bits(before this they are 32bits)
                                                                          

                variable ctrl_reg_readdata    : std_logic_vector(31 downto 0);
                variable ctrl_reg_tempvar     : registers;
                
                variable opcode_readdata      : std_logic_vector(31 downto 0);                
                variable errmode_instrctrap_progcnter_readdata : std_logic_vector(31 downto 0);
                variable ld_st_param_readdata : std_logic_vector(31 downto 0);
                variable timetag_multicyc_unusedbit_readdata : std_logic_vector(31 downto 0);
				
                begin
                    a_tempv := a;
                    b_tempv := b;
                    c_tempv := a.reg*b.reg;
                    
				--control register to start snapshots                    
                    ctrl_reg_tempvar      :=  ctrl_reg;
                -- read register
                    a_readdata := (others => '0');
                    b_readdata := (others => '0');
                    c_readdata := (others => '0');
                
                    ctrl_reg_readdata     := (others => '0');
                                        
                    opcode_readdata       := (others => '0');                   
                    errmode_instrctrap_progcnter_readdata  := (others => '0');
                    ld_st_param_readdata  := (others => '0');
                    timetag_multicyc_unusedbit_readdata  := (others => '0');
					
                    ----Decode----
                    if (apbi.paddr(19 downto 4) = "0000001000000000") then                  --0x200. At this time the address points to the first four regists: a, b, c and control register. line decoding. 
                        case apbi.paddr(3 downto 2) is                                      --row decoding
                            when "00" => a_readdata := a.reg(31 downto 0);                  --temporarily remain these for executing number-multiplying C code in test software.  address is 0x8000_2000.
                            when "01" => b_readdata := b.reg(31 downto 0);                  --temporarily remain these for executing number-multiplying C code in test software.  address is 0x8000_2004.
                            when "10" => c_readdata := c.reg(31 downto 0);                  --temporarily remain these for executing number-multiplying C code in test software.  address is 0x8000_2008.
                            when "11" => ctrl_reg_readdata := ctrl_reg.reg(31 downto 0);    --control register     address is 0x8000_200c.
                            when others  => null;
                        end case;
                    else
                        case apbi.paddr(3 downto 2) is --line decoding
                            when "00" =>
                            opcode_readdata       := opcode(row_decoding(apbi.paddr(19 downto 4))).reg(31 downto 0); --row decoding
                            when "01" => 
                            errmode_instrctrap_progcnter_readdata := errmode_instrctrap_progcnter(row_decoding(apbi.paddr(19 downto 4))).reg(31 downto 0); --row decoding
                            when "10" =>
                            ld_st_param_readdata  := ld_st_param(row_decoding(apbi.paddr(19 downto 4))).reg(31 downto 0); --row decoding
                            when "11" =>
                            timetag_multicyc_unusedbit_readdata := timetag_multicyc_unusedbit(row_decoding(apbi.paddr(19 downto 4))).reg(31 downto 0); --row decoding
                            when others => null;
                        end case;
                    end if;
                                        
                -- write registers from apb bus
                    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
                    case apbi.paddr(19 downto 0) is  
                        when "00000010000000000000" => a_tempv.reg := apbi.pwdata;
                        when "00000010000000000100" => b_tempv.reg := apbi.pwdata;
                        --	an unused writing address "0010" of register "c".
                        when "00000010000000001100" => ctrl_reg_tempvar.reg  := apbi.pwdata;
                        when others => null;
                    end case;
                    end if;
                --automatically reset the control register by the counter 
                    if cnt = TRACESIZE then    					----when the counter reaches trace_size, ctrl_reg_tempvar.reg will be immediately zero. 																														
                      ctrl_reg_tempvar.reg  := (others => '0');   --Later in next rising edge of the clock, ctrl_reg_tempvar.reg will give its value to 
                    end if;                                       --the output port of control register(flipflop), because ctrl_reg_tempvar.reg is also																																
                -- system reset                                   --the input port of the control register(ctrl_reg_in <= ctrl_reg_tempvar;) thus the con-
                    if rst = '0' then                             --trol register will output a zero to disable the counter as well as to stop trace. 
                    a_tempv.reg := (others => '0');
                    b_tempv.reg := (others => '0');
                    c_tempv     := (others => '0');
                    --------extending part-----
                    ctrl_reg_tempvar.reg     := (others => '0');  
                    end if;
                    	
                    	
                    a_in <= a_tempv;
                    b_in <= b_tempv;
                    c_in.reg <= c_tempv(31 downto 0);
                    ---------------------------
                    ctrl_reg_in     <= ctrl_reg_tempvar;
                    
                    --the code part below will generate a cascade mux 
                    if (apbi.paddr(19 downto 4) = "0000001000000000") then
                      case apbi.paddr(3 downto 2) is     
                          when "00" => apbo.prdata <= a_readdata; -- drive apb read bus
                          when "01" => apbo.prdata <= b_readdata; -- drive apb read bus        
                          when "10" => apbo.prdata <= c_readdata; -- drive apb read bus, leaving upper 32bits unconnected inside
                          --------extending part-----
                          when "11" => apbo.prdata <= ctrl_reg_readdata;
                          when others => apbo.prdata <= "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
                      end case;             
                    else  
                      case apbi.paddr(3 downto 2) is
                          when "00" => apbo.prdata <= opcode_readdata;       --drive apb read bus
                          when "01" => apbo.prdata <= errmode_instrctrap_progcnter_readdata;  --drive apb read bus
                          when "10" => apbo.prdata <= ld_st_param_readdata;  --drive apb read bus
                          when "11" => apbo.prdata <= timetag_multicyc_unusedbit_readdata;
                          when others => apbo.prdata <= "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
                      end case;
                    end if;
                     
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
                
			    ctrl_reg <= ctrl_reg_in;    ----ctrl_reg_in : data from the apb bus
                end if;
            end process;


        trace_regs : process(l3_instr_clock_input, ctrl_reg )
        	begin
        		if rising_edge(l3_instr_clock_input) then      			
        			if rst = '0' then 
        			opcode <= init_ram;
        			errmode_instrctrap_progcnter <= init_ram;
        			ld_st_param <= init_ram;
        			timetag_multicyc_unusedbit <= init_ram;
        			
        			elsif (ctrl_reg.reg(0)='1') then
        		    --------extending part-----
                    opcode(to_integer(unsigned(cnt))).reg        <= l3_instr_trace_input(31 downto 0);                                --instruction opcode
                    errmode_instrctrap_progcnter(to_integer(unsigned(cnt))).reg(31) <= l3_instr_trace_input(32);                      --error mode
                    errmode_instrctrap_progcnter(to_integer(unsigned(cnt))).reg(30) <= l3_instr_trace_input(33);                      --instruction trap
                    errmode_instrctrap_progcnter(to_integer(unsigned(cnt))).reg(29 downto 0) <= l3_instr_trace_input(63 downto 34);   --program counter
                    
                    ld_st_param(to_integer(unsigned(cnt))).reg   <= l3_instr_trace_input(95 downto 64);                               --load/store parameter
                    timetag_multicyc_unusedbit(to_integer(unsigned(cnt))).reg(31) <=  l3_instr_trace_input(127);                      --unused bit
                    timetag_multicyc_unusedbit(to_integer(unsigned(cnt))).reg(30) <= l3_instr_trace_input(126);                       --multi-cycle instruction
                    timetag_multicyc_unusedbit(to_integer(unsigned(cnt))).reg(29 downto 0) <= l3_instr_trace_input(125 downto 96);    --time tag
                    ---------------------------
                   end if;
                end if;
          end process;

        -- boot message
        -- pragma translate_off            	
        bootmsg : report_version
            generic map ("reg_32bits" & tost(pindex) &": Example core rev " & tost(REVISION));
        -- pragma translate_on
end architecture rtl;