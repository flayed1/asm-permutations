# asm-permutations
## The problem
The objective was to determine whether a binary file contained correct zero-separated permutations of a subset of {1,...,255}.  
There was one twist: the program was supposed  to be as fast as possible.  

## The solution
I came up with a number of fun ideas to optimize the code.  
The general idea was to use only registers whenever possible.
To minimize the number of syscalls I used a buffer that stored results of read syscall.  
To minimize the number of memory hits to the buffer, I used the RBX register as a temporary buffer to store 8 byes, process the lowest 8 bits and then right shift to move to the next byte.  
Other optimizations included loop unrolling to cut the number of jumps.    
One idea I hadn't managed to implement was creating a jump table that would replace expensive 'switches' with cases from 0 to n.

## Phyrric victory
All this allowed me to hit a pretty good result of 1.9s on the largest test we've had,  which was 0.2s faster than the exemplary solution.  
However, there was one small problem. That was the time on the first run. If the second solution was run again on the same machine, it would score a ridiculous time of 0.230s, while mine stayed roughly the same.   
I managed to find that solution as well. Frankly, it didn't require so much register jugglery and used a lot of memory.  
That was disappointing. I found it a lot less creative and less fun to write, but the results were, indeed, impressive. And the code was a lot cleaner.
