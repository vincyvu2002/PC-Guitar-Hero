setscreen ("graphics:max;max,offscreenonly")
% Offscreen mode is used to prevent screen flickering during draw by utilising double buffer technique

var L1, L2, L3, L4, MY1, MY2, MY3, MY4, Random, tim : int
var MY : array 1 .. 10000 of int

% Array of X-position of each line (there are four lines)
var Lines : array 1 .. 4 of int := init (543, 629, 715, 801)

% Array of color of each line (there are four lines)
var Colors : array 1 .. 4 of int := init (black, red, green, yellow)

tim := 0

% Each rythm record represent a single ball on a specific line and a delay (to the next ball)
type Rythm :
    record
	line : int
	vdelay : int % delay is a reserved word so we use vdelay here
    end record

% Class representing individual balls on screen. The reason to use class instead of
% the much simpler recrod type is because balls must be dynamically allocated and destroyed
% at run time. That's the only way turing allows objects to be allocated.
class Ball
    export var Y, var X, var Color
    var Y : int
    var X : int
    var Color : int
end Ball

% Represents the slots for balls for a single line
type LineOfBalls :
    record
	balls : array 1 .. 10 of pointer to Ball
    end record

% Programmable list of Rythm records, we can have up to 10000 of these
var rythms : array 1 .. 10000 of Rythm

% Initialise the rythm records to represent empty record. Here we use line = 0 to represent empty records.
for i : 1 .. 10000
    rythms (i).line := 0
end for

% Procedure for reading in rythm data from a file. This allows this program to be driven by data.
% The data file is a plain text file that contains multiple lines, each representing a single rythm record.
% Each line must follow this format:
% <line_number> <delay>
% E.g. "1 500" meaning insert a new ball on line 1 and wait 500ms before inserting the next ball.
procedure readInData (fileName : string)
    var line, vdelay : int
    var fd : int
    open : fd, fileName, get
    var rythIndex : int := 1
    if fd > 0 then
	loop
	    exit when eof (fd)
	    get : fd, line % Remember the first item on a line is the line number ...
	    rythms (rythIndex).line := line
	    get : fd, vdelay % ... and the next item is the delay
	    rythms (rythIndex).vdelay := vdelay
	    rythIndex := rythIndex + 1
	    if rythIndex > 10000 then
		exit
	    end if
	end loop
	close : fd
    else
	put "Failed to open " + fileName
    end if
end readInData

% Creates a new ball object against a certain line
function CreateNewBall (line : int) : pointer to Ball
    var ret : pointer to Ball
    new Ball, ret
    ret -> Y := 625
    ret -> X := Lines (line)
    ret -> Color := Colors (line)
    result ret
end CreateNewBall

% Moves a specific ball downward (2 pixels)
procedure MoveBall (var ball : pointer to Ball)
    ball -> Y := ball -> Y - 2
end MoveBall

% Since we are utilising multi-processing technique in this program, and that the various
% processes are manipulating and accessing the balls on screen simultaneously, this is a
% way to protect access to the ball records. Monitors only allow one process to invoke its
% functions and procedures at a time. Note though that Turing's monitors are not recursive
% and as such you cannot call one exported function/method from another exported function
% without instantly dead-locking on yourself.
monitor BallControl
    import Ball, CreateNewBall, Lines, Colors, MoveBall, LineOfBalls
    export destroyBall, introduceNewBall, drawAndMoveBalls, initialise
    var lineOfBalls : array 1 .. 4 of LineOfBalls

    % Private procedure for destroying a specific ball on a particular line.
    % This can be used from other exported function within this monitor without
    % dead-lock.
    procedure _destroyBall (whichLine : int, whichBall : int)
	if lineOfBalls (whichLine).balls (whichBall) not= nil then
	    free Ball, lineOfBalls (whichLine).balls (whichBall)
	    lineOfBalls (whichLine).balls (whichBall) := nil
	end if
    end _destroyBall

    procedure initialise ()
	for l : 1 .. 4
	    for i : 1 .. 10
		lineOfBalls (l).balls (i) := nil
	    end for
	end for
    end initialise

    procedure destroyBall (whichLine : int, whichBall : int)
	_destroyBall (whichLine, whichBall)
    end destroyBall

    procedure introduceNewBall (whichLine : int)
	for i : 1 .. 10
	    if lineOfBalls (whichLine).balls (i) = nil then
		lineOfBalls (whichLine).balls (i) := CreateNewBall (whichLine)
		return
	    end if
	end for
    end introduceNewBall

    procedure drawAndMoveBalls
	for line : 1 .. 4
	    for ballIdx : 1 .. 10
		if lineOfBalls (line).balls (ballIdx) not= nil then
		    Draw.FillOval (lineOfBalls (line).balls (ballIdx) -> X, lineOfBalls (line).balls (ballIdx) -> Y, 25, 25, lineOfBalls (line).balls (ballIdx) -> Color)
		    MoveBall (lineOfBalls (line).balls (ballIdx))
		    if lineOfBalls (line).balls (ballIdx) -> Y < 0 then
			_destroyBall (line, ballIdx)
		    end if
		end if
	    end for
	end for
    end drawAndMoveBalls

end BallControl

% Procedure for drawing the background of the guitar
procedure BasOutline
    %Fill
    drawfillbox (500, 0, maxx - 500, maxy, 20)
    Draw.ThickLine (maxx - 500, maxy, maxx - 500, 0, 6, black)
    Draw.ThickLine (maxx - 500, maxy, 500, maxy, 6, black)
    Draw.ThickLine (maxx - 500, 0, 500, 0, 6, black)
    Draw.ThickLine (500, maxy, 500, 0, 6, black)
    % Outline white inside
    Draw.ThickLine (500, 0, 500, maxy, 2, grey)
    Draw.ThickLine (maxx - 500, maxy, maxx - 500, 0, 2, grey)

    % Click Zone
    drawfillbox (503, 25, maxx - 503, 75, black)
    Draw.ThickLine (503, 25, maxx - 503, 25, 2, black)
    Draw.ThickLine (503, 75, maxx - 503, 75, 2, black)

    % INSIDE LINES
    % Middle Line
    Draw.ThickLine (672, 648, 672, 13, 2, black)
    % Left Line
    Draw.ThickLine (586, 648, 586, 13, 2, black)
    % Right Line
    Draw.ThickLine (maxx - 586, 648, maxx - 586, 13, 2, black)
end BasOutline

% Background process for updating the view of the application. Basically this invokes
% the procedure to draw the background, and then to draw the balls on top of the background.
% This uses the double-buffing technique to prevent flickering when drawing the background
% causing balls to be wiped out.
process UpdateView
    for i : 1 .. 10000
	BasOutline
	BallControl.drawAndMoveBalls ()
	View.Update % Pop the draw buffer to the screen, providing flicker-less rendering
	delay (5)
    end for

    % We're done with the view update, destroy all balls to free up memory
    for ballIdx : 1 .. 4
	for i : 1 .. 10
	    BallControl.destroyBall (ballIdx, i)
	end for
    end for
end UpdateView

% Background process to play the music
process song
    Music.PlayFile ("SNPNG.wav") %play a sound or music file
end song

process Clock
    loop
	locate (1, 1)
	put tim
	delay (1000)
	tim := tim + 1
    end loop
end Clock

BasOutline

% Fork a background process for playing the song
fork song
BallControl.initialise ()

% Read the data to drive the rythm
readInData ("rythms.txt")

% Fork a background process for displaying the clock
fork Clock

% Fork a background process for updating the view
fork UpdateView
delay (7000)

% Go through the list of the rythm records read in from the data file earlier,
% and execute them, one by one.
for rythIdx : 1 .. 10000
    if rythms (rythIdx).line > 0 then
	BallControl.introduceNewBall (rythms (rythIdx).line)
	if rythms (rythIdx).vdelay > 0 then
	    delay (rythms (rythIdx).vdelay)
	end if
    end if
end for
% BallControl.introduceNewBall (4)
% delay (500)
% BallControl.introduceNewBall (4)
% delay (150)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% delay (200)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (2)
% delay (200)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (4)
% delay (200)
% BallControl.introduceNewBall (4)
% delay (500)
% BallControl.introduceNewBall (3)
% delay (200)
% BallControl.introduceNewBall (2)
% delay (200)
% BallControl.introduceNewBall (1)
% delay (150)
% BallControl.introduceNewBall (2)
% delay (750)
% BallControl.introduceNewBall (3)
% delay (150)
% BallControl.introduceNewBall (4)
% delay (500)
% BallControl.introduceNewBall (4)
% delay (510)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (500)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (4)
% delay (750)
% BallControl.introduceNewBall (4)
% delay (150)
% BallControl.introduceNewBall (3)
% delay (150)
% BallControl.introduceNewBall (2)
% delay (150)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (4)
% delay (500)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (3)
% delay (750)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% delay (500)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (4)
% delay (750)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (750)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (750)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (1)
% delay (750)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (1)
% delay (500)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (3)
% BallControl.introduceNewBall (4)
% BallControl.introduceNewBall (1)
% delay (750)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (400)
% BallControl.introduceNewBall (1)
% BallControl.introduceNewBall (2)
% BallControl.introduceNewBall (3)
% delay (500)
% BallControl.introduceNewBall (1)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (2)
% delay (250)
% BallControl.introduceNewBall (3)
% delay (250)
% BallControl.introduceNewBall (4)
% delay (250)
% BallControl.introduceNewBall (4)
