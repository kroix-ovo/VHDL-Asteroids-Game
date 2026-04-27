-- This file is only for drawing the score in the top-right area of the VGA screen.
-- It does not change the score value itself, it just turns the number into pixels.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_display is
    port (
        pixel_x          : in  std_logic_vector(9 downto 0);
        pixel_y          : in  std_logic_vector(9 downto 0);
        score            : in  std_logic_vector(31 downto 0);
        score_on_output  : out std_logic;
        graph_rgb        : out std_logic_vector(2 downto 0)
    );
end counter_display;

architecture Behavioral of counter_display is
    -- These constants set the size of each digit and where the score box begins on screen.
architecture Behavioral of counter_display is
    constant DIGIT_SIZE : integer := 16;
    constant DIGIT_COUNT: integer := 7;
    constant SCORE_X_L  : integer := 520;
    constant SCORE_Y_T  : integer := 8;
    constant SCORE_X_R  : integer := SCORE_X_L + DIGIT_COUNT*DIGIT_SIZE - 1;
    constant SCORE_Y_B  : integer := SCORE_Y_T + DIGIT_SIZE - 1;

    -- In this part I am using small ROM patterns for each digit so the score can
    -- be drawn like a little bitmap image one pixel at a time.
    type digit_rom_type is array (0 to 15) of std_logic_vector(0 to 15);

    constant DIGIT_ROM_BLANK : digit_rom_type := (
        "0000000000000000","0000000000000000","0000000000000000","0000000000000000",
        "0000000000000000","0000000000000000","0000000000000000","0000000000000000",
        "0000000000000000","0000000000000000","0000000000000000","0000000000000000",
        "0000000000000000","0000000000000000","0000000000000000","0000000000000000"
    );

    constant DIGIT_ROM_0 : digit_rom_type := (
        "0000111111110000","0001111111111000","0011110000111100","0011100000011100",
        "0111000000001110","0111000000001110","0111000000001110","0111000000001110",
        "0111000000001110","0111000000001110","0111000000001110","0111000000001110",
        "0011100000011100","0011110000111100","0001111111111000","0000111111110000"
    );

    constant DIGIT_ROM_1 : digit_rom_type := (
        "0000001111000000","0000011111000000","0000111111000000","0001111111000000",
        "0011111111000000","0000011111000000","0000011111000000","0000011111000000",
        "0000011111000000","0000011111000000","0000011111000000","0000011111000000",
        "0000011111000000","0000011111000000","0011111111111100","0011111111111100"
    );

    constant DIGIT_ROM_2 : digit_rom_type := (
        "0001111111111000","0011111111111100","0011100000011100","0000000000011100",
        "0000000000111000","0000000001110000","0000000011100000","0000000111000000",
        "0000001110000000","0000011100000000","0000111000000000","0001110000000000",
        "0011100000000000","0011111111111100","0011111111111100","0000000000000000"
    );

    constant DIGIT_ROM_3 : digit_rom_type := (
        "0001111111111000","0011111111111100","0011100000011100","0000000000011100",
        "0000000000111000","0000000111110000","0000000111110000","0000000000111000",
        "0000000000011100","0000000000011100","0000000000011100","0000000000011100",
        "0011100000011100","0011111111111100","0001111111111000","0000000000000000"
    );

    constant DIGIT_ROM_4 : digit_rom_type := (
        "0000000011110000","0000000111110000","0000001111110000","0000011111110000",
        "0000111011110000","0001110011110000","0011100011110000","0111000011110000",
        "0111111111111110","0111111111111110","0000000011110000","0000000011110000",
        "0000000011110000","0000000011110000","0000000011110000","0000000000000000"
    );

    constant DIGIT_ROM_5 : digit_rom_type := (
        "0011111111111100","0011111111111100","0011100000000000","0011100000000000",
        "0011100000000000","0011111111111000","0011111111111100","0000000000011100",
        "0000000000011100","0000000000011100","0000000000011100","0000000000011100",
        "0011100000011100","0011111111111100","0001111111111000","0000000000000000"
    );

    constant DIGIT_ROM_6 : digit_rom_type := (
        "0000111111110000","0001111111111000","0011110000011100","0011100000000000",
        "0111000000000000","0111001111110000","0111111111111000","0111110000011100",
        "0111000000001110","0111000000001110","0111000000001110","0111000000001110",
        "0011100000011100","0011111111111000","0001111111110000","0000000000000000"
    );

    constant DIGIT_ROM_7 : digit_rom_type := (
        "0011111111111110","0011111111111110","0000000000011100","0000000000111000",
        "0000000001110000","0000000011100000","0000000111000000","0000001110000000",
        "0000011100000000","0000011100000000","0000011100000000","0000011100000000",
        "0000011100000000","0000011100000000","0000011100000000","0000000000000000"
    );

    constant DIGIT_ROM_8 : digit_rom_type := (
        "0001111111111000","0011111111111100","0011100000011100","0011100000011100",
        "0011100000011100","0011111111111100","0001111111111000","0011111111111100",
        "0011100000011100","0011100000011100","0011100000011100","0011100000011100",
        "0011100000011100","0011111111111100","0001111111111000","0000000000000000"
    );

    constant DIGIT_ROM_9 : digit_rom_type := (
        "0001111111110000","0011111111111000","0011100000011100","0111000000001110",
        "0111000000001110","0111000000001110","0111000000001110","0011111111101110",
        "0001111111101110","0000000000001110","0000000000011100","0000000000111000",
        "0011100001110000","0011111111100000","0001111111000000","0000000000000000"
    );

begin
    -- This combinational process checks the current screen pixel, figures out which
    -- score digit it belongs to, and then decides whether that pixel should light up.
begin
    process(pixel_x, pixel_y, score)
        variable px, py     : integer;
        variable score_int  : integer;
        variable digit_idx  : integer;
        variable row_idx    : integer;
        variable col_idx    : integer;
        variable digit_val  : integer range 0 to 9;
        variable rom_cur    : digit_rom_type;
        variable blank_digit: boolean;
    begin
        score_on_output <= '0';
        graph_rgb <= "000";

        px := to_integer(unsigned(pixel_x));
        py := to_integer(unsigned(pixel_y));
        score_int := to_integer(unsigned(score));

        if (SCORE_X_L <= px) and (px <= SCORE_X_R) and (SCORE_Y_T <= py) and (py <= SCORE_Y_B) then
            digit_idx := (px - SCORE_X_L) / DIGIT_SIZE;
            row_idx := py - SCORE_Y_T;
            col_idx := (px - SCORE_X_L) mod DIGIT_SIZE;

            blank_digit := false;

            -- This case statement picks which decimal digit of the score should
            -- be displayed at the current x position.
            case digit_idx is
                when 0 =>
                    if score_int >= 1000000 then
                        digit_val := (score_int / 1000000) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when 1 =>
                    if score_int >= 100000 then
                        digit_val := (score_int / 100000) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when 2 =>
                    if score_int >= 10000 then
                        digit_val := (score_int / 10000) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when 3 =>
                    if score_int >= 1000 then
                        digit_val := (score_int / 1000) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when 4 =>
                    if score_int >= 100 then
                        digit_val := (score_int / 100) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when 5 =>
                    if score_int >= 10 then
                        digit_val := (score_int / 10) mod 10;
                    else
                        blank_digit := true;
                        digit_val := 0;
                    end if;
                when others =>
                    digit_val := score_int mod 10;
            end case;

            -- This section chooses the correct digit ROM, or a blank ROM when a
            -- leading zero should stay hidden.
            if blank_digit then
                rom_cur := DIGIT_ROM_BLANK;
            else
                case digit_val is
                    when 0 => rom_cur := DIGIT_ROM_0;
                    when 1 => rom_cur := DIGIT_ROM_1;
                    when 2 => rom_cur := DIGIT_ROM_2;
                    when 3 => rom_cur := DIGIT_ROM_3;
                    when 4 => rom_cur := DIGIT_ROM_4;
                    when 5 => rom_cur := DIGIT_ROM_5;
                    when 6 => rom_cur := DIGIT_ROM_6;
                    when 7 => rom_cur := DIGIT_ROM_7;
                    when 8 => rom_cur := DIGIT_ROM_8;
                    when others => rom_cur := DIGIT_ROM_9;
                end case;
            end if;

            -- This final check decides whether the current row and column inside
            -- the digit should actually be turned on.
            if rom_cur(row_idx)(col_idx) = '1' then
                score_on_output <= '1';
                graph_rgb <= "010";
            end if;
        end if;
    end process;

end Behavioral;
