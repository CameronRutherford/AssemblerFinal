/*******************************************************************************************
*
*Title:			Conio.h wrapper
*
*Author:		Matthew Bell
*
*Purpose:		Illustrates how to "wrap", for lack of a better term, C/C++ library functions.
*				See pp. 574-583 in Irvine for details.
*
*Last Update:	18 November 2016
*
*******************************************************************************************/

#include<conio.h>
using namespace std;

extern "C" void asmMain();	// <==	Have to invoke your assembler code from the C++ program, so
					 		//		define it as an external. Have to define your "main" assembler
							//		procedure to use the C/C++ call specifications instead of STDCALL

int main()
{
	asmMain();	// <== Call your assembler program here.
	return 0;
}
