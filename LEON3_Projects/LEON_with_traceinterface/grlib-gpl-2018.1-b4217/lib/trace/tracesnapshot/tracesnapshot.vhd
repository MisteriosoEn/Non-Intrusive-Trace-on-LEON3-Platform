library ieee; 
  use ieee.std_logic_1164.all;
  --use ieee.std_logic_arith.all;
  --use ieee.std_logic_unsigned.all;
library grlib;
    use grlib.amba.all;
    use grlib.devices.all;
    use grlib.stdlib.all;

library gaisler; 
  use gaisler.misc.all;

entity tracesnapshot is
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
                l3_instr_clock_input :  in std_ulogic                       ----in this design, cpu and apb bus have the same clock input, so we can directly use this cpu clock to drive the flipflops in the pcore
            );
end entity tracesnapshot;

architecture rtl of tracesnapshot is

    constant REVISION : integer := 0;
    constant PCONFIG : apb_config_type := (
        0 => ahb_device_reg (VENDOR_TRACE, TRACE_TRACESNAPSHOT, 0, REVISION, 0),
        1 => apb_iobar(paddr, pmask));

    type registers is record
            reg : std_logic_vector(31 downto 0);
    end record;

    signal a, a_in : registers;
    signal b, b_in : registers;
    signal c, c_in : registers;
    
    ----extending pcore------
    signal ctrl_reg,   ctrl_reg_in : registers;    ----control register, the pcore will take a snapshot of the instruction trace information when the lsb of this reg is '1'. Ths lsb of this control reg will reset to '0' in next clock cycle.
    signal opcode,     opcode_in   : registers;    ----store the operation code of the instruction.
    signal err_mode,   err_mode_in : registers;    ----its lsb will become '1' if the traced instrution caused processor error mode.
    signal instrc_trap,instrc_trap_in : registers; ----its lsb will become '1' if the traced instruction trapped.
    signal prog_cnter, prog_cnter_in   : registers;----program counter. 2 lsb are always zero.
    signal ld_st_param,ld_st_param_in  : registers;----instruction result, Store address or Store data.
    signal time_tag,   time_tag_in     : registers;----the value of the DSU time tag counter.
    signal multi_cyc,   multi_cyc_in   : registers;----its lsb will become '1' on the second and third instance of a multi-cycle instruction
                                                   ----e.g., LDD, ST, or FPOP.
--  signal reserved, reserved_in     : registers;  ----coresponding to the unused msb of a data collection in instruction trace buffer.

-------------------------

    begin
        comb :  process(rst, a, b, c, ctrl_reg, opcode, err_mode, instrc_trap, prog_cnter, ld_st_param, time_tag, multi_cyc, apbi)
                variable a_readdata : std_logic_vector(31 downto 0);
                variable a_tempv    : registers;

                variable b_readdata : std_logic_vector(31 downto 0);
                variable b_tempv    : registers;

                variable c_readdata : std_logic_vector(31 downto 0);    ----in Vivado 2017.3, 32bits vector multiplys 32bits vectors could not pass synthesis, so this code has been changed.
                variable c_tempv    : std_logic_vector(63 downto 0);    ----c_tempv and c_readdata are changed to 64bits(before this they are 32bits)
                                                                          
-------------------------
                variable ctrl_reg_readdata    : std_logic_vector(31 downto 0);
                variable ctrl_reg_tempvar     : registers;
                
                variable opcode_readdata      : std_logic_vector(31 downto 0);
                variable opcode_tempvar       : registers;
                
                variable err_mode_readdata    : std_logic_vector(31 downto 0);
                variable err_mode_tempvar     : registers;
                
                variable instrc_trap_readdata : std_logic_vector(31 downto 0);
                variable instrc_trap_tempvar  : registers;
                
                variable prog_cnter_readdata  : std_logic_vector(31 downto 0);
                variable prog_cnter_tempvar   : registers;
                
                variable ld_st_param_readdata : std_logic_vector(31 downto 0);
                variable ld_st_param_tempvar  : registers;
                
                variable time_tag_readdata    : std_logic_vector(31 downto 0);
                variable time_tag_tempvar     : registers;
                
                variable multi_cyc_readdata   : std_logic_vector(31 downto 0);
                variable multi_cyc_tempvar    : registers;
-------------------------

                begin
                    a_tempv := a;
                    b_tempv := b;
                    c_tempv := a.reg*b.reg;

--------------------l3_instr_trace_input, write the trace data from the trace interface
                    ctrl_reg_tempvar      :=  ctrl_reg;
                    
                    opcode_tempvar.reg        :=  l3_instr_trace_input(31 downto 0);
                    err_mode_tempvar.reg      :=  (0=>l3_instr_trace_input(32), others=>'0');
                    instrc_trap_tempvar.reg   :=  (0=>l3_instr_trace_input(33), others=>'0');
                    	
                    prog_cnter_tempvar.reg(31 downto 2)    :=  l3_instr_trace_input(63 downto 34);
                    prog_cnter_tempvar.reg(1 downto 0)   :=  ('0','0');             
                           	
                    ld_st_param_tempvar.reg   :=  l3_instr_trace_input(95 downto 64) ;
                    
                    time_tag_tempvar.reg(29 downto 0)      :=  l3_instr_trace_input(125 downto 96);
                    time_tag_tempvar.reg(31 downto 30)     :=  ('0', '0');
                    
                    multi_cyc_tempvar.reg     :=  (0=>l3_instr_trace_input(126), others =>'0');
                  
------------------------
                -- read register
                    a_readdata := (others => '0');
                    b_readdata := (others => '0');
                    c_readdata := (others => '0');
                    ----------
                    ctrl_reg_readdata     := (others => '0');
                    opcode_readdata       := (others => '0');
                    err_mode_readdata     := (others => '0');
                    instrc_trap_readdata  := (others => '0');
                    prog_cnter_readdata   := (others => '0');
                    ld_st_param_readdata  := (others => '0');
                    time_tag_readdata     := (others => '0');
                    multi_cyc_readdata    := (others => '0');
                    --------
                    case apbi.paddr(5 downto 2) is
                        when "0000" => a_readdata := a.reg(31 downto 0);    --temporarily remain these for testing.
                        when "0001" => b_readdata := b.reg(31 downto 0);    --temporarily remain these for testing.
                        when "0010" => c_readdata := c.reg(31 downto 0);    --temporarily remain these for testing.
                        --------extending part-----
                        when "0011" => ctrl_reg_readdata     := ctrl_reg.reg(31 downto 0);
                        when "0100" => opcode_readdata       := opcode.reg(31 downto 0);
                        when "0101" => err_mode_readdata     := err_mode.reg(31 downto 0);
                        when "0110" => instrc_trap_readdata  := instrc_trap.reg(31 downto 0);
                        when "0111" => prog_cnter_readdata   := prog_cnter.reg(31 downto 0);
                        when "1000" => ld_st_param_readdata  := ld_st_param.reg(31 downto 0);
                        when "1001" => time_tag_readdata     := time_tag.reg(31 downto 0);
                        when "1010" => multi_cyc_readdata    := multi_cyc.reg(31 downto 0);
                        ---------------------------                        
                        when others => null;
                    end case;
                -- write registers from apb bus
                    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
                    case apbi.paddr(5 downto 2) is
                        when "0000" => a_tempv.reg := apbi.pwdata;
                        when "0001" => b_tempv.reg := apbi.pwdata;
                        --	an unused writing address "0010" of register "c".
                        when "0011" => ctrl_reg_tempvar.reg     := apbi.pwdata;
                        when others => null;
                    end case;
                    end if;
                    	
                -- system reset
                    if rst = '0' then 
                    a_tempv.reg := (others => '0');
                    b_tempv.reg := (others => '0');
                    c_tempv     := (others => '0');
                    --------extending part-----					
                    ctrl_reg_tempvar.reg     := (others => '0');
                    opcode_tempvar.reg       := (others => '0');
                    err_mode_tempvar.reg     := (others => '0');
                    instrc_trap_tempvar.reg  := (others => '0');
                    prog_cnter_tempvar.reg   := (others => '0');
                    ld_st_param_tempvar.reg  := (others => '0');
                    time_tag_tempvar.reg     := (others => '0');
                    multi_cyc_tempvar.reg    := (others => '0');
                    ---------------------------
                    end if;
                    	
                    	
                    a_in <= a_tempv;
                    b_in <= b_tempv;
                    c_in.reg <= c_tempv(31 downto 0);
                    ---------------------------
                    ctrl_reg_in     <= ctrl_reg_tempvar;  
                             
                    opcode_in       <= opcode_tempvar;             
                    err_mode_in     <= err_mode_tempvar;
                    instrc_trap_in  <= instrc_trap_tempvar;
                    prog_cnter_in   <= prog_cnter_tempvar;
                    ld_st_param_in  <= ld_st_param_tempvar;
                    time_tag_in     <= time_tag_tempvar;
                    multi_cyc_in    <= multi_cyc_tempvar;           
                    ---------------------------
                    
                    case apbi.paddr(5 downto 2) is
                        when "0000" => apbo.prdata <= a_readdata; -- drive apb read bus
                        when "0001" => apbo.prdata <= b_readdata; -- drive apb read bus
                        when "0010" => apbo.prdata <= c_readdata; -- drive apb read bus, leave upper 32bits unconnected inside
                        --------extending part-----
                        when "0011" => apbo.prdata <= ctrl_reg_readdata;     --drive apb read bus
                        when "0100" => apbo.prdata <= opcode_readdata;       --drive apb read bus
                        when "0101" => apbo.prdata <= err_mode_readdata;     --drive apb read bus
                        when "0110" => apbo.prdata <= instrc_trap_readdata;  --drive apb read bus
                        when "0111" => apbo.prdata <= prog_cnter_readdata;   --drive apb read bus
                        when "1000" => apbo.prdata <= ld_st_param_readdata;  --drive apb read bus
                        when "1001" => apbo.prdata <= time_tag_readdata;     --drive apb read bus
                        when "1010" => apbo.prdata <= multi_cyc_readdata;    --drive apb read bus 
                        ---------------------------
                        --when others => null;         <------------here comes the latch!
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
			    
			    ----control flipflop(register)	
			    if ctrl_reg.reg(0) = '0' then
			      ctrl_reg <= ctrl_reg_in;    ----ctrl_reg_in : data from the apb bus
			    elsif ctrl_reg.reg(0)='1' then   
			  	  ctrl_reg.reg   <= (others =>'0');
			    end if;
				
                end if;
            end process;


        trace_regs : process(l3_instr_clock_input)
        	begin
        		if rising_edge(l3_instr_clock_input) then
        			if ctrl_reg.reg(0)='1' then
        		    --------extending part-----
                    opcode        <= opcode_in;
                    err_mode      <= err_mode_in;
                    instrc_trap   <= instrc_trap_in;
                    prog_cnter    <= prog_cnter_in;
                    ld_st_param   <= ld_st_param_in;
                    time_tag      <= time_tag_in;
                    multi_cyc     <= multi_cyc_in;
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