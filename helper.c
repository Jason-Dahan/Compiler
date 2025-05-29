#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "helper.h"

FILE *reader = NULL; //For reading the temp file
FILE *writer = NULL; //For writing the .qud file

//Frees the list of temporary variables
void free_temp_list(temp_node** temp_head)
{
	temp_node* ptr= *temp_head;
	while(*temp_head != NULL)
	{
		*temp_head = (*temp_head)->next;
		free(ptr->name);
		ptr->next=NULL;
		free(ptr);
		ptr=*temp_head;
	}
	*temp_head=NULL;
}

//Frees the list of all break labels
void free_break_list(break_node** break_head, break_node** break_tail)
{
	break_node *ptr;
	while(*break_head != NULL)
	{
		ptr = *break_head;
		*break_head = (*break_head)->next;
		free(ptr->label);
		free(ptr);
	}
	*break_head=NULL;
	*break_tail=*break_head;
}

//Frees the list of all the cases
void free_case_list(case_node** case_head, case_node** case_tail)
{
	case_node *ptr;
	while(*case_head != NULL)
	{
		ptr = *case_head;
		*case_head = (*case_head)->next;
		free(ptr);
	}
	*case_head=NULL;
	*case_tail=*case_head;
}

//Searchs the temp variables for one with the same name
int temp_search(temp_node* temp_head,char *temp_name)
{
	temp_node* temp_curr=temp_head;
	while(temp_curr!=NULL)
	{
		if(strcmp(temp_curr->name,temp_name)==0)
			return 1;
		temp_curr=temp_curr->next;
	}
	return -1;
}

//Add a variable to the end of the variable list
int add_temp_list(temp_node** temp_head,char *temp_name)
{
	temp_node *temp_curr=(temp_node *)malloc(sizeof(temp_node)); //Create the new node
	if(temp_curr==NULL)
		{
			return -1;
		}
	temp_curr->name=(char *)malloc(strlen(temp_name)+1);
	if(temp_curr->name==NULL)
		{
			free(temp_curr);
			return -1;
		}
	strcpy(temp_curr->name,temp_name);
	temp_curr->next=NULL;
	if(*temp_head == NULL) //If the list is empty-add to the beginning
	{
		*temp_head=temp_curr;
	}
	else //The list has some nodes
	{
		temp_node *temp_curr2=*temp_head;
		while(temp_curr2->next != NULL) //Go to the last node
		{
			temp_curr2=temp_curr2->next;
		}
		temp_curr2->next = temp_curr;
	}
	return 1;
}

//Adds a break node to the end of the list
int add_break_list(break_node** break_head,break_node** break_tail,char* label_name)
{
	break_node* break_curr=(break_node *) malloc(sizeof(break_node)); //Create the node
	if(break_curr==NULL)
		{
			return -1;
		}
	break_curr->label=(char *)malloc(strlen(label_name)+1);
	if(break_curr->label==NULL)
		{
			free(break_curr);
			return -1;
		}
	strcpy(break_curr->label,label_name);
	break_curr->prev=NULL;
	break_curr->next=NULL;
	if(*break_head==NULL) //The list is empty
	{
		*break_head=break_curr;
		*break_tail=*break_head;
	}
	else //There is a node
	{
		(*break_tail)->next=break_curr;
		break_curr->prev=*break_tail;
		*break_tail=(*break_tail)->next;
	}
	return 1;
}

//Removes a break_node from the end of the list
int remove_break_list(break_node** break_head, break_node** break_tail)
{
	if(*break_head==NULL) //The list is empty
	{
		fprintf(stderr,"Break list is empty.\n");
		return -1;
	}
	if(*break_tail==*break_head) //Only one node in the list
	{
		free((*break_head)->label);
		free(*break_head);
		*break_head=NULL;
		*break_tail=*break_head;
		return 1;
	}
	else //There are atleast two nodes
	{
	*break_tail=(*break_tail)->prev;
	free((*break_tail)->next->label);
	free((*break_tail)->next);
	(*break_tail)->next=NULL;
	return 1;
	}
}

//Adds a case_node to the end of the list
int add_case_list(case_node** case_head,case_node** case_tail,int line_no)
{
	case_node* case_curr=(case_node *) malloc(sizeof(case_node)); //Create the node
	if(case_curr==NULL)
		{
			return -1;
		}
	case_curr->line_no=line_no;
	case_curr->prev=NULL;
	case_curr->next=NULL;
	if(*case_head==NULL) //List is empty
	{
		*case_head=case_curr;
		*case_tail=*case_head;
	}
	else
	{
		(*case_tail)->next=case_curr;
		case_curr->prev=*case_tail;
		*case_tail=(*case_tail)->next;
	}
	return 1;
}

//Removes the last case from the list
int remove_case_list(case_node** case_head, case_node** case_tail)
{
	if(*case_head==NULL) //List is empty
	{
		fprintf(stderr,"Case list is empty.\n");
		return -1;
	}
	if(*case_tail==*case_head) //Only one node
	{
		free(*case_head);
		*case_head=NULL;
		*case_tail=*case_head;
		return 1;
	}
	else //At least two nodes
	{
	*case_tail=(*case_tail)->prev;
	free((*case_tail)->next);
	(*case_tail)->next=NULL;
	return 1;
	}
}

//Creates a new label and inserts it into num
void gen_label(char * num,int *labelcount)
{
	itoa_label((*labelcount),num);
	(*labelcount)++;
} 

//Creates a new temp and inserts it into num
void gen_temp(char* num,int *tempcount)
{
	itoa_temp((*tempcount),num);
	(*tempcount)++;
} 

//Makes a string of the label where n is the label number and inserts into s. - Taken mostly from C programming language book from Open University
void itoa_label(int n,char s[])
{
	int i=0,j,k,c;
	do
	{
		s[i++]=n%10 + '0';
	} while((n/=10)>0);
	s[i++]='L';
	s[i]='\0';
	for(j=0,k= strlen(s)-1;j<k;j++,k--)
	{
		c=s[j];
		s[j]=s[k];
		s[k]=c;
	}
}

//Makes a string of the temp where n is the temp number and inserts into s. - Taken mostly from C programming language book from Open University
void itoa_temp(int n,char s[])
{
	int i=0,j,k,c;
	do
	{
		s[i++]=n%10 + '0';
	} while((n/=10)>0);
	s[i++]='t';
	s[i]='\0';
	for(j=0,k= strlen(s)-1;j<k;j++,k--)
	{
		c=s[j];
		s[j]=s[k];
		s[k]=c;
	}
}

//Changes a int into a string - Also from O-University book.
void itoa(int n,char s[])
{
	int i=0,j,k,c;
	do
	{
		s[i++]=n%10 + '0';
	} while((n/=10)>0);
	s[i]='\0';
	for(j=0,k= strlen(s)-1;j<k;j++,k--)
	{
		c=s[j];
		s[j]=s[k];
		s[k]=c;
	}
}

//Inserts the linenumber into an array where the index represents the label number
int add_label_table(int** array, char* label, int* size, int linenum)
{
	int num=atoi(&label[1]); //Changes the number part to integer
	if(*size == 0) //The first time the table has been initialized
	{
		*array=(int*)malloc(sizeof(int)*100);
		if(*array==NULL)
			return -1;
		(*size)=100*sizeof(int);
	}
	else if (num != 0 && num == (*size)) //The table is full
	{
		*array=(int*)realloc(*array,((*size)+100*sizeof(int)));
		if(*array ==NULL)
			return -1;
		(*size)=(*size)+100*sizeof(int);
	}
	(*array)[num]=linenum;
	return 1;
}

//Frees the table of labels
void free_label_table(int* array, int size)
{
	free(array);
	array=NULL;
}

//Changes the case labels we added and the regular labels into numbers
void change_labels(char * name, int * array, case_node ** case_head)
{
	char * word;
	char * white_space=" \t\v\f\r\n";
	int i,isFirstLine=1;
	char c;
	reader=fopen(name,"r");
	if(reader==NULL)
	{
		fprintf(stderr,"failed to open file %s\n",name);
		exit(1);
	}
	for(i=1;i<=5;i++)
	{
		name[strlen(name)-1]='\0';
	}
	strcat(name,".qud");
	writer=fopen(name,"w");
	if(writer==NULL)
	{
		fprintf(stderr,"failed to open file %s\n",name);
		exit(1);
	}
	char * line=(char *) malloc(sizeof(char)*LINESIZE+1);
	if(line==NULL)
	{
		fprintf(stderr,"Not enough space for to create line");
	}
	for(;;)
	{
		if(fgets(line,LINESIZE,reader)==NULL) //Get a line
			break;
		if(!isFirstLine) //If it isn't the first line-you need to go down a line
			if((fputc('\n',writer))==EOF)
				fprintf(stderr,"Problem writing label");
		if(isFirstLine) //If it is the first line
			isFirstLine=0;
		if(line[strlen(line)-1]!='\n')
		{
			fprintf(stderr,"Error, too long command line\n");
				break;
		}
		word=strtok(line,white_space); //Get the first token between white spaces
		while(word!=NULL)
		{
			if(word[0] == 'L') //If it begins with capital L its a label
			{
				if((word[strlen(word)-1])==':') //If its declaration ignore.
				{
					word=strtok(NULL,white_space);
					continue;
				}
				else //Its in a jump statement-change to number
				{
					char num[100];
					int n=atoi(&word[1]);
					itoa(array[n],num);
					if((fputs(num,writer))==EOF)
						fprintf(stderr,"Problem writing label");
				}
			}
			else if(strcmp(word,"C")==0) //If it is a C its a case label, take the next case_node with the line number in it.
			{
				char num[100];
				itoa((*case_head)->line_no,num);
				if((fputs(num,writer))==EOF)
						fprintf(stderr,"Problem writing label");
				*case_head=(*case_head)->next;
			}
			else //Its just a regular word so write it.
			{
				if(fputs(word,writer)==EOF)
						fprintf(stderr,"Problem writing label");
			}
		if((fputc(' ',writer))==EOF) //Write spaces between every word.
			fprintf(stderr,"Problem writing label");
		word=strtok(NULL,white_space);	 //Get the next word	
		}
	}
	free(line);
	fclose(reader);
	fclose(writer);	
}
