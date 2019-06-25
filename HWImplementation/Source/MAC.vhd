library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity MAC is
	GENERIC(
		Q_M : integer := 4;
		Q_D : integer := 8;
		Q_W : integer := 8
	);
	PORT(
		clk 	: in std_logic;
		rstn 	: in std_logic;		
		w_in 	: in signed(Q_W-1 downto 0);
		x_in 	: in signed(Q_D-1 downto 0);		
		y_rd 	: out std_logic;
		y_out : out signed(Q_D-1 downto 0)
	);	
	
	constant MAX_CNT : integer := 9;
	constant MAX : signed(Q_D-1 downto 0) := ((Q_D-1)=>'0', others => '1'); -- MAX = 2^(Q_D-1) - 1
	constant MIN : signed(Q_D-1 downto 0) := ((Q_D-1)=>'1', others => '0'); -- MIN = -2^(Q_D-1)
end entity;

architecture arch of MAC is	
begin
	-- MAC process
	process(clk, rstn)		
		variable counter : integer range 0 to MAX_CNT := 0;
		variable tmp_y_var : signed(Q_D+Q_W-1 downto 0) := (others => '0');		
	begin
		if clk'event and clk='1' then
			if rstn = '0' then
				counter := 0;				
				tmp_y_var := (others => '0');										
				y_out <= (others => '0');
				y_rd 	<= '0';				
			else		
				-- update output ready flag
				if counter < MAX_CNT then						
					counter := counter + 1;
					tmp_y_var := x_in*w_in + tmp_y_var;							
					y_rd 	<= '0';
					y_out <= (others => '0');
				else					
					if tmp_y_var(Q_D+Q_W-1 downto Q_M) > MAX then						
						y_out <= MAX;
					elsif tmp_y_var(Q_D+Q_W-1 downto Q_M) < MIN then
						y_out <= MIN;
					else
						y_out <= tmp_y_var(Q_D+Q_M-1 downto Q_M);
					end if;
					y_rd 	<= '1';
				end if;	
			end if;			
		end if;
	end process;		
end architecture;