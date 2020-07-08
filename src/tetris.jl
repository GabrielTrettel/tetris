# ==================
# TETRIS FROM TETRIS
# ==================



include("Styles.jl")
include("TUI_like.jl")


using LinearAlgebra, REPL

const I = ones(Int64, 4, 1)|>rotr90

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

const Z = [7 7 0;
           0 7 7]

const tetrominoes = [I, J, L, O, S, T, Z]
const Board = Matrix{Int64}

calc_iterable(x_len::Integer, y_len::Integer) = Tuple.(Iterators.product(1:y_len, 1:x_len))

mutable struct Tetromino
    type     :: Array
    x        :: Integer
    y        :: Integer
    is_alive :: Bool
    x_len    :: Integer # Column
    y_len    :: Integer # Row
    iter     :: Array
    function Tetromino(t::Array)
        type = t
        x = rand(1:6)
        y = 1

        x_len = length(type[1,:]) # Column
        y_len = length(type[:,1]) # Row

        iter = calc_iterable(x_len, y_len)

        new(type, x, y, true, x_len, y_len, iter)
    end

    function Tetromino(type, x, y, is_alive, x_len, y_len, iter)
        new(type, x, y, is_alive, x_len, y_len, iter)
    end
end



mutable struct GameStatus
    score  :: Real
    level  :: Real
    record :: Real
end

function rotate_tetromino!(t::Tetromino)


    t.type = rotr90(t.type)
    aux = t.x_len
    t.x_len = t.y_len
    t.y_len = aux
    # t.x += 1
    t.iter = calc_iterable(t.x_len, t.y_len)
end

function game_setup(mode::Integer)
    if mode == 0
        println("Enter for begin...$CEND")
        # readline()
    end
end


function pick_a_piece(lastpiece::Integer, nextpiece::Integer)
    lastpiece = nextpiece
    nextpiece = rand(0:length(tetrominoes))

    while nextpiece == 0 || nextpiece == lastpiece
        nextpiece = rand(0:length(tetrominoes))
    end

    curr_t = Tetromino(tetrominoes[lastpiece])

    return curr_t, lastpiece, nextpiece
end


function start_game()
    print("Game mode: 0 for humans, 1 for machines: ")
    # game_mode = parse(Int, readline())
    game_mode = 0

    game_setup(game_mode)
    loop(game_mode)
end

function is_a_valid_game(board::Board)
    all(x->x==0, board[4,:])
end


function parse_input(input::Char)
    lwc_input = lowercase(input)
    if 'a' == lwc_input    || 'Ϩ' == input
        return :left
    elseif 's' == lwc_input || 'ϫ' == input
        return :down
    elseif 'd' == lwc_input || 'ϩ' == input
        return :right
    elseif ' ' == lwc_input || 'Ϫ' == input
        return :rotate
    elseif 'l' == lwc_input
        return :lay
    elseif 'q' == lwc_input
        exit()
    end

    return :none
end


function get2c()
    t = REPL.TerminalMenus.terminal
    REPL.TerminalMenus.enableRawMode(t) || error("unable to switch to raw mode")
    c = Char(REPL.TerminalMenus.readKey(t.in_stream))
    REPL.TerminalMenus.disableRawMode(t)

    return c
end

# Keyboard pooling input
function monitorInput()
    inputBuffer = Channel{Char}(100)

    @async begin
        while true
            c = get2c()
            put!(inputBuffer, c)
        end
    end
    return inputBuffer
end


function clean_channel(data_channel::Channel)
    while isready(data_channel)
        take!(data_channel)
    end
end


function cpy_piece_to_board(board::Board, tetromino::Tetromino)
    for (i, j) in tetromino.iter
        if tetromino.type[i,j] != 0
            board[tetromino.y+i-1, tetromino.x+j-1] = tetromino.type[i, j]
        end
    end
end

function collides(board::Board, t::Tetromino)
    if t.y + t.y_len > 24
        return true
    end

    for (i,j) in t.iter
        if t.type[i,j] != 0 && board[t.y+i-1, t.x+j-1] != 0
             return true
         end
     end
     return false
end

function Base.copy(ta::Tetromino, tb::Tetromino)
    for f in fieldnames(Tetromino)
        setproperty!(ta, f, getproperty(tb, f))
    end
end

function rotate!(board::Board, tetromino::Tetromino)
    new_t = deepcopy(tetromino)

    rotate_tetromino!(new_t)


    if (new_t.x + new_t.x_len) >= 10
        new_t.x = 11 - new_t.x_len
    end

    collides(board, new_t) && return
    copy(tetromino, new_t)
    return
end

function fall_dist(board::Board, tetromino::Tetromino)
    for l in 4:24
        for (i,j) in tetromino.iter
            # check if there is a collision
            if l+i-1 > 24 || tetromino.type[i,j] != 0 && board[l+i-1, tetromino.x+j-1] != 0
                return l-1 - tetromino.y
            end
        end
    end
    return 0
end

function remove_tetromino_from_board(b::Board, t::Tetromino)
    for (i,j) in t.iter
        if t.type[i,j] != 0
            b[t.y+i-1, t.x+j-1] = 0
        end
    end
end


function move_tetromino!(board::Board, tetromino::Tetromino, move_to::Symbol)
    if move_to == :none return end
    if !tetromino.is_alive return end

    if tetromino.y + tetromino.y_len > 24
        return tetromino.is_alive = false
    end

    # Delete's the old Tetromino positioning
    remove_tetromino_from_board(board, tetromino)

    newx = tetromino.x
    newy = tetromino.y


    # Assumes the next move is possible
    if move_to == :left && tetromino.x > 1
        newx -= 1
    elseif move_to == :right && (tetromino.x < (11 - tetromino.x_len))
        newx += 1
    elseif move_to == :down && tetromino.y < (25 - tetromino.y_len)
        newy += 1
    elseif move_to == :lay && tetromino.y < (25 - tetromino.y_len)
        newy += fall_dist(board, tetromino)
    elseif move_to == :rotate
        rotate!(board, tetromino)
        cpy_piece_to_board(board, tetromino)
        return
    end


    # Check if it is possible
    for (i,j) in tetromino.iter
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

    tetromino.x = newx
    tetromino.y = newy

    # Persists the moove
    cpy_piece_to_board(board, tetromino)
    return
end

function shift_1_down(b::Board, row::Integer)
    for r in row:-1:4
        b[r,:] = b[r-1,:]
    end
end


function cleaned_points(b::Board)
    points = 0
    row = 24

    while row > 4 && !all(x->x==0, b[row,:])
        if all(x->x!=0, b[row,:])
            shift_1_down(b, row)
            points += 1
        else
            row -= 1
        end
    end

    return points
end


function gravity(data_channel::Channel, gs::GameStatus)
    @async begin
        while true
            put!(data_channel, :down)
            sleep(0.4 / (1 + (0.1*gs.level)))
        end
    end
end


function loop(mode)
    board = zeros(Int, 24,10)

    last_piece = 1
    next_piece = 2

    tetromino = nothing

    move_to = :down
    down_move = :none
    quit_game = :continue

    data_channel = monitorInput()
    down_channel = Channel(1)

    need_new_piece = true

    gs = GameStatus(0, 0, 0)
    t = gravity(down_channel, gs)

    while true
        if tetromino == nothing || !tetromino.is_alive
            clean_channel(data_channel)
            gs.score += cleaned_points(board)
            if (gs.score > 0 && gs.score % 10 == 0) gs.level += 1 end

            if !is_a_valid_game(board) return end
            tetromino,last_piece,next_piece = pick_a_piece(last_piece, next_piece)
            cpy_piece_to_board(board, tetromino)
        end

        if isready(data_channel)
            key_event = take!(data_channel)
            if 'g' == key_event gs.level += 20 end
            move_to = parse_input(key_event)
            move_tetromino!(board, tetromino, move_to)
        end

        if isready(down_channel)
            down_move = take!(down_channel)
            move_tetromino!(board, tetromino, down_move)
        end

        if move_to != :none || down_move != :none
            print_board(mode, board[4:end,:], tetrominoes[next_piece], gs.score, gs.level, gs.record)
            move_to = :none
            down_move = :none
        end

        sleep(0.00001)
    end
end

start_game()
