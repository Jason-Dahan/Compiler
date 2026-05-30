%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex(void);
extern int yylineno;
extern char* yytext;
void yyerror(const char *s);


enum operator {MULT, DIV, ADD, SUB, EQ, NEQ, LT, GT, LTE, GTE};
enum numtyper {INTEGER, FLOATPOINT};
enum caster {INTCAST, FCAST};

struct numinfo {
    enum numtyper type;
    int ival;
    float fval;
};

struct variable {
    char str[80];
    struct numinfo *val;
};

/* GLOBAL STATE & COUNTERS */
int temp_count = 1;
int label_count = 1;
int has_errors = 0;

/* SYMBOL TABLE */
struct symbol {
    char name[80];
    enum numtyper type;
} symtab[1000];
int sym_count = 0;

void put_sym(char* name, enum numtyper t) {
    strcpy(symtab[sym_count].name, name);
    symtab[sym_count].type = t;
    sym_count++;
}

enum numtyper get_sym_type(char* name) {
    for(int i = 0; i < sym_count; i++) {
        if(strcmp(symtab[i].name, name) == 0) return symtab[i].type;
    }
    fprintf(stderr, "Semantic Error at line %d: Undefined variable '%s'\n", yylineno, name);
    has_errors = 1;
    return INTEGER; /* Default return to prevent cascading crashes */
}

/* Variables for handling comma-separated declarations (e.g., int x, y, z;) */
char decl_list[100][80];
int decl_count = 0;

#define MAX_QUADS 5000
struct quad {
    char op[10];
    char a1[20];
    char a2[20];
    char a3[20];
} quads[MAX_QUADS];
int nextq = 1;

int label_loc[5000]; /* Maps a label number to its final quad instruction line number */

void emit0(const char* op) { strcpy(quads[nextq].op, op); quads[nextq].a1[0]=0; quads[nextq].a2[0]=0; quads[nextq].a3[0]=0; nextq++; }
void emit1(const char* op, const char* a1) { strcpy(quads[nextq].op, op); strcpy(quads[nextq].a1, a1); quads[nextq].a2[0]=0; quads[nextq].a3[0]=0; nextq++; }
void emit2(const char* op, const char* a1, const char* a2) { strcpy(quads[nextq].op, op); strcpy(quads[nextq].a1, a1); strcpy(quads[nextq].a2, a2); quads[nextq].a3[0]=0; nextq++; }
void emit3(const char* op, const char* a1, const char* a2, const char* a3) { strcpy(quads[nextq].op, op); strcpy(quads[nextq].a1, a1); strcpy(quads[nextq].a2, a2); strcpy(quads[nextq].a3, a3); nextq++; }

int gen_label() { return label_count++; }
void set_label(int l) { label_loc[l] = nextq; }

char* gen_temp() {
    char* t = (char*)malloc(20);
    sprintf(t, "_t%d", temp_count++);
    return t;
}

char* itoa_str(int val) {
    char* s = (char*)malloc(20);
    sprintf(s, "%d", val);
    return s;
}

/* CONTROL FLOW STACKS (Break & Switch) */
int break_stack[100];
int break_depth = 0;
void push_break(int l) { break_stack[++break_depth] = l; }
void pop_break() { break_depth--; }
int get_break() { return break_stack[break_depth]; }

struct switch_info {
    char expr_var[20];
    struct { int val; int lbl; } cases[100];
    int case_cnt;
    int def_lbl;
    int end_lbl;
    int disp_lbl;
} sw_stack[10];
int sw_depth = 0;

/* SEMANTIC HELPERS */

void mangle_name(char *dest, const char *src) {
    int j = 0;
    for (int i = 0; src[i] != '\0'; i++) {
        if (src[i] >= 'A' && src[i] <= 'Z') {
            dest[j++] = src[i] + 32;
            dest[j++] = '_';
        } else {
            dest[j++] = src[i];
        }
    }
    dest[j] = '\0';
}

/* Centralized Math Logic (Fixes Massive Code Duplication) */
void handle_math_op(struct variable* res, struct variable* left, struct variable* right, int op) {
    strcpy(res->str, gen_temp());
    res->val = (struct numinfo*)malloc(sizeof(struct numinfo));
    
    char l_str[20], r_str[20];
    strcpy(l_str, left->str);
    strcpy(r_str, right->str);

    int is_float = (left->val->type == FLOATPOINT || right->val->type == FLOATPOINT);
    res->val->type = is_float ? FLOATPOINT : INTEGER;

    if (is_float) {
        if (left->val->type == INTEGER) { strcpy(l_str, gen_temp()); emit2("ITOR", l_str, left->str); }
        if (right->val->type == INTEGER) { strcpy(r_str, gen_temp()); emit2("ITOR", r_str, right->str); }
        
        char* op_str = (op == ADD) ? "RADD" : (op == SUB) ? "RSUB" : (op == MULT) ? "RMLT" : "RDIV";
        emit3(op_str, res->str, l_str, r_str);
    } else {
        char* op_str = (op == ADD) ? "IADD" : (op == SUB) ? "ISUB" : (op == MULT) ? "IMLT" : "IDIV";
        emit3(op_str, res->str, l_str, r_str);
    }
}

/* Centralized Relational Logic (Fixes <= and >= missing Quad Instructions) */
void handle_rel_op(struct variable* res, struct variable* left, struct variable* right, int op) {
    strcpy(res->str, gen_temp());
    res->val = (struct numinfo*)malloc(sizeof(struct numinfo));
    res->val->type = INTEGER; /* Relational checks always return 1 or 0 (int) */
    
    char l_str[20], r_str[20];
    strcpy(l_str, left->str);
    strcpy(r_str, right->str);

    int is_float = (left->val->type == FLOATPOINT || right->val->type == FLOATPOINT);
    if (is_float) {
        if (left->val->type == INTEGER) { strcpy(l_str, gen_temp()); emit2("ITOR", l_str, left->str); }
        if (right->val->type == INTEGER) { strcpy(r_str, gen_temp()); emit2("ITOR", r_str, right->str); }
    }

    char op_str[10];
    char prefix = is_float ? 'R' : 'I';
    int needs_invert = 0;

    if (op == EQ) sprintf(op_str, "%cEQL", prefix);
    else if (op == NEQ) sprintf(op_str, "%cNQL", prefix);
    else if (op == LT) sprintf(op_str, "%cLSS", prefix);
    else if (op == GT) sprintf(op_str, "%cGRT", prefix);
    else if (op == LTE) { sprintf(op_str, "%cGRT", prefix); needs_invert = 1; } /* !(a > b) */
    else if (op == GTE) { sprintf(op_str, "%cLSS", prefix); needs_invert = 1; } /* !(a < b) */

    if (!needs_invert) {
        emit3(op_str, res->str, l_str, r_str);
    } else {
        char t[20]; strcpy(t, gen_temp());
        emit3(op_str, t, l_str, r_str);
        emit3("IEQL", res->str, t, "0"); /* Invert the result */
    }
}
%}

%union {
    enum operator op;
    enum caster ctype;
    struct numinfo *numtype;
    struct variable *var;
    int lbl;
    int num;
}

%token BREAK CASE DEFAULT ELSE FLOAT IF INPUT INT OUTPUT SWITCH WHILE
%token NOT AND OR
%token <op> RELOP ADDOP MULOP
%token <ctype> CAST
%token <var> ID
%token <numtype> NUM

%type <var> expression term factor boolexpr boolterm boolfactor
%type <lbl> M_if N_else M_wstart M_wdo
%type <num> type

%%

program: declarations stmt_block { emit0("HALT"); }
    ;

declarations: declarations declaration
    | /* epsilon */
    ;

declaration: idlist ':' type ';' {
        for(int i = 0; i < decl_count; i++) {
            put_sym(decl_list[i], $3);
        }
        decl_count = 0; /* Reset for the next declaration */
    }
    ;

type: INT { $$ = INTEGER; }
    | FLOAT { $$ = FLOATPOINT; }
    ;

idlist: idlist ',' ID {
        mangle_name(decl_list[decl_count++], $3->str);
    }
    | ID {
        decl_count = 0;
        mangle_name(decl_list[decl_count++], $1->str);
    }
    ;

stmt: assignment_stmt | input_stmt | output_stmt | if_stmt | while_stmt | switch_stmt | break_stmt | stmt_block
    ;

assignment_stmt: ID '=' expression ';' {
        char m_name[80];
        mangle_name(m_name, $1->str);
        enum numtyper t = get_sym_type(m_name);
        
        if (t == INTEGER && $3->val->type == INTEGER) {
            emit2("IASN", m_name, $3->str);
        } else if (t == FLOATPOINT && $3->val->type == FLOATPOINT) {
            emit2("RASN", m_name, $3->str);
        } else if (t == FLOATPOINT && $3->val->type == INTEGER) {
            char* tmp = gen_temp();
            emit2("ITOR", tmp, $3->str);
            emit2("RASN", m_name, tmp);
        } else {
            fprintf(stderr, "Semantic Error at line %d: Cannot implicitly assign FLOAT to INT\n", yylineno);
            has_errors = 1;
        }
    }
    ;

input_stmt: INPUT '(' ID ')' ';' {
        char m_name[80];
        mangle_name(m_name, $3->str);
        enum numtyper t = get_sym_type(m_name);
        if(t == INTEGER) emit1("IINP", m_name);
        else emit1("RINP", m_name);
    }
    ;

output_stmt: OUTPUT '(' expression ')' ';' {
        if($3->val->type == INTEGER) emit1("IPRT", $3->str);
        else emit1("RPRT", $3->str);
    }
    ;

if_stmt: IF '(' boolexpr ')' M_if stmt N_else ELSE { set_label($5); } stmt { set_label($7); }
    ;

M_if: { $$ = gen_label(); emit2("JMPZ", itoa_str($$), $<var>3->str); } ;
N_else: { $$ = gen_label(); emit1("JUMP", itoa_str($$)); } ;

while_stmt: WHILE M_wstart '(' boolexpr ')' M_wdo stmt {
        emit1("JUMP", itoa_str($2));
        set_label($6);
        pop_break();
    }
    ;

M_wstart: { $$ = gen_label(); set_label($$); } ;
M_wdo: { 
        $$ = gen_label(); 
        emit2("JMPZ", itoa_str($$), $<var>4->str);
        push_break($$); 
    } ;

switch_stmt: SWITCH '(' expression ')' M_sw '{' caselist DEFAULT ':' M_def stmtlist '}' {
        if($3->val->type != INTEGER) {
            fprintf(stderr, "Semantic Error at line %d: Switch expression must be INT\n", yylineno);
            has_errors = 1;
        }
        emit1("JUMP", itoa_str(sw_stack[sw_depth].end_lbl));
        set_label(sw_stack[sw_depth].disp_lbl);
        
        /* Dispatch logic at the end (Implements Teacher Feedback) */
        for (int i=0; i < sw_stack[sw_depth].case_cnt; i++) {
            char* t = gen_temp();
            emit3("INQL", t, sw_stack[sw_depth].expr_var, itoa_str(sw_stack[sw_depth].cases[i].val));
            emit2("JMPZ", itoa_str(sw_stack[sw_depth].cases[i].lbl), t);
        }
        emit1("JUMP", itoa_str(sw_stack[sw_depth].def_lbl));
        set_label(sw_stack[sw_depth].end_lbl);
        sw_depth--;
        pop_break();
    }
    ;

M_sw: {
        sw_depth++;
        sw_stack[sw_depth].case_cnt = 0;
        strcpy(sw_stack[sw_depth].expr_var, $<var>3->str);
        sw_stack[sw_depth].disp_lbl = gen_label();
        sw_stack[sw_depth].end_lbl = gen_label();
        push_break(sw_stack[sw_depth].end_lbl);
        emit1("JUMP", itoa_str(sw_stack[sw_depth].disp_lbl));
    } ;

M_def: { sw_stack[sw_depth].def_lbl = gen_label(); set_label(sw_stack[sw_depth].def_lbl); } ;

caselist: caselist CASE NUM ':' M_case stmtlist
    | /* epsilon */
    ;

M_case: {
        int l = gen_label(); set_label(l);
        sw_stack[sw_depth].cases[sw_stack[sw_depth].case_cnt].val = $<numtype>0->ival;
        sw_stack[sw_depth].cases[sw_stack[sw_depth].case_cnt].lbl = l;
        sw_stack[sw_depth].case_cnt++;
    } ;

break_stmt: BREAK ';' {
        if(break_depth == 0) {
            fprintf(stderr, "Semantic Error at line %d: BREAK outside of loop/switch\n", yylineno);
            has_errors = 1;
        } else {
            emit1("JUMP", itoa_str(get_break()));
        }
    }
    ;

stmt_block: '{' stmtlist '}'
    ;

stmtlist: stmtlist stmt
    | /* epsilon */
    ;

boolexpr: boolexpr OR boolterm {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = (struct numinfo*)malloc(sizeof(struct numinfo));
        $$->val->type = INTEGER;
        char* t1 = gen_temp();
        emit3("IADD", t1, $1->str, $3->str);
        strcpy($$->str, gen_temp());
        emit3("IGRT", $$->str, t1, "0"); /* (A+B) > 0 */
    }
    | boolterm { $$ = $1; }
    ;

boolterm: boolterm AND boolfactor {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = (struct numinfo*)malloc(sizeof(struct numinfo));
        $$->val->type = INTEGER;
        strcpy($$->str, gen_temp());
        /* Teacher Feedback: a AND b == IMLT result a b */
        emit3("IMLT", $$->str, $1->str, $3->str); 
    }
    | boolfactor { $$ = $1; }
    ;

boolfactor: NOT '(' boolexpr ')' {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = (struct numinfo*)malloc(sizeof(struct numinfo));
        $$->val->type = INTEGER;
        strcpy($$->str, gen_temp());
        emit3("IEQL", $$->str, $3->str, "0");
    }
    | expression RELOP expression {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        handle_rel_op($$, $1, $3, $2);
    }
    ;

expression: expression ADDOP term {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        handle_math_op($$, $1, $3, $2);
    }
    | term { $$ = $1; }
    ;

term: term MULOP factor {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        handle_math_op($$, $1, $3, $2);
    }
    | factor { $$ = $1; }
    ;

factor: '(' expression ')' { $$ = $2; }
    | CAST '(' expression ')' {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = (struct numinfo*)malloc(sizeof(struct numinfo));
        strcpy($$->str, gen_temp());
        
        if ($1 == INTCAST) {
            $$->val->type = INTEGER;
            if($3->val->type == FLOATPOINT) emit2("RTOI", $$->str, $3->str);
            else emit2("IASN", $$->str, $3->str);
        } else {
            $$->val->type = FLOATPOINT;
            if($3->val->type == INTEGER) emit2("ITOR", $$->str, $3->str);
            else emit2("RASN", $$->str, $3->str);
        }
    }
    | ID {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = (struct numinfo*)malloc(sizeof(struct numinfo));
        mangle_name($$->str, $1->str);
        $$->val->type = get_sym_type($$->str);
    }
    | NUM {
        $$ = (struct variable*)malloc(sizeof(struct variable));
        $$->val = $1; 
        strcpy($$->str, gen_temp());
        if ($$->val->type == INTEGER) {
            emit2("IASN", $$->str, itoa_str($$->val->ival));
        } else {
            char f_str[40]; sprintf(f_str, "%f", $$->val->fval);
            emit2("RASN", $$->str, f_str);
        }
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parse Error at line %d: %s\n", yylineno, s);
    has_errors = 1;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: cpq <input_file.ou>\n");
        exit(1);
    }

    int len = strlen(argv[1]);
    if(len < 3 || strcmp(argv[1] + len - 3, ".ou") != 0) {
        fprintf(stderr, "Error: Input file must have .ou extension\n");
        exit(1);
    }

    extern FILE *yyin;
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        fprintf(stderr, "Error: failed to open file %s\n", argv[1]);
        exit(1);
    }

    /* Start parsing */
    yyparse();
    fclose(yyin);

    if (has_errors) {
        fprintf(stderr, "\nCompilation failed due to errors. No output generated.\n");
        exit(1);
    }

    /* Create the .qud output filename */
    char name[80];
    strcpy(name, argv[1]);
    name[len - 2] = 'q';
    name[len - 1] = 'u';
    name[len] = 'd';
    name[len + 1] = '\0';
    
    FILE *yyout = fopen(name, "w");
    if (!yyout) {
        fprintf(stderr, "Error: failed to create output file %s\n", name);
        exit(1);
    }

    /* Output the Quad Array and Resolve the Labels to final line numbers */
    for(int i = 1; i < nextq; i++) {
        if(strcmp(quads[i].op, "JUMP") == 0) {
            fprintf(yyout, "JUMP %d\n", label_loc[atoi(quads[i].a1)]);
        } else if(strcmp(quads[i].op, "JMPZ") == 0) {
            fprintf(yyout, "JMPZ %d %s\n", label_loc[atoi(quads[i].a1)], quads[i].a2);
        } else {
            fprintf(yyout, "%s", quads[i].op);
            if(quads[i].a1[0] != 0) fprintf(yyout, " %s", quads[i].a1);
            if(quads[i].a2[0] != 0) fprintf(yyout, " %s", quads[i].a2);
            if(quads[i].a3[0] != 0) fprintf(yyout, " %s", quads[i].a3);
            fprintf(yyout, "\n");
        }
    }

    fprintf(stderr, "Student: [ENTER YOUR NAME HERE]\n");
    fprintf(yyout, "Student: [ENTER YOUR NAME HERE]\n");
    fclose(yyout);

    return 0;
}