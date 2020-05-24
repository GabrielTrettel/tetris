include("Styles.jl")

board_string = """

    ______________________
    |%|     SCORE:  &
    |%|     LEVEL:  !
    |%|     RECORD: @
    |%|
    |%|
    |%|     PROXIMO TETROMINO:
    |%|        ___________
    |%|        |*|
    |%|        |*|
    |%|        |*|
    |%|        |*|
    |%|        ‾‾‾‾‾‾‾‾‾‾‾
    |%|
    |%|
    |%|
    |%|
    |%|
    |%|
    |%|
    |%|
    |%|
    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
"""

const BLOCK_CHAR =  "██"
const WHITE_BLOCK = " ⋅"

#                 blank    I          J      L       O      S         T
const COLORS = [CWHITE, CWHITE, CBLUE, CRED, CYELLOW, CGREEN, CVIOLET]

function format_board_line(board_line)
    line = CBLACKBG * if length(board_line)<=4  WHITE_BLOCK ^ (4-length(board_line)) else "" end

    for col in board_line
        fill_char = if col == 0 WHITE_BLOCK else BLOCK_CHAR end

        line *= "$(COLORS[col+1])$(fill_char)"
    end
    return line * CEND
end


function print_board(mode, board, next_tetromino=[], score="None", level="None", record="None")
    if mode == 1 return end
    run(`clear`)
    board_line_counter = 1
    next_tetromino_line_counter = 1
    output_text = ""

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
    println(output_text)
end
