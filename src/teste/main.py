
FIFO = "/tmp/player_pipe"
i = 0
while True:
    with open(FIFO) as fifo:
        fifo.write("1")
    i+=1
