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
    inputBuffer = Channel{Char}(100)

    @async begin
        while true
            c = get2c()
            put!(inputBuffer, c)
        end
    end
    return inputBuffer
end

function create_pipes(game_pipe, player_pipe)
    if !isfile(game_pipe)
        run(`mkfifo $game_pipe`)
    end
    if !isfile(player_pipe)
        run(`mkfifo $player_pipe`)
    end
end

function create_player_pipe() :: Channel
    game_pipe = "/tmp/game_pipe"
    player_pipe = "/tmp/player_pipe"
    create_pipes(game_pipe, player_pipe)

    player_channel = Channel(1000)
    return player_channel
end

function bind_player_pipe_with_channel(pp::String, pc::Channel)
    @async begin
        while true
            move = read(pp)
            put!(pc, move)
        end
    end
end

function bind_game_buffer_with_output(gc::Channel)
    @async begin
        while true
            game_info = take!(gc)
            if game_info.status
                print_board(game_info)
            else
                exit()
            end
        end
    end
end



function init()
    print("Are you human? (y/n)")
    player_buffer = if readline()|>lowercase == "y"
        kbd_pooling_input()
    else
        pp = create_player_pipe()
        bind_player_pipe_with_channel(pp,pc)
        pp
    end

    game_buffer = Tetris.start_game(player_buffer)

    bind_game_buffer_with_output(game_buffer)
    wait()

end

init()
