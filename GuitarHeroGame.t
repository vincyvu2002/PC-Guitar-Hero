setscreen ("graphics:max;max,offscreenonly")

var L1, L2, L3, L4, MY1, MY2, MY3, MY4, Random : int
var MY : array 1 .. 10000 of int
var Lines : array 1 .. 4 of int
var Colors : array 1 .. 4 of int
Lines (1) := 543
Lines (2) := 629
Lines (3) := 715
Lines (4) := 801
Colors (1) := black
Colors (2) := red
Colors (3) := green
Colors (4) := yellow

class Ball
    export var Y, var Line, var Color
    var Y : int
    var Line : int
    var Color : int
end Ball

function CreateNewBall (line : int, color : int) : pointer to Ball
    var ret : pointer to Ball
    new Ball, ret
    ret -> Y := 625
    ret -> Line := line
    ret -> Color := color
    result ret
end CreateNewBall

procedure MoveBall (var ball : pointer to Ball)
    ball -> Y := ball -> Y - 2
end MoveBall

type LineOfBalls:
    record
	balls : array 1 .. 2 of pointer to Ball
    end record

monitor BallControl
    import Ball, CreateNewBall, Lines, Colors, MoveBall, LineOfBalls
    export destroyBall, introduceNewBall, drawAndMoveBalls, initialise
    var lineOfBalls : array 1 .. 4 of LineOfBalls

    procedure initialise ()
	for l : 1 .. 4
	    for i : 1 .. 2
		lineOfBalls (l).balls (i) := nil
	    end for
	end for
    end initialise

    procedure destroyBall (whichLine : int, whichBall : int)
	if lineOfBalls (whichLine).balls (whichBall) not= nil then
	    free Ball, lineOfBalls (whichLine).balls (whichBall)
	    lineOfBalls (whichLine).balls (whichBall) := nil
	end if
    end destroyBall

    procedure introduceNewBall (whichLine : int)
	for i : 1 .. 2
	    if lineOfBalls (whichLine).balls (i) = nil then
		lineOfBalls (whichLine).balls (i) := CreateNewBall (Lines (whichLine), Colors (whichLine))
		return
	    end if
	end for
    end introduceNewBall

    procedure drawAndMoveBalls
	for l : 1 .. 4
	    for b : 1 .. 2
		if lineOfBalls (l).balls (b) not= nil then
		    Draw.FillOval (lineOfBalls (l).balls (b) -> Line, lineOfBalls (l).balls (b) -> Y, 25, 25, lineOfBalls (l).balls (b) -> Color)
		    MoveBall (lineOfBalls (l).balls (b))
		    if lineOfBalls (l).balls (b) -> Y < 0 then
			free Ball, lineOfBalls (l).balls (b)
			lineOfBalls (l).balls (b) := nil
		    end if
		end if
	    end for
	end for
    end drawAndMoveBalls

end BallControl

% balls (1) := CreateNewBall (543, black)
% balls (2) := CreateNewBall (629, red)
% balls (3) := CreateNewBall (715, green)
% balls (4) := CreateNewBall (801, yellow)

% NOTES:
% maxx = 1345
% maxy = 685

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

process UpdateView
    for i : 1 .. 5000
	BasOutline
	BallControl.drawAndMoveBalls ()
	View.Update
	delay (5)
    end for
    for b : 1 .. 4
	BallControl.destroyBall (b,1)
	BallControl.destroyBall (b,2)
    end for
end UpdateView

process song
    Music.PlayFile ("SNPNG.wav") %play a sound or music file
end song

BasOutline
fork song
%delay (7000)
BallControl.initialise ()

fork UpdateView
delay (7000)
BallControl.introduceNewBall (4)
delay (500)
BallControl.introduceNewBall (4)
BallControl.introduceNewBall (3)
delay (500)
BallControl.introduceNewBall (3)
delay (500)
BallControl.introduceNewBall (2)
delay (500)
BallControl.introduceNewBall (2)
