# ==================
# TETRIS FROM TETRIS
# ==================



include("Styles.jl")
include("TUI_like.jl")


using LinearAlgebra



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
    is_alive
end


function game_setup(mode)
    if mode == 0
        println("Enter for begin...$CEND")
        readline()
    end
end




function pick_a_piece(pieces, lastpiece, nextpiece)
    lastpiece = nextpiece
    nextpiece = rand(0:length(pieces))

    while nextpiece == 0 || nextpiece == lastpiece
        nextpiece = rand(0:length(pieces))
    end

    return [pieces[lastpiece], lastpiece, nextpiece]
end


function start_game()
    print("Game mode: 0 for humans, 1 for machines: ")
    # game_mode = parse(Int, readline())
    game_mode = 0

    game_setup(game_mode)
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
    elseif 'l' == input
        return :lay
    end

    return :none
end


# Keyboard pooling input
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
    if (tetromino.x + length(tetromino.type[1,:])) >= 10
        tetromino.x = 11 - length(tetromino.type[1,:])
    end
end

function fall_dist(board, tetromino)
    for l in 4:24
        for i in length(tetromino.type[:,1]):-1:1
            for j in length(tetromino.type[1,:]):-1:1
                # check if there is a collision
                if l+i-1 > 24 || tetromino.type[i,j] != 0 && board[l+i-1, tetromino.x+j-1] != 0
                    return l-1 - tetromino.y
                end
            end
        end
    end
    return 0
end

function move_piece!(board, tetromino, move_to)
    if move_to == :none return end
    if !tetromino.is_alive return end

    if tetromino.y+(length(tetromino.type[:,1])) > 24
        return tetromino.is_alive = false
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
    elseif move_to == :lay && tetromino.y < (25 - length(tetromino.type[:,1]))
        newy += fall_dist(board, tetromino)
    elseif move_to == :rotate
        if ndims(tetromino.type) == 1
            tetromino.type = tetromino.type'
        else
            tetromino.type = rotr90(tetromino.type)
        end
        adjust_cordinates(board, tetromino)

        cpy_piece_to_board(board, tetromino)
        return
    end


    # Check if it is possible
    for i in length(tetromino.type[:,1]):-1:1
        for j in length(tetromino.type[1,:]):-1:1
            # check if there is a collision
            if tetromino.type[i,j] != 0 && board[newy+i-1, newx+j-1] != 0
                # Collision in x-axis don't break the game but tetromino can't move sideways
                if newx != tetromino.x
                    newx = tetromino.x
                else
                    # Collision in y-axis break the game
                    cpy_piece_to_board(board, tetromino)
                    return tetromino.is_alive = false
                end
            end
        end
    end

    tetromino.x = newx
    tetromino.y = newy

    # Persists the moove
    cpy_piece_to_board(board, tetromino)
    return
end

function shift_1_down(board, row)
    for r in row:-1:4
        board[r,:] = board[r-1,:]
    end
end


function cleaned_points(board)
    points = 0
    row = 24

    while row > 4 && !all(x->x==0, board[row,:])
        if all(x->x!=0, board[row,:])
            shift_1_down(board, row)
            points += 1
        else
            row -= 1
        end
    end

    return points
end


function gravity(data_channel, gs)
    @async begin
        while true
            put!(data_channel, :down)
            sleep(0.4 / (1 + (0.1*gs.level)))
        end
    end
end


mutable struct game_status
    score
    level
    record
end

function loop(mode)
    board = zeros(Int, 24,10)
    pieces = [I, J, L, O, S, T]

    last_piece = 1
    next_piece = 2

    tetromino = nothing

    move_to = :down
    down_move = :none
    quit_game = :continue

    data_channel = monitorInput()
    down_channel = Channel(1)

    need_new_piece = true

    gs = game_status(0, 0, 0)
    t = gravity(down_channel, gs)

    while true
        if tetromino == nothing || !tetromino.is_alive
            clean_channel(data_channel)
            gs.score += cleaned_points(board)
            if (gs.score > 0 && gs.score % 10 == 0) gs.level += 1 end

            if !is_a_valid_game(board) return end
            tetromino,last_piece,next_piece = pick_a_piece(pieces, last_piece, next_piece)
            tetromino = Piece(tetromino, rand(1:6), 1, true)
            cpy_piece_to_board(board, tetromino)
        end

        if isready(data_channel)
            key_event = lowercase(take!(data_channel))
            if 'q' == key_event return end
            if 'g' == key_event gs.level += 20 end
            move_to = parse_input(key_event)
            move_piece!(board, tetromino, move_to)
        end

        if isready(down_channel)
            down_move = take!(down_channel)
            move_piece!(board, tetromino, down_move)
        end

        if move_to != :none || down_move != :none
            print_board(mode, board[4:end,:], pieces[next_piece], gs.score, gs.level, gs.record)
            move_to = :none
            down_move = :none
        end

        sleep(0.00001)
    end
end

start_game()
