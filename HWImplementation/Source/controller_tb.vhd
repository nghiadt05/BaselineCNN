library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;
use std.textio.all;

entity controller_tb is
end controller_tb;

architecture behaviour of controller_tb is
	component controller
	port(
		rstn	: in 	std_logic;
		clk	: in	std_logic;
		out_rd : out std_logic;
		done : out std_logic;
		out_data : out signed(7 downto 0)
	);
	end component;
	
	signal rstn : std_logic := '0';
	signal clk : std_logic := '0';
	signal out_rd : std_logic;
	signal done : std_logic;
	signal out_data : signed(7 downto 0);
	signal data_cnt : natural := 0;
	constant clk_period : time := 10 ns;
begin

	con_cnn: controller
	port map(
		rstn => rstn,
		clk => clk,
		out_rd => out_rd,
		done => done,
		out_data => out_data
	);
	
	-- clock process
	process
	begin	
		clk <= not clk;
		wait for clk_period/2;	
	end process;
	
	-- reset process
	process
	begin
		rstn <= '0';
		wait for clk_period*5;
		rstn <= '1';
		wait;
	end process;
	
	-- check new data
	process(out_rd)
		file testfile : text open read_mode is "../Bin/o_conv_i_0.txt";
		variable lineOut : line;
		variable data : integer;
	begin		 
		if out_rd'event and out_rd = '1' then
			data_cnt <= data_cnt + 1;				
			if (not endfile(testFile)) then
				readline(testFile, lineOut);
				read(lineOut,data);
				assert ( data = to_integer(out_data) )
				report "Models missmatched !"
				severity failure;
			end if;
		end if;
	end process;
	
	-- check the done signal to terminate the testmench
	process(clk, done)
	begin
		if clk'event and clk='1' then
			if rstn = '1' then
				assert(done = '0') report "Done !" severity failure;
			end if;
		end if;
	end process;
	
end architecture;