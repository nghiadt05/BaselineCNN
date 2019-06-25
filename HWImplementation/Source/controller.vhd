library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity controller is
	port(
		rstn	: in 	std_logic;
		clk	: in	std_logic;
		out_rd : out std_logic;
		done : out std_logic;
		out_data : out signed(7 downto 0)
	);
end controller;

architecture behavioral of controller is
	-- bram component
	component bram 
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
	end component;
	
	-- mac component
	component MAC
	generic(
		Q_M : integer := 4;
		Q_D : integer := 8;
		Q_W : integer := 8
	);
	port(
		clk 	: in std_logic;
		rstn	: in std_logic;		
		w_in 	: in signed(Q_W-1 downto 0);
		x_in 	: in signed(Q_D-1 downto 0);		
		y_rd 	: out std_logic;
		y_out : out signed(Q_D-1 downto 0)
	);
	end component;
	
	--
	function log2( i : natural) return integer is
		variable temp    : integer := i;
		variable ret_val : integer := 0; 
	begin					
		while temp > 1 loop
		ret_val := ret_val + 1;
		temp    := temp / 2;     
		end loop;

		return ret_val;
	end function;
	
	-- constants and subtypes
	constant DATA_LENGTH : natural := 8;
	constant MAC_NUM 		: natural := 16;
	constant MAX 			: signed(DATA_LENGTH-1 downto 0) := ((DATA_LENGTH-1)=>'0', others => '1'); -- MAX = 2^(Q_D-1) - 1
	constant MIN 			: signed(DATA_LENGTH-1 downto 0) := ((DATA_LENGTH-1)=>'1', others => '0'); -- MIN = -2^(Q_D-1)
	
	-- conv0 configuration
	 constant C_IN			: natural := 3;
	 constant H_I			: natural := 32;
	 constant W_I			: natural := 32;
	 constant C_OUT		: natural := 16;
	 constant S				: natural := 1;
	 constant H_F			: natural := 3;
	 constant W_F			: natural := 3;
	 constant H_OUT		: natural := 30;
	 constant W_OUT		: natural := 30;
	 constant BRAM_I_INIT_FILE : string(1 to 21):= "../Bin/i_conv_i_0.txt";
	 constant BRAM_W_INIT_FILE : string(1 to 21):= "../Bin/w_conv_i_0.txt";
	 constant BRAM_O_INIT_FILE : string(1 to 21):= "../Bin/b_conv_i_0.txt";

	-- conv1 configuration
--	constant C_IN			: natural := 16;
--	constant H_I			: natural := 15;
--	constant W_I			: natural := 15;
--	constant C_OUT			: natural := 16;
--	constant S				: natural := 1;
--	constant H_F			: natural := 3;
--	constant W_F			: natural := 3;
--	constant H_OUT			: natural := 13;
--	constant W_OUT			: natural := 13;
--	constant BRAM_I_INIT_FILE : string(1 to 21):= "../Bin/i_conv_i_1.txt";
--	constant BRAM_W_INIT_FILE : string(1 to 21):= "../Bin/w_conv_i_1.txt";
--	constant BRAM_O_INIT_FILE : string(1 to 21):= "../Bin/b_conv_i_1.txt";
	
		-- conv2 configuration
--	constant C_IN			: natural := 16;
--	constant H_I			: natural := 6;
--	constant W_I			: natural := 6;
--	constant C_OUT			: natural := 16;
--	constant S				: natural := 1;
--	constant H_F			: natural := 3;
--	constant W_F			: natural := 3;
--	constant H_OUT			: natural := 4;
--	constant W_OUT			: natural := 4;
--	constant BRAM_I_INIT_FILE : string(1 to 21):= "../Bin/i_conv_i_2.txt";
--	constant BRAM_W_INIT_FILE : string(1 to 21):= "../Bin/w_conv_i_2.txt";
--	constant BRAM_O_INIT_FILE : string(1 to 21):= "../Bin/b_conv_i_2.txt";

	constant HfWf			: natural := H_F*W_F;
	constant HoWo			: natural := H_OUT*W_OUT;
	constant CiHfWf		: natural := C_IN*HfWf;

	constant BRAM_I_OFFSET : natural := H_I*W_I;
	constant BRAM_I_ADDR_MAX : natural := C_IN*BRAM_I_OFFSET;
	constant BRAM_I_STORE_SIZE : natural := BRAM_I_OFFSET;
	constant BRAM_I_ADDR_LENGTH : natural := log2(BRAM_I_STORE_SIZE) + 1;
	
	constant BRAM_W_ADDR_MAX : natural := C_OUT*CiHfWf;
	constant BRAM_W_STORE_SIZE : natural := BRAM_W_ADDR_MAX;
	constant BRAM_W_ADDR_LENGTH : natural := log2(BRAM_W_STORE_SIZE) + 1;
	
	constant BRAM_O_ADDR_MAX : natural := C_OUT*HoWo;
	constant BRAM_O_STORE_SIZE : natural := BRAM_O_ADDR_MAX;
	constant BRAM_O_ADDR_LENGTH : natural := log2(BRAM_O_STORE_SIZE) + 1;
		
	subtype 	WORD is std_logic_vector(DATA_LENGTH-1 downto 0);
		
	-- bram signals
	type 	 bram_i_dout_type is array (C_IN-1 downto 0) of WORD;
	signal bram_i_wen 	: std_logic := '0';
	signal bram_i_addr	: std_logic_vector(BRAM_I_ADDR_LENGTH-1 downto 0) := (others => '0'); 
	signal bram_i_din		: std_logic_vector(DATA_LENGTH-1 downto 0) := (others => '0');	
	signal bram_i_dout 	: bram_i_dout_type;
	
	type   bram_w_dout_type is array (MAC_NUM-1 downto 0) of WORD;
	type 	 bram_w_addr_type is array (MAC_NUM-1 downto 0) of std_logic_vector(BRAM_W_ADDR_LENGTH-1 downto 0);
	signal bram_w_wen 	: std_logic := '0';
	signal bram_w_addr	: bram_w_addr_type := (others => (others=>'0'));
	signal bram_w_din		: std_logic_vector(DATA_LENGTH-1 downto 0) := (others => '0');	
	signal bram_w_dout	: bram_w_dout_type;
	
	signal bram_o_wen 	: std_logic := '0';
	signal bram_o_addr	: std_logic_vector(BRAM_O_ADDR_LENGTH-1 downto 0) := (others => '0'); 
	signal bram_o_din		: std_logic_vector(DATA_LENGTH-1 downto 0) := (others => '0');	
	signal bram_o_dout	: std_logic_vector(DATA_LENGTH-1 downto 0) := (others => '0');	
	
	-- mac signals
	type mac_data_type is array (MAC_NUM-1 downto 0) of signed(data_length-1 downto 0);
	type mac_y_rd_type is array (MAC_NUM-1 downto 0) of std_logic;
	signal mac_rstn : std_logic := '0';
	signal mac_x_in : mac_data_type := (others => (others => '0'));
	signal mac_y_out : mac_data_type;
	signal mac_y_rd : mac_y_rd_type;
	
	-- psum 
	signal psum : signed(DATA_LENGTH-1 downto 0):= (others => '0');
	
	-- controller signal
	type state is(init, chkdn_all, chkdn_cout_i, chkdn_cin, conv_comp, psum_update, output_update, halt);
	signal cur_state, nxt_state : state := init;
	
	signal isdone_all : std_logic := '0';
	signal isdone_cout_i : std_logic := '0';
	signal isdone_cin : std_logic := '0';
	signal isdone_conv_comp : std_logic := '0';
	signal isdone_psum_updt : std_logic := '0';
	signal isdone_otpt_updt : std_logic := '0';
		
begin
	-- input map bram
	bram_input_map:
	for i in 0 to C_IN-1 generate -- number of c_in		
		bram_inmap_i : bram
		generic map(
			init			=> '1', 						-- '1': init data from file, otherwise init from 0
			seg_store 	=> '1', 						-- '1': store 1 segment only, otherwise store all
			offset		=> BRAM_I_OFFSET,			-- segment size
			segment		=> i,							-- segment index
			addr_max		=> BRAM_I_ADDR_MAX,		-- the whole data file
			store_size	=> BRAM_I_STORE_SIZE,	-- the actual storage
			data_length => DATA_LENGTH,			-- datalength
			addr_length => BRAM_I_ADDR_LENGTH,	-- ceil(log2(store_size))
			data_file 	=> BRAM_I_INIT_FILE
		)
		port map(
			clk => clk,
			wen => bram_i_wen,
			addr => bram_i_addr,
			din => bram_i_din,
			dout => bram_i_dout(i)
		);
	end generate bram_input_map;
			
	-- mac units with associated weight brams
	gen_mac:
	for i in 0 to (MAC_NUM-1) generate		
		-- weight bram
		bram_weight_i : bram
		generic map(
			init			=> '1', 						-- '1': init data from file, otherwise init from 0
			seg_store 	=> '0', 						-- '1': store 1 segment only, otherwise store all
			addr_max		=> BRAM_W_ADDR_MAX,		-- the whole data file
			store_size	=> BRAM_W_STORE_SIZE, 	-- the actual storage
			data_length => DATA_LENGTH,			-- datalength
			addr_length => BRAM_W_ADDR_LENGTH,	-- ceil(log2(store_size))
			data_file 	=> BRAM_W_INIT_FILE
		)
		port map(
			clk => clk,
			wen => bram_w_wen,
			addr => bram_w_addr(i),
			din => bram_w_din,
			dout => bram_w_dout(i)
		);
		
		-- mac
		mac_i: mac
		generic map(
			Q_M => 4,
			Q_D => DATA_LENGTH,
			Q_W => DATA_LENGTH
		)
		port map(
			clk 	=> clk,
			rstn	=> mac_rstn,
			w_in 	=> signed(bram_w_dout(i)),
			x_in 	=> mac_x_in(i),
			y_rd 	=> mac_y_rd(i),
			y_out => mac_y_out(i)
		);
	end generate gen_mac;
	
	-- output map bram
	bram_outmap : bram
	generic map(
		init			=> '1', 							-- '1': init data from file, otherwise init from 0
		seg_store 	=> '0', 							-- '1': store 1 segment only, otherwise store all
		addr_max		=> BRAM_O_ADDR_MAX,			-- the whole data file
		store_size	=> BRAM_O_STORE_SIZE, 		-- the actual storage
		data_length => DATA_LENGTH,				-- datalength
		addr_length => BRAM_O_ADDR_LENGTH,		-- ceil(log2(store_size))
		data_file 	=> BRAM_O_INIT_FILE
	)
	port map(
		clk => clk,
		wen => bram_o_wen,
		addr => bram_o_addr,
		din => bram_o_din,
		dout => bram_o_dout
	);

	-- state synchronous 
	process (clk, rstn)
	begin
		if clk'event and clk='1' then
			if rstn = '0' then
				cur_state <= init;
			else
				cur_state <= nxt_state;
			end if;
		end if;
	end process;
	
	-- next state and output update
	process (cur_state, clk)		
		variable cout_cnt : natural range 0 to 16 := 0;
		variable howo_cnt : natural range 0 to HoWo := 0;
		variable cin_cnt : natural range 0 to 7 := 0;
		variable hfwf_cnt : natural range 0 to 11 := 0;
		variable psum_cnt : natural range 0 to MAC_NUM := 0;		
		variable out_cnt : natural range 0 to 2 := 0;
		variable h_o_cnt : natural range 0 to H_OUT := 0;
		variable w_o_cnt : natural range 0 to W_OUT := 0;
		variable h_f_cnt : natural range 0 to H_F := 0;
		variable w_f_cnt : natural range 0 to W_F := 0;
		
		variable CIN_MAX_CNT	: natural := C_IN/MAC_NUM+1;		
		variable LAST_ACT_MAC : natural range 0 to MAC_NUM := 0;
		variable ACT_MAC : natural range 0 to MAC_NUM := 0;
		
		variable tmp_psum : integer range -2000 to 2000 := 0;
	begin
		if clk'event and clk = '1' then
			case cur_state is
				when init =>
					-- state update
					nxt_state <= chkdn_all;
					
					-- signal update	
					done <= '0';
					out_rd <= '0';
					out_data <= (others => '0');
					
					isdone_all <= '0';
					isdone_cout_i <= '0';
					isdone_cin <= '0';
					isdone_conv_comp <= '0';
					isdone_psum_updt <= '0';
					isdone_otpt_updt <= '0';
										
					if (C_IN mod MAC_NUM) = 0 then
						CIN_MAX_CNT := C_IN/MAC_NUM;
						LAST_ACT_MAC := MAC_NUM;
					else
						CIN_MAX_CNT := C_IN/MAC_NUM + 1;
						LAST_ACT_MAC := C_IN mod MAC_NUM;
					end if;
					
				when chkdn_all =>
					-- state update 
					if cout_cnt = C_OUT then
						nxt_state <= halt;
					else
						nxt_state <= chkdn_cout_i;
					end if;
					
					-- signal update
					if cout_cnt = C_OUT then
						isdone_all <= '1';
					else
						howo_cnt := 0;
						isdone_all <= '0';						
					end if;
				
				when chkdn_cout_i =>
					-- state update
					if howo_cnt = HoWo then
						nxt_state <= chkdn_all;
					else
						nxt_state <= chkdn_cin;
					end if;
					
					-- signal update
					if howo_cnt = HoWo then
						if isdone_cout_i = '0' then
							cout_cnt := cout_cnt + 1;
						end if;
						isdone_cout_i <= '1';
					else
						isdone_cout_i <= '0';
						-- reset cin iteration counter and psum
						cin_cnt := 0;
						tmp_psum := 0;
						psum <= (others => '0');						
					end if;						
				
				when chkdn_cin =>
					-- state update
					if cin_cnt = CIN_MAX_CNT then
						nxt_state <= output_update;
					else
						nxt_state <= conv_comp;
					end if;
					
					-- signal update
					if cin_cnt = CIN_MAX_CNT then						
						isdone_cin <= '1';
					else
						-- clear flags
						isdone_cin <= '0';
						isdone_conv_comp <= '0';
						isdone_psum_updt <= '0';
						-- MAC setup
						mac_rstn <= '0';
						if cin_cnt = CIN_MAX_CNT - 1 then
							ACT_MAC := LAST_ACT_MAC;
						else
							ACT_MAC := MAC_NUM;
						end if;						
						hfwf_cnt := 0;
						-- psum setup
						psum_cnt := 0;
						-- output map dram setup
						out_cnt := 0;
						bram_o_wen <= '0';
					end if;
					
				when conv_comp => 
					-- state update
					if hfwf_cnt <= (HfWf+1) then
						nxt_state <= conv_comp;
					else
						nxt_state <= psum_update;
					end if;
					
					-- signal update
					if hfwf_cnt <= (HfWf+1) then			
						-- input brams		
						if hfwf_cnt < HfWf then
							h_o_cnt := howo_cnt/W_OUT;
							w_o_cnt := howo_cnt mod W_OUT;
							h_f_cnt := hfwf_cnt/W_F;
							w_f_cnt := hfwf_cnt mod W_F;
							bram_i_addr <= std_logic_vector( to_unsigned( (S*h_o_cnt+h_f_cnt)*W_I + (S*w_o_cnt+w_f_cnt), BRAM_I_ADDR_LENGTH) );
						end if;
						-- weight bram and assign the output of the input brams to MAC units
						for i in 0 to ACT_MAC-1 loop -- comment this line for sysnthesis
						--for i in 0 to MAC_NUM-1 loop -- uncomment this line for synthesis
							if hfwf_cnt >= 1 and hfwf_cnt <= HfWf then
								bram_w_addr(i) <= std_logic_vector(to_unsigned(cout_cnt*CiHfWf+(cin_cnt*MAC_NUM+i)*HfWf+hfwf_cnt-1,BRAM_W_ADDR_LENGTH));								
							end if;							
							mac_x_in(i) <= signed(bram_i_dout(cin_cnt*MAC_NUM+i));
						end loop;						
						-- enable all MACs 1 clock cycle after all input data is ready
						if hfwf_cnt = 2 then
							mac_rstn <= '1';
						end if;
						hfwf_cnt := hfwf_cnt + 1;
						isdone_conv_comp <= '0';
					else						
						isdone_conv_comp <= '1';
					end if;
					
				when psum_update =>	
					-- state update
					if psum_cnt < ACT_MAC then
						nxt_state <= psum_update;
					else
						nxt_state <= chkdn_cin;
					end if;
					
					-- signal update
					if psum_cnt < ACT_MAC then	-- accumulate MAC outputs
						bram_o_addr <= std_logic_vector(to_unsigned(cout_cnt*HoWo+howo_cnt,BRAM_O_ADDR_LENGTH));
						tmp_psum := tmp_psum + to_integer(mac_y_out(psum_cnt));												
						psum_cnt := psum_cnt + 1;
						isdone_psum_updt <= '0';						
						psum <= (others => '0');					
					else 
						if isdone_psum_updt = '0' then
							cin_cnt := cin_cnt + 1;
						end if;
						isdone_psum_updt <= '1';																	
					end if;
					
				when output_update =>
					-- state update
					if out_cnt < 2 then
						nxt_state <= output_update;
					else
						nxt_state <= chkdn_cout_i;
					end if;					
					
					-- signal update
					if out_cnt = 0 then	-- add bias to output and truncate it
						tmp_psum := tmp_psum + to_integer(signed(bram_o_dout));
						if tmp_psum > to_integer(MAX) then
							psum <= MAX;
						elsif tmp_psum < to_integer(MIN) then
							psum <= MIN;			
						else
							psum <= to_signed(tmp_psum, DATA_LENGTH);	
						end if;
						isdone_otpt_updt <= '0';
						out_cnt := out_cnt + 1;
					elsif out_cnt = 1 then -- write the output to bram
						bram_o_wen <= '1';
						bram_o_addr <= std_logic_vector(to_unsigned(cout_cnt*HoWo+howo_cnt,BRAM_O_ADDR_LENGTH));
						bram_o_din <= std_logic_vector(psum);
						isdone_otpt_updt <= '0';
						out_rd <= '1';					
						out_data <= psum;
						out_cnt := out_cnt + 1;
					else
						if isdone_otpt_updt = '0' then
							howo_cnt := howo_cnt + 1;
						end if;
						out_rd <= '0';
						isdone_otpt_updt <= '1';
						bram_o_wen <= '0';
					end if;
					
				when halt =>
					-- state update
					if rstn = '0' then
						nxt_state <= init;
					else
						nxt_state <= halt;
					end if;
					
					-- signal update
					done <= '1';
					
				when others =>
					-- state update
					nxt_state <= init;
					
			end case;
		end if;
	end process;
end behavioral;

