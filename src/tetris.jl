using REPL
include("game.jl")
import .TetrisGame

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


function init()
    println("Humman: 1\nAI: 2")
    buffer = if readline() == "1"
        kbd_pooling_input()
    else
        AI_glue()
    end

    TetrisGame.start_game(buffer)
end

init()
