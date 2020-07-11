include("Styles.jl")

include("game.jl")
import .Tetris

logo = raw"""


                    _____ ___ _____ ___ ___ ___
                   |_   _| __|_   _| _ \_ _/ __|
                     | | | _|  | | |   /| |\__ \
        ___ ___  __ _| |_|___| |_|_|_|_\___|___/ ___ ___ ___
        | __| _ \/ _ \|  \/  | |_   _| __|_   _| _ \_ _/ __|
        | _||   / (_) | |\/| |   | | | _|  | | |   /| |\__ \
        |_| |_|_\\___/|_|  |_|   |_| |___| |_| |_|_\___|___/

"""

board_string = """
            ______________________
            |%|     SCORE:  &
            |%|     LEVEL:  !
            |%|     RECORD: @
            |%|
            |%|
            |%|     NEXT TETROMINO:
            |%|      ___________
            |%|      |*|
            |%|      |*|
            |%|      |*|
            |%|      |*|
            |%|      ‾‾‾‾‾‾‾‾‾‾‾
            |%|
            |%|     CONTROLS:
            |%|     left: a
            |%|     down (1 block): s
            |%|     right: d
            |%|     rotate: space bar
            |%|     down (all blocks): l
            |%|
            |%|
            ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
"""

const BLOCK_CHAR =  "██"
const WHITE_BLOCK = " ⋅"

#                 blank    I     J      L       O      S         T       z
const COLORS = [CWHITE, CWHITE, CBLUE, CRED, CYELLOW, CGREEN, CVIOLET, CBEIGE]

function format_board_line(board_line)
    line = CBLACKBG * if length(board_line)<=4  WHITE_BLOCK ^ (4-length(board_line)) else "" end

    for col in board_line
        fill_char = if col == 0 WHITE_BLOCK else BLOCK_CHAR end

        line *= "$(COLORS[col+1])$(fill_char)"
    end
    return line * CEND
end

function print_board(args)
    body
end

print_board(gs::Tetris.GameStatus) = print_board(gs.board, gs.next_tetromino, gs.score,gs.level,gs.record)


function print_board(board, next_tetromino=[], score="None", level="None", record="None")
    next_tetromino = next_tetromino.type

    run(`clear`)
    board_line_counter = 1
    next_tetromino_line_counter = 1
    output_text = logo

    for line in split(board_string, '\n')
        if '%' in line
            line = replace(line, '%'=>format_board_line(board[board_line_counter,:]))
            board_line_counter += 1
        end

        if '*' in line
            if next_tetromino_line_counter <= length(next_tetromino[:,1])
                line = replace(line, '*'=>format_board_line(next_tetromino[next_tetromino_line_counter,:]))
                next_tetromino_line_counter += 1
            else
                line = replace(line, '*'=>format_board_line([0,0,0,0]))
            end
        end

        line = replace(line, '&'=>score)
        line = replace(line, '!'=>level)
        line = replace(line, '@'=>record)
        output_text *= line * '\n'
    end
    # write(stdout, output_text)
    # println("PRINT BOARD")
    println(output_text)
end
