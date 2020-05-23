# ==================
# TETRIS FROM TETRIS
# ==================



include("Styles.jl")

using LinearAlgebra

const FILL_CHAR_V = "|"
const FILL_CHAR_H_B = "‾"
const FILL_CHAR_H_T = "_"

const BLOCK_CHAR =  "██"
const WHITE_BLOCK = " ⋅"

const SEPARATOR_LINE = '|'


const I = [1;
           1;
           1;
           1]


const J = [2 0 0;
           2 2 2]

const L = [0 0 3;
           3 3 3]

const O = [4 4;
           4 4]

const S = [0 5 5;
           5 5 0]

const T = [0 6 0;
           6 6 6]

mutable struct Piece
    type
    x
    y
end


#                 blank    I          J      L       O      S         T
const COLORS = [:white, :white,  :blue, :red, :yellow, :green, :magenta]


function game_begin(mode)
    if mode == 0
        println("$(CBLINK)Enter for begin...$CEND")
        readline()
    end
end



function print_board(mode, board)
    if mode == 1 return end

    run(`clear`)
    println(CBLACKBG, FILL_CHAR_H_T^(20+3))
    for row in eachrow(board[4:end,:])
        print(FILL_CHAR_V)

        for col in row[1:end-1]
            printstyled(if col == 0 WHITE_BLOCK else BLOCK_CHAR end; color=COLORS[col+1])
        end

        printstyled(if row[end] == 0 WHITE_BLOCK*" " else BLOCK_CHAR*" " end; color = COLORS[row[end]+1])
        println(FILL_CHAR_V)
    end
    println("$(FILL_CHAR_H_B^(20+3))")
end



function pick_a_piece(pieces, last_pieces)
    return pieces[rand(1:length(pieces))]
end


function start_game()
    print("Game mode: 0 for humans, 1 for machines: ")
    # game_mode = parse(Int, readline())
    game_mode = 0

    game_begin(game_mode)
    loop(game_mode)
end

function is_a_valid_game(board)
    all(x->x==0, board[4,:])
end

function parse_input(input)
    if 'a' == input
        return :left
    elseif 's' == input
        return :down
    elseif 'd' == input
        return :right
    elseif ' ' == input
        return :rotate
    end

    return :none
end


# Keyboard pooling detector
function monitorInput()
    # Put STDIN in 'raw mode'
    ccall(:jl_tty_set_mode, Int32, (Ptr{Cvoid}, Int32), stdin.handle, true) == 0 || throw("FATAL: Terminal unable to enter raw mode.")

    inputBuffer = Channel{Char}(100)

    @async begin
        while true
            c = read(stdin, Char)
            put!(inputBuffer, c)
        end
    end
    return inputBuffer
end


function clean_channel(data_channel)
    while isready(data_channel)
        take!(data_channel)
    end
end


function cpy_piece_to_board(board, tetromino)
    for i in 1:length(tetromino.type[:,1])
        for j in 1:length(tetromino.type[1,:])
            if tetromino.type[i,j] != 0
                board[tetromino.y+i-1, tetromino.x+j-1] = tetromino.type[i, j]
            end
        end
    end
end


function adjust_cordinates(board, tetromino)
    println(tetromino.x + length(tetromino.type[1,:]))
    if (tetromino.x + length(tetromino.type[1,:])) >= 10
        tetromino.x = 11 - length(tetromino.type[1,:])
    end
end


function move_piece!(board, tetromino, move_to)
    if tetromino.y+(length(tetromino.type[:,1])) > 24
        return true
    end

    # Delete's the old piece positioning
    for i in 1:length(tetromino.type[:,1])
        for j in 1:length(tetromino.type[1,:])
            if tetromino.type[i,j] != 0
                board[tetromino.y+i-1, tetromino.x+j-1] = 0
            end
        end
    end

    newx = tetromino.x
    newy = tetromino.y


    # Assumes the next move is possible
    if move_to == :left && tetromino.x > 1
        newx -= 1
    elseif move_to == :right && (tetromino.x < (11 - length(tetromino.type[1,:])))
        newx += 1
    elseif move_to == :down && tetromino.y < (25 - length(tetromino.type[:,1]))
        newy += 1
    elseif move_to == :rotate
        if ndims(tetromino.type) == 1
            tetromino.type = tetromino.type'
        else
            tetromino.type = rotr90(tetromino.type)
        end
        adjust_cordinates(board, tetromino)

        cpy_piece_to_board(board, tetromino)
        return false
    end

    # Check if it is possible
    for i in 1:length(tetromino.type[:,1])
        for j in 1:length(tetromino.type[1,:])
            if tetromino.type[i,j] != 0 && board[newy+i-1, newx+j-1] != 0
                if newx != tetromino.x
                    newx = tetromino.x
                else
                    cpy_piece_to_board(board, tetromino)
                    return true
                end
            end
        end
    end

    tetromino.x = newx
    tetromino.y = newy

    # Persists the moove
    cpy_piece_to_board(board, tetromino)
    return false
end


function cleaned_points(board)
    points = 0

    for row in 24:-1:4
        if all(x->x!=0, board[row,:])
            for i in row:-1:4
                board[i,:] = board[i-1,:]
                if all(x->x==0, board[row,:])
                    break
                end
            end
            points += 1

        elseif all(x->x==0, board[row,:])
            break
        end
    end

    return points
end


function loop(mode)
    board = zeros(Int, 24,10)
    pieces = [I, J, L, O, S, T]
    last_pieces = []


    tetromino = nothing

    move_to = :none
    quit_game = :continue

    data_channel = monitorInput()

    print_board(mode, board)

    need_new_piece = true
    # while is_a_valid_game(board)
    i=0
    score = 0
    while true
        score += cleaned_points(board)

        i+=1

        if isready(data_channel)
            key_event = lowercase(take!(data_channel))

            if 'q' == key_event return end
            move_to = parse_input(key_event)
            println("$CRED -- $move_to -- $CEND")
        end

        println("Score: $score")
        # println(i)
        # println(need_new_piece)
        # println(move_to)

        if need_new_piece
            if !is_a_valid_game(board)
                break
            end
            tetromino = Piece(pick_a_piece(pieces, last_pieces), rand(1:6), 1)
            cpy_piece_to_board(board, tetromino)
            need_new_piece = false
        end


        if move_to != :none
            need_new_piece = move_piece!(board, tetromino, move_to)
        end


        if !need_new_piece
            need_new_piece = move_piece!(board, tetromino, :down)
        end

        move_to = :none
        clean_channel(data_channel)
        println(tetromino)
        sleep(0.3) # FIXME
        print_board(mode, board)

    end
end

start_game()
