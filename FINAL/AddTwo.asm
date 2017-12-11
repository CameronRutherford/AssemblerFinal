; Description: Stacker game using only assembler
; Revision date: 12/11/2017
; By: Cameron Rutherford, Tristan Hildahl, Tyler Stitt

;For Irvine functions
INCLUDE Irvine32.inc

;C/C++ functions used in the program.
_kbhit PROTO C
getch PROTO C   

;A few constansts that really help with 
startWidth EQU 40
maxRight EQU 50				;this must be at least one bigger than startWidth
cursorMax EQU maxRight + 1
bufferSIZE EQU 3

.data

lagCheckLow WORD 2		;used to manipulate the speed at which the game updates
lagLow WORD 5
lagCheck WORD 5
lagCounter BYTE 0
lag BYTE 40

intromessage BYTE "Welcome To Stacker!                   High Score: ",0
EndMessage BYTE "GAME OVER!",0
message1 BYTE "You failed on level ",0
successMessage BYTE "New high score!",0

prevLeft BYTE -1		;used to store the block's position on the previous level.
prevRight BYTE -1		;set to -1 to make the first check easy

oldLeft BYTE 0			;both are used to store the position of the block one "tick" beforehand
oldRight BYTE 0

currentLeft BYTE 0		;all are used to store the block's current properties
currentRight BYTE startWidth
CurrentWidth BYTE startWidth
velocity BYTE 1
currentY BYTE 1
currentColor BYTE 1

filename BYTE "highscore.txt",0		;Things used for the file I/O
buffer BYTE bufferSIZE DUP(?)
highScore BYTE ?
fileHandle DWORD ?

.code
;---------------------------------------------------------
updateHighScore PROC
;
; Checks to see if the current high score is a new high score,
; If it is a new highscore, then update the high score and display a message,
; Otherwise exit the whole program and return control to the OS.
; Returning control here was necessary for some reason as the ret command
; from this function seemed to break the program.
; Receives:	The current high score from highScore and the current score from currentY
;			Gets the file handle from the predefined filename data
; Returns: nothing
; Requires: nothing
;---------------------------------------------------------
	mov al, currentY
	sub al, 2			;Need to sub 2 from current Y to have consistency with what is displayed as your "score"
	mov ah, highScore
	cmp al, ah			;Compare your score to the current high score
	jle unlucky			;If your score wasn't high enough, end the program. Otherwise update the high score 
	mov highScore, al	;Store the new highscore
	mov edx, OFFSET successMessage		
	call WriteString		;Output the sucess message
	call crlf

	;The goal of this loop is to store the string version of the high score into buffer
	;Due to there not being an int to string function, this nested loop effectively assumes
	;the lowest possible high score is 10 and the highest is 100, and counts up from there 
	;to 100 constantly checking to see if the scores match. Once they do, it jumps out of the loops.

 	mov buffer[0], 030h	;Initialize the first digit to 0
L1:
	mov buffer[1], 030h	;Initialize the second digit to 0
	mov ecx, 10			;Count through from 0-9
	L2:
		push ecx		;This is recquired to maintain the loop counter
		mov edx, OFFSET buffer
		mov ecx, bufferSIZE
		call ParseDecimal32		;Convert the current number we are checking to a decimal
		cmp al, highScore		;See if we are at the high score
		je foundHigh			;If we have found it, get out of here
		inc buffer[1]			;Otherwise keep counting
		pop ecx
	loop L2
	inc buffer[0]
jmp L1

	;Now that we have the string version of the high score...

foundHigh:

	mov buffer[2], 0	;make sure it is null terminating

	;Write the new high score to the file

	mov	edx, OFFSET filename	
	call CreateOutputFile
	mov fileHandle, eax
	mov edx, OFFSET buffer
	mov ecx, bufferSIZE
	call WriteToFile
	mov eax, fileHandle
	call CloseFile

	;Do this regardless of if there is a new high score or not

	;This is the solution we came up with to avoid our program crashing each time the game ended
	;By exiting the whole program here, we avoided the issue and still maintained desirable behaviour

	;This loop effectively waits for the user to press a button to end the program, as otherwise the program quits instantly
unlucky:
	call _kbhit
	cmp eax, 0
	jne unlucky


	INVOKE exitProcess, 0	;Exit the whole program.
	ret						;This line is never hit.
updateHighScore ENDP
;---------------------------------------------------------
displayCurrentHighScore PROC
;
; Outputs the current high score to the screen and modifies the high score
; memory to contain the current high score for later use.
; Receives:	Gets the file handle from the predefined filename data
; Returns: nothing
; Requires: nothing
;---------------------------------------------------------
	
	;Open the file and read from it
	mov	edx,OFFSET filename 
	call OpenInputFile 
	mov fileHandle, eax
	mov edx, OFFSET buffer
	mov ecx, bufferSIZE
	call ReadFromFile

	;Convert the string stored into an integer
	mov edx, OFFSET buffer
	mov ecx, bufferSIZE
	call ParseDecimal32

	mov highScore, al	;Store the high score
	call WriteDec		;Output the high score
	mov eax, fileHandle	
	call CloseFile		;Close the file
	call crlf
	ret
displayCurrentHighScore ENDP


;---------------------------------------------------------
GameOver PROC
;
; Outputs the game over message
; Receives:	nothing
; Returns: nothing
; Requires: dh to have current y already in it, which it
;			does when the function is called.
;---------------------------------------------------------
	mov dl, 0
	call Gotoxy	;Go to the right place in the screen - bottom left corner
	call crlf	;endl

	mov  edx,OFFSET EndMessage	;cout << "GAME OVER" << endl;
    call WriteString 
	call crlf

	mov  edx,OFFSET message1	;cout << "You failed on level " << currentY - 1 <<  endl;
	call WriteString
	mov al, currentY
	dec al
	call WriteDec
	call crlf

	ret
GameOver ENDP


;---------------------------------------------------------
updateSpeed PROC
;
; Manipulates the lag variable in a specific way to make the game
; speed up at a faster rate over time, whilst also having a hard floor
; in terms of both the speed of the game and the rate of change.
; Receives: global variables
; Returns: modivied global variables
; Requires: nothing
;---------------------------------------------------------
	pushad

	inc lagCounter
	movzx eax, lagCounter
	sub ax, lagCheck	;Check to see if we have passed the point at which the speed needs to be changed
	jnz neverMind		;If the speed doesn't need to be changed, skip the following code and exit the function

	mov lagCounter, 0	;Reset the lag counter
	mov al, lag			;Decrement lag by 5
	sub al, 5
	cmp ax, lagLow		;If the lag is below the pre-determined lowest lag,
	cmovb ax, lagLow	;Hard reset it back to the lowest possible
	mov lag, al			;Re-store lag into memory
	dec lagCheck		;Increase the rate of change

	movzx ebx, lagCheck	;Check to see if the lag check is below the pre-determined lowest
	cmp bx, lagCheckLow
	cmovb bx, lagCheckLow	;Set it to the lowest if it is
	mov lagCheck, bx		;Re-store lagCheck once done

neverMind:
	popad
	ret
updateSpeed ENDP

;---------------------------------------------------------
fancyColor PROC
;
; Used to set the color to a different color depending on what
; current color is. Since current color is updated after every new line,
; the function makes it so every color excluding black is cycled through.
; Receives: global variables
; Returns: the text color set to be something consistent with the currentColor
; Requires: nothing
;---------------------------------------------------------
	pushad
GoOn:
	mov edx, 0					; Full disclosure, I still do not fully understand how this works
	movzx eax, currentColor		; This being the div instruction. But it does.
	mov ecx, 01h				
	div ecx
	mov dl, al					;edx has the result of the division.

	shl al, 4					;Do some bit shifting magic to ensure the color is properly in al.
	mov ah, dl
	shr ax, 4

	cmp al, 0					;If we have got to black, go to the next color and try again.
	je ChangeColor

	call setTextColor			;Set the text color and exit the function

	popad
	ret

ChangeColor:
	inc currentColor
	jmp GoOn

fancyColor ENDP



asmMain PROC C

	;Write the intro message and display the current high score.
	call Clrscr
	mov  edx,OFFSET intromessage
    call WriteString 
	call displayCurrentHighScore
	call crlf

	;The "start" of the infinite loop that the game runs on until you lose...
	;This is jumped to every time a new level is successfully reached.

reDrawBlock:					;Draw the block, wherever it is, at the start of each level.

	mov al, currentLeft			;Do some arithmetic to ensure that CurrentRight is correct
	add al, CurrentWidth		;Since the block shrinks in size, this is necessary to avoid incorrect starting sizes
	mov CurrentRight, al

	mov ecx, 0					;Set up the loop counter to draw every character in the block
	mov cl, CurrentWidth
	inc cl

	mov dl, currentLeft			;Do this outside the loop to since we are drawing from left to right, we never have to reset these.
	mov dh, currentY
	call Gotoxy
L1:						;Draw the block from left to right at the start
	call fancyColor		;Set the color based on the currentY
	mov al, '*'
	call WriteChar
	Loop L1

	mov eax, white + (black * 16)		;Make sure to endl with black and white because otherwise each carriage return looks weird
	call SetTextColor
	call crlf

	;This line is jumped to every time the keyboard is polled to see if a button was pressed
Move:

	;This block outputs the number of the current level at the end of the line
	mov dl, cursorMax
	mov dh, currentY
	call Gotoxy
	mov eax, white + (black * 16)
	call SetTextColor
	mov al, currentY
	call WriteDec

	;Wait for a bit while the current image is displayed..
	movzx eax, lag
	call Delay
	call _kbhit			;Poll for a button being pressed
	cmp eax, 0
	jne ButtonPressed	;if a button was pressed, go to the update section of the code. Otherwise continue

	;This line is jumped to if the block is needed to be moved without polling for keyboard input

ForceMove:

	;Check to see what direction the block is moving in
	mov al, velocity
	cmp al, 1
	jne Backward	;If the block is moving backward jump to the appropriate section of code
	
	;Otherwise if it is moving forward...

	;Check to see if it is at the max size that is predetermined.
	mov al, currentRight
	cmp currentRight, maxRight
	je Reverse		;If it is, change the direction the block is moving

	;Otherwise update the block normally moving forward

	;Update the currentRight based on oldRight, knowing al has currentRight
	mov oldRight, al
	inc al
	mov currentRight, al

	;Update the currentLeft based on the oldLeft
	mov ah, currentLeft
	mov oldLeft, ah
	inc ah
	mov currentLeft, ah

	;Since the block is moving forward, we need to erase the trailing block, and print the new leading block

	;Erasing the trailing block...
	mov dl, oldLeft
	mov dh, currentY
	call Gotoxy
	mov eax, black + (black * 16)
	call SetTextColor
	mov al, '*'			;NB: This character can be anythign because the background and foreground are the same.
						;	 It has been left as this everywhere as confirmation things are working as intended.
	call WriteChar

	;Printing the new leading block
	mov dl, currentRight
	mov dh, currentY
	call Gotoxy
	call fancyColor
	mov al, '*'
	call WriteChar

	;Start the polling again for key input and whatnot
	jmp Move

	;Do everything similar for moving backward, with a few things flipped.
Backward:

	;Check to see if it is at the min size that is predetermined.
	mov al, currentLeft
	cmp currentLeft, 0
	je Reverse		;If it is, change the direction the block is moving

	;Otherwise update the block normally moving backward

	;Update the currentLeft based on oldLeft, knowing al has currentLeft
	mov oldLeft, al
	dec al
	mov currentLeft, al

	;Update the currentRight based on the oldRight
	mov ah, currentRight
	mov oldRight, ah
	dec ah
	mov currentRight, ah

	;Since the block is moving backward, we need to erase the trailing block, and print the new leading block

	;Erasing the trailing block...
	mov dl, oldRight
	mov dh, currentY
	call Gotoxy
	mov eax, black + (black * 16)
	call SetTextColor
	mov al, '*'
	call WriteChar

	;Printing the new leading block
	mov dl, currentLeft
	mov dh, currentY
	call Gotoxy
	call fancyColor
	mov al, '*'
	call WriteChar

	;Start the polling again for key input and whatnot
	jmp Move

	;This is jumped to when the direction needs reversing
Reverse:

	mov al, velocity	;Since velocity is either +/- 1, we simply neet to not al to flip it!
	not al				;So flip it!
	mov velocity, al
	jmp ForceMove		;Jump to ForceMove as we don't need to poll for input again when the direction changes

	;This is jumped to every time the player presses a button
ButtonPressed:

	;This small "loop" here makes it so the input buffer cannot be flooded to cheat the game
	;It can still kind of be done to an extent, however this makes it extremely less effective.
	call getch		;used to get rid of one of the inputs in the input buffer
	call _kbhit
	cmp eax, 0
	jne ButtonPressed	;If a button was pressed again, clear the input buffer and try again

	mov al, prevLeft
	inc al
	jz Nothing	;This jump is successfully executed after the first button press to make sure everything initializes properly.
				;i.e. This allows for the user to determine where the initial base block is placed, avoiding using a pre-set

	dec al	;reset al after the check ^
	cmp al, currentLeft ;Compare the prevLeft to currentLeft
						;if the prevLeft is greater than current left (i.e. the left hand side is overhanging...),
	jg ELeft			;then jump to the section that erases the left hanging blocks

	mov al, prevRight		;Otherwise check to see if prevRight < currentRight (i.e the right hand side is overhanging...)
	cmp al, currentRight
	jl ERight				;if it is, then jump to the section that erases the right hanging blocks

	jmp Nothing				;Otherwise nothing must be overhanging, so do nothing!

ELeft:						;Erase the left hand side of the block that is overhanging
							;al has prevLeft

	sub al, currentLeft		;Find the change in width needed
	mov dl, CurrentWidth
	sub dl, al				;Subtract that change from the currentWidth to get a "newWidth"
	mov CurrentWidth, dl

	mov ecx, 0				;Set the loop counter and go to the "correct" spot to start erasing
	mov cl, al
	mov dl, currentLeft		;Since we are erasing from right to left, we only need to set the position once
	mov dh, currentY
	call Gotoxy
	
	;Erase all the hanging pieces
L2:
	mov eax, black + (black * 16)
	call SetTextColor
	mov al, '*'
	call WriteChar
	Loop L2

	;Since the prevLeft doesn't need to be changed as it was "reset" by cleaning up the overhang,
	;We only need to update the right side information
	mov al, currentRight
	mov prevRight, al
	jmp Done		;Update to the next level!


	;A very similar process is done for erasing the right overhang, just kind of flipped.
ERight:
	mov al, currentRight
	sub al, prevRight
	mov dl, CurrentWidth
	sub dl, al
	mov CurrentWidth, dl
	mov ecx, 0
	mov cl, al
	mov dl, currentRight
	mov dh, currentY
	call Gotoxy
L3:
	mov eax, black + (black * 16)
	call SetTextColor
	mov al, '*'
	call WriteChar
	dec dl
	call Gotoxy			;Since we are erasing from right to left, we do need to manipulate the coordinates each time...
	Loop L3

	mov al, currentLeft
	mov prevLeft, al
	jmp Done

	;This is esecuted when the block was in the perfect position and nothing needed to be changed!
	;There is still code here to make sure that initially the prevRight and prevLeft are set correctly - a small inefficiency
Nothing:
	mov al, currentRight
	mov prevRight, al
	mov al, currentLeft
	mov prevLeft, al

	;This is called when we need to update to the next level
Done:
	;update the y value, the speed and the color
	inc CurrentY
	call UpdateSpeed
	inc CurrentColor

	;endl
	mov eax, white + (black * 16)		;Make sure to endl with black and white because otherwise each carriage return looks weird
	call SetTextColor
	call crlf

	;check to see if the current width is now <= 0. If it is jump to the game over section below
	mov al, CurrentWidth
	cmp al, 0
	jl GameDone
jmp reDrawBlock	;otherwise move onto the next level and start the loop all over again!
GameDone:		;finish the game and call the updateHighScore proc.
	call GameOver
	call updateHighScore
	ret
asmMain ENDP
END