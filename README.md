# Snake_Assembly
Project of classic Snake game written in assembler MASM. Some things still need to be upgraded.

# How to run game? Example steps
1. Install DosBox0.74 virtual machine
2. In Dosbox write:
  mount d C:\Path\To\Folder\With\GameFiles
  (GameFiles = LINK.exe ; MASM.exe ; snake.asm)
  This command mount given path to disc d on the virtual machine.
3. Move to mounted disc by writing D:
4. Write "masm snake.asm;" to create obj file of game.
5. Write "link snake.obj;" to create snake.exe
6. To start game write snake

# How to play game?
Use W to move up, S to go down, A to go left, D to go right. In the upper part of the screen 
there is information about points. Each second is one point and one eaten fruit is 100 points.
To exit the game click X

# Known issues
1. Sometimes game just freezes on start or after eating the fruit. This problem is possibly caused by issue with spawning fruit.

Any questions, and propositions can be send to grzegorzszymanski1109@gmail.com 
