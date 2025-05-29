#define LINESIZE 1000 //Size of line

typedef struct temp_node{ //a linked list of the variables before knowing their type
 char* name;
 struct temp_node *next;
}temp_node;

typedef struct break_node{ //a double sided linked list of the while/switch stmts exit labels(ordered from earliest to latest)
 struct break_node *prev;
 char* label;
 struct break_node *next;
}break_node;

typedef struct case_node{ //a double linked list of cases and their line number from the earliest to latest(skips the first case)
 struct case_node *prev;
 int line_no;
 struct case_node *next;
}case_node;

void free_temp_list(temp_node** temp_head);
void free_break_list(break_node** break_head, break_node** break_tail);
void free_case_list(case_node** case_head, case_node** case_tail);
int add_temp_list(temp_node** temp_head,char *temp_name);
int add_break_list(break_node** break_head,break_node** break_tail,char* label_name);
int remove_break_list(break_node** break_head, break_node** break_tail);
int add_case_list(case_node** case_head,case_node** case_tail,int line_no);
int remove_case_list(case_node** case_head, case_node** case_tail);
void gen_label(char * num,int *labelcount);
void gen_temp(char* num,int *tempcount);
void itoa_label(int n,char s[]);
void itoa_temp(int n,char s[]);
void itoa(int n,char s[]);
int add_label_table(int** array, char* label, int* size, int linenum);
void free_label_table(int* array, int size);
void change_labels(char * name, int * label_array, case_node ** case_head);
