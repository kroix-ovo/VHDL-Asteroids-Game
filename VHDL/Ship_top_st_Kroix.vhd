-- This top-level file ties the VGA timing block, the ship game graphics block,
-- and the score counter overlay together so everything shows up on one screen.
library ieee;
use ieee.std_logic_1164.all;

entity pong_top_st is
    port (
        clk, reset      : in  std_logic;
        btnU, btnD      : in  std_logic;
        btnL, btnR      : in  std_logic;
        btnC            : in  std_logic;
        hsync, vsync    : out std_logic;
        comp_sync       : out std_logic;
        blank           : out std_logic;
        vga_pixel_tick  : out std_logic;
        rgb             : out std_logic_vector(2 downto 0)
    );
end pong_top_st;

architecture arch of pong_top_st is

    -- In this section I am declaring the internal signals that let the three big
    -- pieces of the design talk to each other before the final RGB output is chosen.
architecture arch of pong_top_st is

    signal pixel_x, pixel_y     : std_logic_vector(9 downto 0);
    signal video_on             : std_logic;
    signal pixel_tick           : std_logic;
    signal rgb_reg, rgb_next    : std_logic_vector(2 downto 0);

    signal pong_graph_rgb       : std_logic_vector(2 downto 0);
    signal counter_rgb          : std_logic_vector(2 downto 0);
    signal score                : std_logic_vector(31 downto 0);
    signal score_on             : std_logic;

begin

    -- This block generates the VGA timing signals and also tells the rest of the
    -- design which pixel is currently being drawn on the screen.
    vga_sync_unit : entity work.vga_sync
        port map (
            clk       => clk,
            reset     => reset,
            hsync     => hsync,
            vsync     => vsync,
            comp_sync => comp_sync,
            video_on  => video_on,
            p_tick    => pixel_tick,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y
        );

    -- This block creates the main game image, including the ship, the missile,
    -- and the asteroids, and it also sends the running score value out.
    pong_graph_unit : entity work.pong_graph_st
        port map (
            clk       => clk,
            reset     => reset,
            btnU      => btnU,
            btnD      => btnD,
            btnL      => btnL,
            btnR      => btnR,
            btnC      => btnC,
            video_on  => video_on,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y,
            score     => score,
            graph_rgb => pong_graph_rgb
        );

    -- This block draws the score digits so they can be layered on top of the
    -- main graphics without changing the game logic itself.
    counter_unit : entity work.counter_display
        port map (
            pixel_x         => pixel_x,
            pixel_y         => pixel_y,
            score           => score,
            score_on_output => score_on,
            graph_rgb       => counter_rgb
        );

    -- This line chooses whether the current pixel should come from the score
    -- overlay or from the main game graphics.
    rgb_next <= counter_rgb when score_on = '1' else pong_graph_rgb;

    -- This register process updates the RGB output at the pixel tick so the
    -- screen changes in sync with the VGA timing.
    process(clk, reset)
    begin
        if reset = '1' then
            rgb_reg <= (others => '0');
        elsif rising_edge(clk) then
            if pixel_tick = '1' then
                rgb_reg <= rgb_next;
            end if;
        end if;
    end process;

    -- These last assignments send the finished RGB value out and also expose
    -- a few helpful timing/status signals at the top level.
    rgb            <= rgb_reg;
    vga_pixel_tick <= pixel_tick;
    blank          <= not video_on;

end arch;
