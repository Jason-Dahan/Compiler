
%code{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "hashmap.h"
#include "helper.h"
#include <float.h>

int tempcount=0; //for counting temps
int labelcount=0; //for counting labels
int linenum=1; //counts the linenumber
extern FILE* yyout; //for writing the temp file

extern int yylex (void);
void yyerror (const char *s);

hashmap_map* vars= NULL; //Symbol table
temp_node *temp_head = NULL; //Temp list
break_node *break_head=NULL; //Head of break list
break_node *break_tail=NULL; //Tail of break list
case_node *case_head=NULL; //Head of case list
case_node *case_tail=NULL; //Tail of case list
int *label_head=NULL; //Label table
int size=0; //Size of table
char saved_name[20];
}

%code requires {
    enum compoperator {EQ, NEQ, LT, GT, LTE, GTE};
    enum addoperator {ADD,SUB};
    enum muloperator {MULT, DIV};
    enum caster {INTCAST, FCAST };
}

%union {
  enum addoperator addop;
  enum muloperator mulop;
  enum compoperator compop;
  enum caster ctype;
  int numtype;
  float ival;
  char name[80];
} 

%token FLOAT
%token <name> ID
%token INPUT
%token OUTPUT
%token IF
%token WHILE
%token SWITCH
%token CASE
%token <ival> NUM
%token DEFAULT
%token BREAK
%token OR
%token AND
%token NOT
%token <compop> RELOP
%token <addop> ADDOP
%token <mulop> MULOP
%token <ctype> CAST
%token INT
%token ELSE
%token '('
%token ')'
%token '{'
%token '}'
%token ','
%token ':'
%token ';'
%token '='
%type <numtype> type
%type <name> expression boolexpr boolterm boolfactor term caselist factor

%%
program:{break_tail=break_head; case_tail=case_head;vars=hashmap_new();}
	declarations stmt_block 
	 {
	  	hashmap_free(vars); //Frees all structures besides the ones we need for after
	  	free_temp_list(&temp_head);
	  	free_break_list(&break_head,&break_tail);
	  	fprintf(yyout,"HALT\n"); //ends with HALT
	  	linenum++;
	 	fprintf(stderr,"This program was written by: Jason Sneag\n");
	 };

declarations: 
	    declarations declaration {}
	| {};

declaration:
		 idlist ':' type ';' {
					temp_node * temp_curr=temp_head;
					while(temp_curr!=NULL) //Go through all the nodes in the temp list
					{
						if(get(vars, temp_curr->name)!=-3) //Variable name already exists in symbol table from previous declaration
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"The variable was declared already.\n");
							remove(saved_name);
							exit(1);
						}
						if(set(vars,temp_curr->name,$3)==-1)//Add to variable list
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Problem adding variable to list.\n");
							remove(saved_name);
							exit(1);
						}
						temp_curr=temp_curr->next;
					}
					free_temp_list(&temp_head); //Free the temp list(Might be used again).
				};	

type: INT   {$$ = 0;}
	|FLOAT {$$ = 1;};

idlist: idlist ',' ID {
			if(get(vars,$3)!=-3) //Variable already declared here
			{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"The variable was declared already.\n");
				remove(saved_name);
				exit(1);
			}
			if(add_temp_list(&(temp_head),$3)==-1) //Adds to temp list
			{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"Problem adding temp to list.\n");
				remove(saved_name);
				exit(1);
			}	
		}
	|ID {
			if(get(vars,$1)!=-3) //Checks if declared already
			{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"The variable was declared already.\n");
				remove(saved_name);
				exit(1);
			}
			if(add_temp_list(&(temp_head),$1)==-1) //Adds to temp list
			{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"Problem adding temp to list.\n");
				remove(saved_name);
				exit(1);
			}
		};
stmt: assignment_stmt {}
	|input_stmt {}
	|output_stmt {}
	|if_stmt {}
	|while_stmt {}
	|switch_stmt {}
	|break_stmt {}
	|stmt_block {};
	

assignment_stmt: ID '=' expression ';' {
					int var_type;
					int exp_type;
					if((var_type=get(vars,$1))==-1) /*Didnt find the var name in var list*/
					{
						hashmap_free(vars);
	  					free_temp_list(&temp_head);
	  					free_break_list(&break_head,&break_tail);
	  					free_case_list(&case_head,&case_tail);
						free_label_table(label_head,size);
						fprintf(stderr,"The variable wasn't declared.\n");
						remove(saved_name);
						exit(1);
					}
					exp_type=get(vars,$3); //The expression was definitely added since we added the temp var/
					if(var_type==0 && exp_type==1) /*Assign float to int */
					{
	  						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Cant assign Integer to float.\n");
							remove(saved_name);
							exit(1);
						}
					}
					if(var_type==1 && exp_type==0) /*Assign int to float */
					  {
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						fprintf(yyout,"ITOR %s %s \n", temp, $3); /*Cast to float before*/
						linenum++;
						if(set(vars,temp, 1)==-1) //Add var to sym table
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Problem adding variable to list.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RASN %s %s \n", $1, temp);
						linenum++;
					  }
					if(var_type==0 && exp_type==0)	/*Assign int to int*/
					{
						fprintf(yyout,"IASN %s %s \n", $1, $3);
						linenum++;
					}
					if(var_type==1 && exp_type==1)	/*Assign float to float*/
					{
						fprintf(yyout,"RASN %s %s \n", $1, $3);
						linenum++;
					}
					 };

input_stmt: INPUT '(' ID ')' ';' {
					int var_type=get(vars,$3);
					if(var_type==-3) //ID wasnt declared
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"ID wasn't declared.\n");
							remove(saved_name);
							exit(1);
					}
					else 
					{	
						if(var_type==0) //Integer
						{
							fprintf(yyout,"IINP %s \n", $3);
							linenum++;
						}
						else //Float
						{
							fprintf(yyout,"RINP %s \n", $3);
							linenum++;
						}
					}
				};

output_stmt: OUTPUT '(' expression ')' ';'
			{ 	
			  int var_type =get(vars,$3); //We added expr no need to check
			  if(var_type==0) //Integer
			  {
				fprintf(yyout,"IPRT %s \n", $3);
				linenum++;
			  }
			  else //Float
			  {
				fprintf(yyout,"RPRT %s \n", $3);
				linenum++;
			  }
			};

if_stmt: IF
	'(' boolexpr ')'
	{
		char label[labelcount+2];
		gen_label(label,&labelcount);
		fprintf(yyout,"JMPZ %s %s \n", label, $3); //If it isn't then jump to the else
		linenum++;
		strcpy($<name>$,label);
	}
	stmt	
		{char label[labelcount+2]; //exit label for if
		 gen_label(label,&labelcount);
		 fprintf(yyout,"JMP %s\n",label);
		 linenum++;
		 strcpy($<name>$,label);}
	ELSE 
	{
		fprintf(yyout,"%s: ",$<name>5); //start of else
		if(add_label_table(&label_head,$<name>5,&size,linenum)==-1)
			{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"Issue adding label to label list.\n");
				remove(saved_name);
				exit(1);
			}
	}
	stmt 
	{
		fprintf(yyout,"%s: ",$<name>7); //end of else
		if(add_label_table(&label_head,$<name>7,&size,linenum)==-1)
		{
			hashmap_free(vars);
	  		free_temp_list(&temp_head);
	  		free_break_list(&break_head,&break_tail);
	  		free_case_list(&case_head,&case_tail);
			free_label_table(label_head,size);
			fprintf(stderr,"Issue adding label to label list.\n");
			remove(saved_name);
			exit(1);
		}
	};

while_stmt: WHILE {
		char label[labelcount+2]; //repeat label
		gen_label(label,&labelcount);
		fprintf(yyout,"%s: ",label); //Print the repeat label before the check
		if(add_label_table(&label_head,label,&size,linenum)==-1)
		{
			hashmap_free(vars);
	  		free_temp_list(&temp_head);
	  		free_break_list(&break_head,&break_tail);
	  		free_case_list(&case_head,&case_tail);
			free_label_table(label_head,size);
			fprintf(stderr,"Issue adding label to label list.\n");
			remove(saved_name);
			exit(1);
		}
		strcpy($<name>$,label);
		}
'(' boolexpr ')'{
		char label[labelcount+2];
		gen_label(label,&labelcount); //exit label
		fprintf(yyout,"JMPZ %s %s \n", label, $4); //If boolexpr isn't true then jump to exit
		linenum++;
		if(add_break_list(&break_head,&break_tail,label)==-1)
		{
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"Issue adding break list.\n");
				remove(saved_name);
				exit(1);
		}
		strcpy($<name>$,label);
} stmt {
	fprintf(yyout,"JUMP %s\n",$<name>2); //Jump to the repeat label
	linenum++;
	fprintf(yyout,"%s: ",$<name>6);  //Write the exit label
	if(add_label_table(&label_head,$<name>6,&size,linenum)==-1)
	{
			hashmap_free(vars);
	  		free_temp_list(&temp_head);
	  		free_break_list(&break_head,&break_tail);
	  		free_case_list(&case_head,&case_tail);
			free_label_table(label_head,size);
			fprintf(stderr,"Issue adding label to list.\n");
			remove(saved_name);
			exit(1);
	}
	remove_break_list(&break_head,&break_tail); //We are done with the while stmt so we can remove the exit label from the list.
 } ;

switch_stmt:{	
		char endlabel[labelcount+2];
		gen_label(endlabel,&labelcount);
		add_break_list(&break_head,&break_tail,endlabel);
		strcpy($<name>$,endlabel);
		} 
		SWITCH caselist DEFAULT ':'{ 
						add_case_list(&case_head,&case_tail,linenum);
					   }
		stmtlist '}'
		{
		 fprintf(yyout,"%s: ",$<name>1);
		 if(add_label_table(&label_head,$<name>1,&size,linenum)==-1)
		{
			hashmap_free(vars);
	  		free_temp_list(&temp_head);
	  		free_break_list(&break_head,&break_tail);
	  		free_case_list(&case_head,&case_tail);
			free_label_table(label_head,size);
			fprintf(stderr,"Unable to locate space for label.\n");
			exit(1);
		}
		 if(remove_break_list(&break_head,&break_tail)==-1) //remove the endlabel since we are done.
		 {
				hashmap_free(vars);
	  			free_temp_list(&temp_head);
	  			free_break_list(&break_head,&break_tail);
	  			free_case_list(&case_head,&case_tail);
				free_label_table(label_head,size);
				fprintf(stderr,"The break list was empty.\n");
				remove(saved_name);
				exit(1);
		}
		};
caselist:
	caselist CASE NUM ':' {
				if($3!=(int)$3) //NUM is not an Integer
				{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Num isn't an Integer.\n");
					remove(saved_name);
					exit(1);
				}
				if(add_case_list(&case_head,&case_tail,linenum)==-1)
				{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue adding case to list.\n");
					remove(saved_name);
					exit(1);
				}
				char temp[tempcount+2];
				gen_temp(temp,&tempcount);
				fprintf(yyout,"IEQL %s %s %d\n",temp,$1,(int)$3);
				linenum++;
				fprintf(yyout,"JMPZ %s %s\n", "C", temp);
				linenum++;
				}
	stmtlist {strcpy($$,$1);}
	| '(' expression ')' '{' CASE NUM ':'
				{
				if($6!=(int)$6) //NUM is not an Integer
				{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Num is not an Integer.\n");
					remove(saved_name);
					exit(1);
				}
				char temp[tempcount+2];
				gen_temp(temp,&tempcount);
				fprintf(yyout,"IEQL %s %s %d\n",temp,$2,(int)$6);
				linenum++;
				fprintf(yyout,"JMPZ %s %s\n", "C", temp);
				linenum++;
				} 
	stmtlist
				{ 
				   int exp_type=get(vars,$2);
				   if(exp_type==1) //Expression not an Integer
				{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Expression isn't an Integer in switch.\n");
					remove(saved_name);
					exit(1);
				}
				strcpy($$,$2);
				};

break_stmt: BREAK ';'{
			if(break_tail==NULL)
			{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Break not in while/switch segment.\n");
					remove(saved_name);
					exit(1);
			}
			fprintf(yyout,"JUMP %s\n",break_tail->label); //Jump to the exit label
			linenum++;
			};

stmt_block: '{' stmtlist '}' ;

stmtlist: stmtlist stmt {}
	| {};

boolexpr: boolexpr OR boolterm
		{ 
			char temp[tempcount+2];
			gen_temp(temp,&tempcount);
			if(set(vars,temp,0)==-1)
			{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue set variable in table.\n");
					remove(saved_name);
					exit(1);
			}
			fprintf(yyout,"IADD %s %s %s\n", temp, $1, $3); /*Add both answers*/
			linenum++;
			char temp2[tempcount+2];
			gen_temp(temp2,&tempcount);
			strcpy($$,temp2);
			if(set(vars,$$,0)==-1)
			{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue set variable in table.\n");
					remove(saved_name);
					exit(1);
			}
			fprintf(yyout,"INQL %s %s 0\n", $$, temp); /*If its not 0 then 1 or more are true*/
			linenum++;
		}
		
	|boolterm { strcpy($$,$1);};

boolterm: boolterm AND boolfactor
		{ 
			char temp[tempcount+2];
			gen_temp(temp,&tempcount);
			char temp2[tempcount+2];
			gen_temp(temp2,&tempcount);
			if(set(vars,temp,0)==-1)
			{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue set variable in table.\n");
					remove(saved_name);
					exit(1);
			}
			fprintf(yyout,"IADD %s %s %s\n", temp, $1, $3); /*Add both answers*/
			linenum++;
			strcpy($$,temp2);
			if(set(vars,$$,0)==-1)
			{
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue set variable in table.\n");
					remove(saved_name);
					exit(1);
			}
			fprintf(yyout,"IEQL %s %s 2\n", $$, temp); /*If its 2 then both are true*/
			linenum++;
		}
	|boolfactor { strcpy($$,$1); };

boolfactor: NOT '(' boolexpr ')'
		{ 
		 char temp[tempcount+2];
		 gen_temp(temp,&tempcount);
		 strcpy($$,temp);
		 if(set(vars,temp,0)==-1)
		 {
					hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"Issue set variable in table.\n");
					remove(saved_name);
					exit(1);
		}
		 fprintf(yyout,"IEQL %s %s 0\n", $$, $3);  /*if boolexpr is 0 then boolfactor is 1 if not then it is 1 then boolfactor is 0-meaning it does the "not" action */
		 linenum++;
		} 
	|expression RELOP expression
		{ 
		 int expr1_type = get(vars,$1);
		 int expr2_type = get(vars,$3);
		 switch ($2)
			{
			case EQ: if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp, &tempcount);
						strcpy($$,temp);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"REQL %s %s %s\n", $$, $1, $3); 
						linenum++;
					}
					else if(expr1_type==1 && expr2_type==0)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						linenum++;
			 			fprintf(yyout,"REQL %s %s %s\n", temp2, $1, temp); 
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"REQL %s %s %s\n", temp2,temp, $3);
						linenum++; 
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
		 			if(set(vars,temp,0)==-1)
					{
						hashmap_free(vars);
	  					free_temp_list(&temp_head);
	  					free_break_list(&break_head,&break_tail);
	  					free_case_list(&case_head,&case_tail);
						free_label_table(label_head,size);
						fprintf(stderr,"Issue set variable in table.\n");
						remove(saved_name);
						exit(1);
					}
					fprintf(yyout,"IEQL %s %s %s\n", $$, $1, $3); 
					linenum++;
				}
				  break;
				
			case GTE: if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RLSS %s %s %s\n", temp, $1, $3);  /*Do Less than*/
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp2, temp); /*Then do 'not' to the answer*/
						linenum++;
						strcpy($$,temp2);
						if(set(vars,$$,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(expr1_type==1 && expr2_type==0)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
						char temp3[tempcount+2];
						gen_temp(temp3,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3);
						linenum++;
			 			fprintf(yyout,"RLSS %s %s %s\n", temp2, $1, temp); 
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp3, temp2);
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						if(set(vars,temp3,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp3);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
						char temp3[tempcount+2];
						gen_temp(temp3,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"RLSS %s %s %s\n", temp2,temp, $3);
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp3, temp2);
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						if(set(vars,temp3,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp3);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					char temp2[tempcount+2];
					gen_temp(temp2,&tempcount);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
					fprintf(yyout,"ILSS %s %s %s\n", temp, $1, $3);
					linenum++;
					fprintf(yyout,"IEQL %s %s 0\n", temp2, temp); 
					linenum++;
					strcpy($$,temp2);
					if(set(vars,$$,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
				}
				  break;

			case LTE: if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RGRT %s %s %s\n", temp, $1, $3);  /*Do Greater than*/
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp2, temp); /*Then do 'not' to the answer*/
						linenum++;
						strcpy($$,temp2);
						if(set(vars,$$,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(expr1_type==1 && expr2_type==0)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
			 			char temp3[tempcount+2];
						gen_temp(temp3,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						linenum++;
			 			fprintf(yyout,"RGRT %s %s %s\n", temp2, $1, temp); 
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp3, temp2);
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						if(set(vars,temp3,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp3);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
						char temp3[tempcount+2];
						gen_temp(temp3,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"RGRT %s %s %s\n", temp2,temp, $3);
						linenum++;
						fprintf(yyout,"IEQL %s %s 0\n", temp3, temp2);
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						if(set(vars,temp3,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp3);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					char temp2[tempcount+2];
					gen_temp(temp2,&tempcount);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
					fprintf(yyout,"IGRT %s %s %s\n", temp, $1, $3);
					linenum++;
					fprintf(yyout,"IEQL %s %s 0\n", temp2, temp); 
					linenum++;
					strcpy($$,temp2);
					if(set(vars,$$,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
				}
				  break;
			case GT: if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						strcpy($$,temp);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RGRT %s %s %s\n", $$, $1, $3); 
						linenum++;
					}
					else if(expr1_type==1 && expr2_type==0)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						linenum++;
			 			fprintf(yyout,"RGRT %s %s %s\n", temp2, $1, temp); 
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"RGRT %s %s %s\n", temp2,temp, $3); 
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
		 			if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					fprintf(yyout,"IGRT %s %s %s\n", $$, $1, $3); 
					linenum++;
				}
				  break;

			case LT:if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						strcpy($$,temp);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RLSS %s %s %s\n", $$, $1, $3); 
						linenum++;
					}
					else if(expr1_type==1 && expr2_type==0)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3);
						linenum++; 
			 			fprintf(yyout,"RLSS %s %s %s\n", temp2, $1, temp); 
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"RLSS %s %s %s\n", temp2,temp, $3); 
						linenum++;
						if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
		 			if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					fprintf(yyout,"ILSS %s %s %s\n", $$, $1, $3); 
					linenum++;
				}
				  break;

			case NEQ: if(expr1_type==1 || expr2_type==1)
				{
					if(expr1_type==1 && expr2_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						strcpy($$,temp);
		 				if(set(vars,temp,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RNQL %s %s %s\n", $$, $1, $3); 
						linenum++;
					}
					else if(expr1_type==1 && expr2_type==0)
					{
			 			char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						linenum++;
			 			fprintf(yyout,"RNQL %s %s %s\n", temp2, $1, temp); 
						linenum++;
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
					else
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
						char temp2[tempcount+2];
						gen_temp(temp2,&tempcount);
		 				if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 			fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						linenum++;
			 			fprintf(yyout,"RNQL %s %s %s\n", temp2,temp, $3);
						linenum++; 
						if(set(vars,temp2,0)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						strcpy($$,temp2);
					}
				}
				else /*Both are 0S */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
		 			if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					fprintf(yyout,"INQL %s %s %s\n", $$, $1, $3); 
					linenum++;
				}
				  break;
		}
		};

expression:
	     expression ADDOP term
		{ 	
			int expr_type=get(vars,$1);
			int term_type=get(vars,$3);
			if ($2 == ADD)
                        {
				if(expr_type==1 || term_type==1)
				{
					if(expr_type==1 && term_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
			 			strcpy($$,temp);
						if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RADD %s %s %s\n", $$, $1, $3); 
			 			linenum++;
					}
					else if(expr_type==1 && term_type==0)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						 linenum++;
						 fprintf(yyout,"RADD %s %s %s\n", temp2, $1, temp); 
						 linenum++;
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(expr_type==0 && term_type==1)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						 linenum++;
						 fprintf(yyout,"RADD %s %s %s\n", temp2, temp, $3); 
						 linenum++;
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
				}
				else /*Neither are floats */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
					fprintf(yyout,"IADD %s %s %s\n", $$, $1, $3); 
			 		linenum++;
				}
			}
                  	 else /*Its SUB*/
		     	 {
				if(expr_type==1 || term_type==1)
				{
					if(expr_type==1 && term_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
			 			strcpy($$,temp);
						if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RSUB %s %s %s\n", $$, $1, $3); 
			 			linenum++;
					}
					else if(expr_type==1 && term_type==0)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						 linenum++;
						 fprintf(yyout,"RSUB %s %s %s\n", temp2, $1, temp);
						 linenum++; 
						 strcpy($$,temp2);
						if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(expr_type==0 && term_type==1)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						 linenum++;
						 fprintf(yyout,"RSUB %s %s %s\n", temp2, temp, $3); 
						 linenum++;
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
				}
				else /*Neither are floats */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
					}
					fprintf(yyout,"ISUB %s %s %s\n", $$, $1, $3); 
			 		linenum++;
				}
			}}
	|term { strcpy($$,$1); };

term: term MULOP factor
		{ 	
			int term_type=get(vars,$1);
			int fact_type=get(vars,$3);
			if ($2 == MULT)
                       {
				if(term_type==1 || fact_type==1)
				{
					if(term_type==1 && fact_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
			 			strcpy($$,temp);
						if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RMLT %s %s %s\n", $$, $1, $3); 
			 			linenum++;
					}
					else if(term_type==1 && fact_type==0)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						 linenum++;
						 fprintf(yyout,"RMLT %s %s %s\n", temp2, $1, temp);
						 linenum++; 
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(term_type==0 && fact_type==1)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $1); 
						 linenum++;
						 fprintf(yyout,"RMLT %s %s %s\n", temp2, temp, $3); 
						 linenum++;
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
				}
				else /*Neither are floats */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					fprintf(yyout,"IMLT %s %s %s\n", $$, $1, $3); 
			 		linenum++;
				}
			}
                    else /*Its DIV*/
		      {
				if(term_type==1 || fact_type==1)
				{
					if(term_type==1 && fact_type==1)
					{
						char temp[tempcount+2];
						gen_temp(temp,&tempcount);
			 			strcpy($$,temp);
						if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						fprintf(yyout,"RDIV %s %s %s\n", $$, $1, $3); 
			 			linenum++;
					}
					else if(term_type==1 && fact_type ==0)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $3); 
						 linenum++;
						 fprintf(yyout,"RDIV %s %s %s\n", temp2, $1, temp); 
						 linenum++;
						 strcpy($$,temp2);
						if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
					else if(term_type==0 && fact_type==1)
					{
						 char temp[tempcount+2];
						 gen_temp(temp,&tempcount);
						 char temp2[tempcount+2];
						 gen_temp(temp2,&tempcount);
						 if(set(vars,temp,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
						 fprintf(yyout,"ITOR %s %s\n", temp, $1);
						 linenum++; 
						 fprintf(yyout,"RDIV %s %s %s\n", temp2, temp, $3); 
						 linenum++;
						 strcpy($$,temp2);
						 if(set(vars,temp2,1)==-1)
						{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					}
				}
				else /*Neither are floats */
				{
					char temp[tempcount+2];
					gen_temp(temp,&tempcount);
					strcpy($$,temp);
					if(set(vars,temp,0)==-1)
					{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
					fprintf(yyout,"IDIV %s %s %s\n", $$, $1, $3); 
			 		linenum++;
				}
			}
			}
	|factor { strcpy($$,$1); };

factor: '(' expression ')' { strcpy($$,$2); }
	|CAST '(' expression ')' 
		{	
			if($1==INTCAST)
			{
				char temp[tempcount+2];
				gen_temp(temp,&tempcount);
				strcpy($$,temp);
				if(set(vars,temp,0)==-1)
				{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
				fprintf(yyout,"RTOI %s %s\n", $$, $3);
				linenum++; 
			}
			else
			{
				char temp[tempcount+2];
				gen_temp(temp,&tempcount);
				strcpy($$,temp);
				if(set(vars,temp,1)==-1)
				{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
				fprintf(yyout,"ITOR %s %s\n", $$, $3);
				linenum++;
			}
		}
	|ID { if(get(vars,$1)==-3)
		{
	  				hashmap_free(vars);
	  				free_temp_list(&temp_head);
	  				free_break_list(&break_head,&break_tail);
	  				free_case_list(&case_head,&case_tail);
					free_label_table(label_head,size);
					fprintf(stderr,"ID not declared in factor.\n");
					exit(1);
		}
		strcpy($$,$1);
	   }
	|NUM {
		char num[FLT_MAX_EXP];
		if($1==(int)$1)
			{itoa((int)$1,num);
			 if(set(vars,num,0)==-1)
			 {
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 strcpy($$,num);
			}
		else
			{itoa($1,$$);
			 if(set(vars,num,1)==-1)
			{
							hashmap_free(vars);
	  						free_temp_list(&temp_head);
	  						free_break_list(&break_head,&break_tail);
	  						free_case_list(&case_head,&case_tail);
							free_label_table(label_head,size);
							fprintf(stderr,"Issue set variable in table.\n");
							remove(saved_name);
							exit(1);
						}
			 strcpy($$,num);
			}
		 };
	     
%%
int main (int argc, char **argv)
{
 	char name[20];
	char name2[20];
	extern FILE *yyin;
	if(argc != 2)
	{
		fprintf(stderr,"Usage: %s <input file name>\n",argv[0]);
		exit(1);
	}
	yyin=fopen(argv[1], "r");
	if(yyin == NULL)
	{
		fprintf(stderr,"failed to open file %s\n",argv[1]);
		exit(1);
	}
	strcpy(name,argv[1]);
	name[strlen(name)-2]='\0';
	strcat(name,"temp");
	yyout=fopen(name,"w");
	if(yyout==NULL)
	{
		fprintf(stderr,"failed to open file %s\n",name);
		exit(1);
	}
	strcpy(saved_name,name);
	yyparse ();
	fclose (yyin);
	fclose(yyout);
	change_labels(&name[0],label_head,&case_head);
	free_label_table(label_head,size);
	free_case_list(&case_head,&case_tail);
	remove(saved_name);
	return 0;
}

/* called by yyparse() whenever a syntax error is detected */
void yyerror (const char *s)
{
  extern int line; // defined by flex
  fprintf (stderr, "Error in line %d:%s\n", line,s);
}
