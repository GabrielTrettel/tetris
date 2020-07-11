using REPL
include("game.jl")
include("TUI_like.jl")
import .Tetris


function get2c()
    t = REPL.TerminalMenus.terminal
    REPL.TerminalMenus.enableRawMode(t) || error("unable to switch to raw mode")
    c = Char(REPL.TerminalMenus.readKey(t.in_stream))
    REPL.TerminalMenus.disableRawMode(t)

    return c
end

# Keyboard pooling input
function kbd_pooling_input()
    inputBuffer = Channel(100)

    @async begin
        while true
            c = get2c()
            put!(inputBuffer, string(c))
        end
    end
    return inputBuffer
end

function create_pipes(game_pipe, player_pipe)
    if !isfifo(game_pipe)
        run(`mkfifo $game_pipe`)
    end
    if !isfifo(player_pipe)
        run(`mkfifo $player_pipe`)
    end
end



function bind_player_pipe_with_channel(pp::String, pc::Channel)
    @async begin
        while true
            # move = read(run(`cat $pp`; wait=true), String)
            move = read(`cat $pp`, String)
            # move = "a"
            move = strip(move, ['\n', '\r'])|>String
            # println("to lendo $(typeof(move))")
            put!(pc, move)
        end
    end
end

function bind_game_buffer_with_output(gc::Channel, gp::String="")
    @async begin
        while true
            game_info = take!(gc)
            if game_info.status
                print_board(game_info)
                gp!="" && send_data_through_pipe(game_info, gp)
            else
                exit()
            end
        end
    end
end

function send_data_through_pipe(game_info::Tetris.GameStatus, gp::String)
    msg = "\"$(game_info.curr_tetromino.name)\n\""
    run(`./teste/sc.sh $msg $gp`; wait=true)
end


function init()
    game_pipe = "/tmp/game_pipe"
    player_pipe = "/tmp/player_pipe"

    human = nothing

    player_buffer = if length(ARGS) <= 0
        human = true
        kbd_pooling_input()
    else
        create_pipes(game_pipe, player_pipe)
        pc = Channel(1000)
        # println("alo")
        bind_player_pipe_with_channel(player_pipe, pc)
        human = false
        player_program = ARGS[1]

        @async run(`./$player_program $game_pipe $player_pipe`)
        pc
    end

    game_buffer = Tetris.start_game(player_buffer)

    if human
        bind_game_buffer_with_output(game_buffer)
    else
        bind_game_buffer_with_output(game_buffer, game_pipe)
    end

    wait()

end

init()
