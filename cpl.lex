%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cpl.tab.h"
%}

%option noyywrap yylineno
%x COMMENT

%%

"/*"               { BEGIN(COMMENT); }
<COMMENT>"*/"      { BEGIN(INITIAL); }
<COMMENT>.|\n      { /* Ignore everything inside comments */ }
<COMMENT><<EOF>>   { fprintf(stderr, "Error: Unclosed comment at line %d\n", yylineno); exit(1); }

"break"     return BREAK;
"case"      return CASE;
"default"   return DEFAULT;
"else"      return ELSE;
"float"     return FLOAT;
"if"        return IF;
"input"     return INPUT;
"int"       return INT;
"output"    return OUTPUT;
"switch"    return SWITCH;
"while"     return WHILE;

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

[a-zA-Z][0-9a-zA-Z_]* {
    yylval.var = (struct variable*)malloc(sizeof(struct variable));
    strcpy(yylval.var->str, yytext);
    return ID;
}

0|[1-9][0-9]* {
    yylval.numtype = (struct numinfo*)malloc(sizeof(struct numinfo));
    yylval.numtype->type = INTEGER;
    yylval.numtype->ival = atoi(yytext);
    return NUM;
}

(0|[1-9][0-9]*)\.[0-9]+ {
    yylval.numtype = (struct numinfo*)malloc(sizeof(struct numinfo));
    yylval.numtype->type = FLOATPOINT;
    yylval.numtype->fval = atof(yytext);
    return NUM;
}

"*" { yylval.op = MULT; return MULOP; }
"/" { yylval.op = DIV;  return MULOP; }
"+" { yylval.op = ADD;  return ADDOP; }
"-" { yylval.op = SUB;  return ADDOP; }

"==" { yylval.op = EQ;  return RELOP; }
"!=" { yylval.op = NEQ; return RELOP; }
"<"  { yylval.op = LT;  return RELOP; }
">"  { yylval.op = GT;  return RELOP; }
"<=" { yylval.op = LTE; return RELOP; }
">=" { yylval.op = GTE; return RELOP; }

"static_cast<int>"   { yylval.ctype = INTCAST; return CAST; }
"static_cast<float>" { yylval.ctype = FCAST; return CAST; }

[ \t\r\n]+ { /* Skip whitespace */ }

. { fprintf(stderr, "Lexical Error: Unrecognized token '%c' at line %d\n", yytext[0], yylineno); }

%%