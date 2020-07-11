#!/bin/julia
function bind_pipes()
    # UNIX named pipe for echo
    game_pipe = ARGS[1]
    while true
        s = read(`cat $game_pipe`, String)
        # println("Msg from $game_pipe : $s")
    end
end


function bind_write()
    pipe = ARGS[2]
    while true
        run(`./teste/sc.sh w $pipe`; wait=true)
        run(`echo \"w\" $pipe`)
        sleep(0.2)
    end
end

@async bind_pipes()
@async bind_write()

wait()
