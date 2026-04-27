-- This is the main graphics file for the ship game.
-- It handles movement, collisions, drawing, respawn timing, random asteroid behavior,
-- and score updates all in one place.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pong_graph_st is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        btnU      : in  std_logic;
        btnD      : in  std_logic;
        btnL      : in  std_logic;
        btnR      : in  std_logic;
        btnC      : in  std_logic;
        video_on  : in  std_logic;
        pixel_x   : in  std_logic_vector(9 downto 0);
        pixel_y   : in  std_logic_vector(9 downto 0);
        score     : out std_logic_vector(31 downto 0);
        graph_rgb : out std_logic_vector(2 downto 0)
    );
end pong_graph_st;

architecture combined_arch of pong_graph_st is

    -- These constants control the overall screen size and the basic sizes and speeds
    -- for the ship, missile, asteroids, and timing counters.
architecture combined_arch of pong_graph_st is

    constant MAX_X : integer := 640;
    constant MAX_Y : integer := 480;

    -- ship (Collymore)
    constant SHIP_SIZE        : integer := 32;
    constant SHIP_V           : integer := 4;
    constant SHIP_DEAD_FRAMES : integer := 60;

    -- missile / beam (Collymore)
    constant MISSILE_SIZE : integer := 16;
    constant MISSILE_V    : integer := 6;

    -- asteroids (Jones)
    constant AST_COUNT      : integer := 7;
    constant AST_MIN_SIZE   : integer := 32;
    constant AST_MAX_SIZE   : integer := 64;
    constant AST_HIT_FRAMES : integer := 30;
    constant ONE_SEC_COUNT  : integer := 100000000;

    type ship_rom_type is array (0 to 31) of std_logic_vector(0 to 31);
    type beam_rom_type is array (0 to 15) of std_logic_vector(0 to 15);

    type ast_pos_x_array   is array (0 to AST_COUNT-1) of integer range 0 to MAX_X-1;
    type ast_pos_y_array   is array (0 to AST_COUNT-1) of integer range 0 to MAX_Y-1;
    type ast_size_array    is array (0 to AST_COUNT-1) of integer range AST_MIN_SIZE to AST_MAX_SIZE;
    type ast_rad_array     is array (0 to AST_COUNT-1) of integer range 0 to AST_MAX_SIZE/2;
    type ast_boundx_array  is array (0 to AST_COUNT-1) of integer range 0 to MAX_X + AST_MAX_SIZE;
    type ast_boundy_array  is array (0 to AST_COUNT-1) of integer range 0 to MAX_Y + AST_MAX_SIZE;
    type sl_array          is array (0 to AST_COUNT-1) of std_logic;
    type frame_array       is array (0 to AST_COUNT-1) of integer range 0 to 7;
    type timer_array       is array (0 to AST_COUNT-1) of integer range 0 to AST_HIT_FRAMES;

    -- This ROM stores the ship bitmap so the ship can be drawn with a fixed shape
    -- instead of just showing up as a plain square.
    constant SHIP_ROM : ship_rom_type := (
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000001000000000000000",
        "00000000000000111110000000000000",
        "00000000000000111110000000000000",
        "00000000000000111110000000000000",
        "00000000000000111110000000000000",
        "00000001100000111110000011000000",
        "00000001100000110110000011000000",
        "00000001100000110110000011000000",
        "00000001100000110110000011000000",
        "00000001100000110110000011000000",
        "00000001100011000001100011000000",
        "11000001100111000001110011000001",
        "11000001100111000001110011000001",
        "11000001111111001001111111000001",
        "11000001111111001001111111000001",
        "11000001100111111111110011000001",
        "11000000011111111111111100000001",
        "11000000011111111111111100000001",
        "00001111111111110111111111111000",
        "00001111111111110111111111111000",
        "00111111111111110111111111111110",
        "00111100011111110111111100011110",
        "00111100011111110111111100011110",
        "11110000011111000001111100000111",
        "11110000011111000001111100000111",
        "11000000000000001000000000000001"
    );

    -- This ROM does the same thing for the missile so the beam has its own shape
    -- when it is active on the screen.
    constant BEAM_ROM : beam_rom_type := (
        "0000111111110000", "0011111111111100", "0111111111111111", "0111111111111111",
        "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111",
        "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111",
        "0111111111111111", "0111111111111111", "0011111111111100", "0000111111110000"
    );

    -- In this section I am declaring the working signals for pixel position, object
    -- locations, collision flags, score tracking, and the random generator state.
    signal pix_x, pix_y : integer range 0 to 1023;
    signal refr_tick    : std_logic;
    signal checkerboard : std_logic;

    -- ship
    signal ship_x_reg, ship_x_next : integer range 0 to MAX_X-1;
    signal ship_y_reg, ship_y_next : integer range 0 to MAX_Y-1;
    signal ship_dead_reg, ship_dead_next : std_logic;
    signal ship_timer_reg, ship_timer_next : integer range 0 to SHIP_DEAD_FRAMES;

    -- missile
    signal missile_x_reg, missile_x_next : integer range 0 to MAX_X-1;
    signal missile_y_reg, missile_y_next : integer range 0 to MAX_Y-1;
    signal missile_active_reg, missile_active_next : std_logic;

    -- asteroids
    signal ast_x_reg, ast_x_next : ast_pos_x_array;
    signal ast_y_reg, ast_y_next : ast_pos_y_array;
    signal ast_size_reg, ast_size_next : ast_size_array;
    signal ast_radius_reg, ast_radius_next : ast_rad_array;
    signal ast_center_reg, ast_center_next : ast_rad_array;
    signal ast_move_cnt_reg, ast_move_cnt_next : frame_array;
    signal ast_move_lim_reg, ast_move_lim_next : frame_array;
    signal ast_hit_reg, ast_hit_next : sl_array;
    signal ast_timer_reg, ast_timer_next : timer_array;

    signal score_reg   : unsigned(31 downto 0);
    signal sec_cnt_reg : integer range 0 to ONE_SEC_COUNT-1;
    signal ast_hit_count : integer range 0 to AST_COUNT;

    signal lfsr_reg, lfsr_next : std_logic_vector(9 downto 0);

    -- boundaries
    signal ship_x_l, ship_x_r : integer range 0 to MAX_X + SHIP_SIZE;
    signal ship_y_t, ship_y_b : integer range 0 to MAX_Y + SHIP_SIZE;
    signal missile_x_l, missile_x_r : integer range 0 to MAX_X + MISSILE_SIZE;
    signal missile_y_t, missile_y_b : integer range 0 to MAX_Y + MISSILE_SIZE;

    signal ast_x_l, ast_x_r : ast_boundx_array;
    signal ast_y_t, ast_y_b : ast_boundy_array;

    -- draw enables
    signal ship_sq_on      : std_logic;
    signal ship_on         : std_logic;
    signal missile_sq_on   : std_logic;
    signal missile_on      : std_logic;
    signal ast_sq_on       : sl_array;
    signal ast_pix_on      : sl_array;
    signal ast_on          : std_logic;

    -- collisions
    signal ast_missile_hit    : sl_array;
    signal ast_ship_collision : sl_array;
    signal missile_hit_any    : std_logic;
    signal ship_collision_any : std_logic;

    -- colors
    signal ship_rgb    : std_logic_vector(2 downto 0);
    signal missile_rgb : std_logic_vector(2 downto 0);
    signal ast_rgb     : std_logic_vector(2 downto 0);

begin

    -- This first group of assignments converts the incoming pixel coordinates into
    -- integers and builds a simple frame tick and object boundary signals.
begin

    pix_x <= to_integer(unsigned(pixel_x));
    pix_y <= to_integer(unsigned(pixel_y));

    refr_tick <= '1' when (pix_y = 481) and (pix_x = 0) else '0';
    checkerboard <= pixel_x(0) xor pixel_y(0);
    score <= std_logic_vector(score_reg);

    -- boundaries
    ship_x_l <= ship_x_reg;
    ship_x_r <= ship_x_reg + SHIP_SIZE - 1;
    ship_y_t <= ship_y_reg;
    ship_y_b <= ship_y_reg + SHIP_SIZE - 1;

    missile_x_l <= missile_x_reg;
    missile_x_r <= missile_x_reg + MISSILE_SIZE - 1;
    missile_y_t <= missile_y_reg;
    missile_y_b <= missile_y_reg + MISSILE_SIZE - 1;

    -- This generate block repeats the same boundary and collision setup for every
    -- asteroid so each one can be tested independently.
    gen_ast_bounds : for i in 0 to AST_COUNT-1 generate
    begin
        ast_x_l(i) <= ast_x_reg(i);
        ast_x_r(i) <= ast_x_reg(i) + ast_size_reg(i) - 1;
        ast_y_t(i) <= ast_y_reg(i);
        ast_y_b(i) <= ast_y_reg(i) + ast_size_reg(i) - 1;

        ast_sq_on(i) <= '1' when (pix_x >= ast_x_l(i)) and (pix_x <= ast_x_r(i)) and
                                 (pix_y >= ast_y_t(i)) and (pix_y <= ast_y_b(i))
                       else '0';

        ast_missile_hit(i) <= '1' when (missile_active_reg = '1') and (ast_hit_reg(i) = '0') and
                                       (missile_x_l < ast_x_r(i) + 1) and
                                       (missile_x_r + 1 > ast_x_l(i)) and
                                       (missile_y_t < ast_y_b(i) + 1) and
                                       (missile_y_b + 1 > ast_y_t(i))
                              else '0';

        ast_ship_collision(i) <= '1' when (ship_dead_reg = '0') and (ast_hit_reg(i) = '0') and
                                          (ship_x_l < ast_x_r(i) + 1) and
                                          (ship_x_r + 1 > ast_x_l(i)) and
                                          (ship_y_t < ast_y_b(i) + 1) and
                                          (ship_y_b + 1 > ast_y_t(i))
                                 else '0';
    end generate;

    -- This process checks whether any asteroid was hit by the missile during the
    -- current frame.
    process(ast_missile_hit)
        variable any_hit : std_logic;
        variable hit_sum : integer range 0 to AST_COUNT;
    begin
        any_hit := '0';
        hit_sum := 0;
        for i in 0 to AST_COUNT-1 loop
            if ast_missile_hit(i) = '1' then
                any_hit := '1';
                hit_sum := hit_sum + 1;
            end if;
        end loop;
        missile_hit_any <= any_hit;
        ast_hit_count <= hit_sum;
    end process;

    -- This process checks whether any live asteroid overlaps the ship.
    process(ast_ship_collision)
        variable any_hit : std_logic;
    begin
        any_hit := '0';
        for i in 0 to AST_COUNT-1 loop
            if ast_ship_collision(i) = '1' then
                any_hit := '1';
            end if;
        end loop;
        ship_collision_any <= any_hit;
    end process;

    -- registers
    -- This large register process stores the current state of the ship, missile,
    -- asteroid positions, timers, and the LFSR from one clock cycle to the next.
    process(clk, reset)
    begin
        if reset = '1' then
            ship_x_reg <= 304;
            ship_y_reg <= 420;
            ship_dead_reg <= '0';
            ship_timer_reg <= 0;

            missile_x_reg <= 0;
            missile_y_reg <= 0;
            missile_active_reg <= '0';

            ast_x_reg(0) <= 40;  ast_y_reg(0) <= 0;
            ast_x_reg(1) <= 220; ast_y_reg(1) <= 90;
            ast_x_reg(2) <= 420; ast_y_reg(2) <= 180;
            ast_x_reg(3) <= 120; ast_y_reg(3) <= 280;
            ast_x_reg(4) <= 500; ast_y_reg(4) <= 380;
            ast_x_reg(5) <= 300; ast_y_reg(5) <= 40;
            ast_x_reg(6) <= 560; ast_y_reg(6) <= 220;

            ast_size_reg(0) <= 32; ast_radius_reg(0) <= 16; ast_center_reg(0) <= 15;
            ast_size_reg(1) <= 40; ast_radius_reg(1) <= 20; ast_center_reg(1) <= 19;
            ast_size_reg(2) <= 48; ast_radius_reg(2) <= 24; ast_center_reg(2) <= 23;
            ast_size_reg(3) <= 56; ast_radius_reg(3) <= 28; ast_center_reg(3) <= 27;
            ast_size_reg(4) <= 64; ast_radius_reg(4) <= 32; ast_center_reg(4) <= 31;
            ast_size_reg(5) <= 36; ast_radius_reg(5) <= 18; ast_center_reg(5) <= 17;
            ast_size_reg(6) <= 52; ast_radius_reg(6) <= 26; ast_center_reg(6) <= 25;

            ast_move_cnt_reg(0) <= 0; ast_move_lim_reg(0) <= 3;
            ast_move_cnt_reg(1) <= 0; ast_move_lim_reg(1) <= 4;
            ast_move_cnt_reg(2) <= 0; ast_move_lim_reg(2) <= 5;
            ast_move_cnt_reg(3) <= 0; ast_move_lim_reg(3) <= 4;
            ast_move_cnt_reg(4) <= 0; ast_move_lim_reg(4) <= 6;
            ast_move_cnt_reg(5) <= 0; ast_move_lim_reg(5) <= 3;
            ast_move_cnt_reg(6) <= 0; ast_move_lim_reg(6) <= 5;

            for i in 0 to AST_COUNT-1 loop
                ast_hit_reg(i) <= '0';
                ast_timer_reg(i) <= 0;
            end loop;

            lfsr_reg <= "1011010110";

        elsif rising_edge(clk) then
            ship_x_reg <= ship_x_next;
            ship_y_reg <= ship_y_next;
            ship_dead_reg <= ship_dead_next;
            ship_timer_reg <= ship_timer_next;

            missile_x_reg <= missile_x_next;
            missile_y_reg <= missile_y_next;
            missile_active_reg <= missile_active_next;

            for i in 0 to AST_COUNT-1 loop
                ast_x_reg(i) <= ast_x_next(i);
                ast_y_reg(i) <= ast_y_next(i);
                ast_size_reg(i) <= ast_size_next(i);
                ast_radius_reg(i) <= ast_radius_next(i);
                ast_center_reg(i) <= ast_center_next(i);
                ast_move_cnt_reg(i) <= ast_move_cnt_next(i);
                ast_move_lim_reg(i) <= ast_move_lim_next(i);
                ast_hit_reg(i) <= ast_hit_next(i);
                ast_timer_reg(i) <= ast_timer_next(i);
            end loop;

            lfsr_reg <= lfsr_next;
        end if;
    end process;

    -- This score process is supposed to reward survival over time and also give a
    -- bigger bonus whenever an asteroid gets destroyed.
    -- score counter: +100 each second alive, +1000 per asteroid hit, clear on respawn
    process(clk, reset)
        variable new_score : unsigned(31 downto 0);
    begin
        if reset = '1' then
            score_reg <= (others => '0');
            sec_cnt_reg <= 0;
        elsif rising_edge(clk) then
            if (btnC = '1') and (ship_dead_reg = '1') then
                score_reg <= (others => '0');
                sec_cnt_reg <= 0;
            elsif ship_dead_reg = '0' then
                new_score := score_reg;

                if sec_cnt_reg = ONE_SEC_COUNT - 1 then
                    sec_cnt_reg <= 0;
                    new_score := new_score + to_unsigned(100, 32);
                else
                    sec_cnt_reg <= sec_cnt_reg + 1;
                end if;

                if (refr_tick = '1') and (ast_hit_count > 0) then
                    new_score := new_score + to_unsigned(ast_hit_count * 1000, 32);
                end if;

                score_reg <= new_score;
            end if;
        end if;
    end process;

    -- This line of logic advances the LFSR so the asteroid respawn values do not
    -- keep repeating in an obvious pattern.
    process(lfsr_reg)
    begin
        lfsr_next <= lfsr_reg(8 downto 0) & (lfsr_reg(9) xor lfsr_reg(6));
    end process;

    -- ship death and reset management
    -- This process handles the ship death and respawn timing so the ship can stay
    -- off-screen briefly and then come back cleanly.
    process(ship_dead_reg, ship_timer_reg, ship_collision_any, btnC, refr_tick)
    begin
        ship_dead_next <= ship_dead_reg;
        ship_timer_next <= ship_timer_reg;

        if (btnC = '1') and (ship_dead_reg = '1') then
            ship_dead_next <= '0';
            ship_timer_next <= 0;
        elsif ship_collision_any = '1' then
            ship_dead_next <= '1';
            ship_timer_next <= 0;
        elsif (refr_tick = '1') and (ship_dead_reg = '1') and (ship_timer_reg < SHIP_DEAD_FRAMES) then
            ship_timer_next <= ship_timer_reg + 1;
        end if;
    end process;

    -- ship movement
    -- This movement process updates the ship position based on the pushbuttons and
    -- only moves it on the refresh tick so the motion stays stable on screen.
    process(ship_x_reg, ship_y_reg, ship_dead_reg, refr_tick, btnU, btnD, btnL, btnR, btnC)
    begin
        ship_x_next <= ship_x_reg;
        ship_y_next <= ship_y_reg;

        if refr_tick = '1' then
            if (btnC = '1') and (ship_dead_reg = '1') then
                ship_x_next <= 304;
                ship_y_next <= 420;
            elsif ship_dead_reg = '0' then
                if (btnU = '1') and (ship_y_reg > SHIP_V) then
                    ship_y_next <= ship_y_reg - SHIP_V;
                elsif (btnD = '1') and (ship_y_reg < MAX_Y - SHIP_SIZE - SHIP_V) then
                    ship_y_next <= ship_y_reg + SHIP_V;
                end if;

                if (btnL = '1') and (ship_x_reg > SHIP_V) then
                    ship_x_next <= ship_x_reg - SHIP_V;
                elsif (btnR = '1') and (ship_x_reg < MAX_X - SHIP_SIZE - SHIP_V) then
                    ship_x_next <= ship_x_reg + SHIP_V;
                end if;
            end if;
        end if;
    end process;

    -- missile / beam logic
    -- This process controls when the missile is fired, how it moves, and when it
    -- should disappear after leaving the screen or hitting something.
    process(missile_x_reg, missile_y_reg, missile_active_reg, refr_tick,
            btnC, ship_x_reg, ship_y_reg, ship_dead_reg, missile_hit_any)
    begin
        missile_x_next <= missile_x_reg;
        missile_y_next <= missile_y_reg;
        missile_active_next <= missile_active_reg;

        if missile_hit_any = '1' then
            missile_active_next <= '0';
        elsif refr_tick = '1' then
            if ship_dead_reg = '1' then
                missile_active_next <= '0';
            elsif missile_active_reg = '1' then
                if missile_y_reg >= MISSILE_V then
                    missile_y_next <= missile_y_reg - MISSILE_V;
                else
                    missile_active_next <= '0';
                end if;
            elsif btnC = '1' then
                missile_x_next <= ship_x_reg + 8;
                missile_y_next <= ship_y_reg - 8;
                missile_active_next <= '1';
            end if;
        end if;
    end process;

    -- asteroid update: movement, hit/explosion, respawn
    -- This asteroid process is the part that updates asteroid motion, hit timing,
    -- and respawn behavior using the random values from the LFSR.
    process(ast_x_reg, ast_y_reg, ast_size_reg, ast_radius_reg, ast_center_reg,
            ast_move_cnt_reg, ast_move_lim_reg, ast_hit_reg, ast_timer_reg,
            lfsr_reg, refr_tick, ship_dead_reg, ast_missile_hit, ast_x_r, ast_y_b)
        variable base_rand  : integer;
        variable spawn_x    : integer;
        variable spawn_size : integer;
        variable move_now   : boolean;
    begin
        for i in 0 to AST_COUNT-1 loop
            ast_x_next(i) <= ast_x_reg(i);
            ast_y_next(i) <= ast_y_reg(i);
            ast_size_next(i) <= ast_size_reg(i);
            ast_radius_next(i) <= ast_radius_reg(i);
            ast_center_next(i) <= ast_center_reg(i);
            ast_move_cnt_next(i) <= ast_move_cnt_reg(i);
            ast_move_lim_next(i) <= ast_move_lim_reg(i);
            ast_hit_next(i) <= ast_hit_reg(i);
            ast_timer_next(i) <= ast_timer_reg(i);
        end loop;

        base_rand := to_integer(unsigned(lfsr_reg));

        if refr_tick = '1' then
            for i in 0 to AST_COUNT-1 loop
                if ast_missile_hit(i) = '1' then
                    ast_hit_next(i) <= '1';
                    ast_timer_next(i) <= 0;
                elsif ast_hit_reg(i) = '1' then
                    if ast_timer_reg(i) < AST_HIT_FRAMES then
                        ast_timer_next(i) <= ast_timer_reg(i) + 1;
                    else
                        spawn_size := AST_MIN_SIZE + ((base_rand + i*11 + ast_timer_reg(i)) mod (AST_MAX_SIZE - AST_MIN_SIZE + 1));
                        spawn_x := ((base_rand + i*97 + ast_size_reg(i)*13) * 37) mod (MAX_X - spawn_size);

                        ast_x_next(i) <= spawn_x;
                        ast_y_next(i) <= 0;
                        ast_size_next(i) <= spawn_size;
                        ast_radius_next(i) <= spawn_size / 2;
                        ast_center_next(i) <= (spawn_size / 2) - 1;
                        ast_move_cnt_next(i) <= 0;
                        ast_move_lim_next(i) <= 3 + ((base_rand + i*7) mod 4);
                        ast_hit_next(i) <= '0';
                        ast_timer_next(i) <= 0;
                    end if;
                elsif ship_dead_reg = '0' then
                    move_now := false;

                    if ast_move_cnt_reg(i) >= ast_move_lim_reg(i) then
                        ast_move_cnt_next(i) <= 0;
                        move_now := true;
                    else
                        ast_move_cnt_next(i) <= ast_move_cnt_reg(i) + 1;
                    end if;

                    if move_now then
                        if ast_y_b(i) < (MAX_Y - 2) then
                            ast_y_next(i) <= ast_y_reg(i) + 2;

                            if ast_x_r(i) < (MAX_X - 2) then
                                ast_x_next(i) <= ast_x_reg(i) + 2;
                            else
                                ast_x_next(i) <= 0;
                            end if;
                        else
                            spawn_size := AST_MIN_SIZE + ((base_rand + i*11 + ast_y_reg(i)) mod (AST_MAX_SIZE - AST_MIN_SIZE + 1));
                            spawn_x := ((base_rand + i*97 + ast_size_reg(i)*13) * 37) mod (MAX_X - spawn_size);

                            ast_x_next(i) <= spawn_x;
                            ast_y_next(i) <= 0;
                            ast_size_next(i) <= spawn_size;
                            ast_radius_next(i) <= spawn_size / 2;
                            ast_center_next(i) <= (spawn_size / 2) - 1;
                            ast_move_cnt_next(i) <= 0;
                            ast_move_lim_next(i) <= 1 + ((base_rand + i*7) mod 3);
                        end if;
                    end if;
                end if;
            end loop;
        end if;
    end process;

    -- object bounding squares for ship and missile
    ship_sq_on <= '1' when (pix_x >= ship_x_l) and (pix_x <= ship_x_r) and
                           (pix_y >= ship_y_t) and (pix_y <= ship_y_b)
                  else '0';

    missile_sq_on <= '1' when (missile_active_reg = '1') and
                              (pix_x >= missile_x_l) and (pix_x <= missile_x_r) and
                              (pix_y >= missile_y_t) and (pix_y <= missile_y_b)
                     else '0';

    -- This drawing section decides whether the current pixel belongs to the ship
    -- and also handles the blinking effect while the ship is respawning.
    -- ship draw using Collymore 32x32 ROM
    process(pix_x, pix_y, ship_x_l, ship_y_t, ship_sq_on, ship_dead_reg, ship_timer_reg, checkerboard)
        variable row_idx : integer range 0 to SHIP_SIZE-1;
        variable col_idx : integer range 0 to SHIP_SIZE-1;
    begin
        ship_on <= '0';

        if ship_sq_on = '1' then
            row_idx := pix_y - ship_y_t;
            col_idx := pix_x - ship_x_l;

            if SHIP_ROM(row_idx)(col_idx) = '1' then
                if (ship_dead_reg = '0') or ((ship_timer_reg < SHIP_DEAD_FRAMES) and (checkerboard = '1')) then
                    ship_on <= '1';
                end if;
            end if;
        end if;
    end process;

    -- This section draws the missile by looking up the proper bit inside the beam ROM.
    -- missile draw using Collymore beam ROM
    process(pix_x, pix_y, missile_x_l, missile_y_t, missile_sq_on)
        variable row_idx : integer range 0 to MISSILE_SIZE-1;
        variable col_idx : integer range 0 to MISSILE_SIZE-1;
    begin
        missile_on <= '0';

        if missile_sq_on = '1' then
            row_idx := pix_y - missile_y_t;
            col_idx := pix_x - missile_x_l;

            if BEAM_ROM(row_idx)(col_idx) = '1' then
                missile_on <= '1';
            end if;
        end if;
    end process;

    -- Jones asteroid shape with Collymore-style checkerboard explosion
    -- This asteroid drawing process checks each asteroid's circular shape and decides
    -- whether the current pixel should be colored as part of an asteroid.
    process(pix_x, pix_y, ast_x_l, ast_y_t, ast_sq_on, ast_size_reg,
            ast_center_reg, ast_radius_reg, ast_hit_reg, ast_timer_reg, checkerboard)
        variable row_idx    : integer;
        variable col_idx    : integer;
        variable dx         : integer;
        variable dy         : integer;
        variable dist2      : integer;
        variable inside_ast : boolean;
        variable dent_scale : integer;
    begin
        for i in 0 to AST_COUNT-1 loop
            ast_pix_on(i) <= '0';

            if ast_sq_on(i) = '1' then
                row_idx := pix_y - ast_y_t(i);
                col_idx := pix_x - ast_x_l(i);

                dx := col_idx - ast_center_reg(i);
                dy := row_idx - ast_center_reg(i);
                dist2 := dx*dx + dy*dy;

                inside_ast := (dist2 <= ast_radius_reg(i) * ast_radius_reg(i));
                dent_scale := ast_size_reg(i) / 4;

                if inside_ast then
                    if (dx >= -dent_scale*2) and (dx <= -dent_scale) and
                       (dy >= -dent_scale*2) and (dy <= -dent_scale/2) then
                        if ((dx + dent_scale)*(dx + dent_scale) +
                            (dy + dent_scale)*(dy + dent_scale)) <= dent_scale*dent_scale then
                            inside_ast := false;
                        end if;
                    end if;

                    if (dx >= dent_scale/2) and (dx <= dent_scale*2) and
                       (dy >= -dent_scale/2) and (dy <= dent_scale/2) then
                        if ((dx - dent_scale)*(dx - dent_scale) + dy*dy) <= (dent_scale*dent_scale)/2 then
                            inside_ast := false;
                        end if;
                    end if;

                    if (dx >= -dent_scale*2) and (dx <= -dent_scale/2) and
                       (dy >= dent_scale/2) and (dy <= dent_scale*2) then
                        if ((dx + dent_scale)*(dx + dent_scale) +
                            (dy - dent_scale)*(dy - dent_scale)) <= (dent_scale*dent_scale)/2 then
                            inside_ast := false;
                        end if;
                    end if;
                end if;

                if inside_ast then
                    if (ast_hit_reg(i) = '0') or ((ast_timer_reg(i) < AST_HIT_FRAMES) and (checkerboard = '1')) then
                        ast_pix_on(i) <= '1';
                    end if;
                end if;
            end if;
        end loop;
    end process;

    -- This small process combines the per-asteroid draw flags into one final asteroid
    -- draw enable for the RGB logic.
    process(ast_pix_on)
        variable any_ast : std_logic;
    begin
        any_ast := '0';
        for i in 0 to AST_COUNT-1 loop
            if ast_pix_on(i) = '1' then
                any_ast := '1';
            end if;
        end loop;
        ast_on <= any_ast;
    end process;

    ship_rgb <= "100";
    missile_rgb <= "110";
    ast_rgb <= "111";

    -- This final RGB mux chooses which object gets priority at the current pixel and
    -- sends the finished color out to the top level.
    process(video_on, ship_on, missile_on, ast_on, ship_rgb, missile_rgb, ast_rgb)
    begin
        if video_on = '0' then
            graph_rgb <= "000";
        else
            if ship_on = '1' then
                graph_rgb <= ship_rgb;
            elsif missile_on = '1' then
                graph_rgb <= missile_rgb;
            elsif ast_on = '1' then
                graph_rgb <= ast_rgb;
            else
                graph_rgb <= "000";
            end if;
        end if;
    end process;

end combined_arch;