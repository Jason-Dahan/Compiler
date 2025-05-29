%{
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "cpl.tab.h"
int line=1; //Used to show which line has the error
%}

%option noyywrap
%x COMMENT
%%

"break" return BREAK;

"case" return CASE;

"default" return DEFAULT;

"else" return ELSE;

"float" return FLOAT;

"if" return IF;

"input" return INPUT;

"int" return INT;

"output" return OUTPUT;

"switch" return SWITCH;

"while" return WHILE;

"(" return '(';

")" return ')';

"{" return '{';

"}" return '}';

"," return ',';

":" return ':';

";" return ';';

"=" return '=';

"!" return NOT;

"&&" return AND;

"||" return OR;

[a-zA-Z][0-9a-zA-Z]* {
			int i;
			int isNum=1;
			int isT=0;
			for(i=0;yytext[i];i++)
			{
				if(i==0 && yytext[i]=='t')//Checks if the first letter is t
					isT=1;
				if(i>0 && !isdigit(yytext[i])) //Checks if not all of the rest of the letters are numbers
					isNum=0;
				if(isalpha(yytext[i])) //Changes all letters to lower case
					yytext[i]=tolower(yytext[i]);
			}
			if(isT && isNum) //It's a temp format
				fprintf (stderr, "can't use temp names\n");
			strcpy(yylval.name,yytext);
			return ID;
		     }

[1-9][0-9]* {
			yylval.ival = atof(yytext); //Also written as float but will be handled in bison
			return NUM;
	    }

[1-9][0-9]*\.[0-9]*[1-9] {
			  	 yylval.ival = atof(yytext);
			 	 return NUM;
			 }

"*" {yylval.mulop=MULT;return MULOP;}

"/" {yylval.mulop=DIV;return MULOP;}

"+" {yylval.addop=ADD;return ADDOP;}

"-" {yylval.addop=SUB;return ADDOP;}

"==" {yylval.compop=EQ;return RELOP;}

"!=" {yylval.compop=NEQ;return RELOP;}

"<" {yylval.compop=LT;return RELOP;}

">" {yylval.compop=GT;return RELOP;}

"<=" {yylval.compop=LTE;return RELOP;}

">=" {yylval.compop=GTE;return RELOP;}

"static_cast<int>" {yylval.ctype=INTCAST;return CAST;}

"static_cast<float>" {yylval.ctype=FCAST;return CAST;}

"/*"	{BEGIN(COMMENT);}

<COMMENT>. {}

<COMMENT>"*/" {BEGIN(0);}

\n {line++;}

[ \r\t]+ {}

. {fprintf (stderr, "line %d: unrecognized token %c\n",
                               line, yytext[0]);}

%%
