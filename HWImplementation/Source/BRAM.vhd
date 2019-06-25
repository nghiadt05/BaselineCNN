library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

----------------------------------------------------------------------------------
entity bram is
	generic(
		init			: std_logic := '1'; 	-- '1': init data from file, otherwise init from 0
		seg_store 	: std_logic := '1'; 	-- '1': store 1 segment only, otherwise store all
		offset		: natural := 9;   	-- segment size
		segment		: natural := 3;		-- segment index
		addr_max		: natural := 432; 	-- the whole data file
		store_size	: natural := 9; 		-- the actual storage
		data_length : natural := 8;	
		addr_length : natural := 9;		-- ceil(log2(seg_size))
		data_file 	: string(1 to 21):= "../Bin/w_conv_i_0.txt"
	);
   port (		
		clk	: in std_logic;			
		wen	: in std_logic;
		addr	: in std_logic_vector(addr_length-1 downto 0);
		din	: in std_logic_vector(data_length-1 downto 0);
		dout	: out std_logic_vector(data_length-1 downto 0)			
	);
end bram;
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
architecture behavior of bram is

	subtype word is std_logic_vector(data_length-1 downto 0);
	type bram_type is array (0 to store_size-1) of word;	
	--signal bram_data : bram_type := (others => (others => '0'));	
	
	-- initialize bram data from file for fast simulation (uncomment this part for synthesis)
	impure function initbram(datafile : in string) return bram_type is
		file bramfile : text open read_mode is datafile;
		variable line : line;
		variable indata : integer range -128 to 127 := 0;
		variable bram_data : bram_type; 
	begin
		for i in 0 to addr_max-1 loop			
			if (not endfile(bramfile)) then
				readline(bramfile,line);
				read(line, indata);
				if seg_store = '0' then
					if init = '1' then
						bram_data(i) := std_logic_vector(to_signed(indata,data_length));			
					else
						bram_data(i) := (others => '0');
					end if;
				else
					if i >= segment*offset and i < (segment+1)*offset then
						if init = '1' then
							bram_data(i-segment*offset) := std_logic_vector(to_signed(indata,data_length));			
						else
							bram_data(i-segment*offset) := (others => '0');
						end if;
					end if;
				end if;					
			end if;
		end loop;
		return bram_data;
	end function;	
	signal bram_data : bram_type := initbram(data_file);		
begin
	
	process (clk)
	begin
		-- port a
		if clk'event and clk = '1' then				
			if wen = '1' then
				bram_data(conv_integer(addr)) <= din;
			end if;
			dout <= bram_data(conv_integer(addr));					
		end if;			
	end process;
	
end behavior;
----------------------------------------------------------------------------------

