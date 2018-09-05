/**************************************************
* File Name   : main.c
* Date        : 8/18/2018
* Description : Testing the trace pcore
* Version     : 2.0.0
* Author      : zyLiu6707
* Modified    : Minjun Seo
**************************************************/

#include <stdio.h>
#include <stdlib.h>

///********************functionality options********************///
#define enable_multi_tables 0         //1: enable 0: disable
#define trace_output_mode 1           //1: directly output traces in the called function 0: by calling ad-hoc function
#define only_output_the_last_trace 0  //1: enable 0: disable
///********************functionality options********************///

#define trace_size 255 //same as the VHDL generic

/*simple hardware multiplier*/
volatile unsigned int * multi_a;    //point to register of operand a
volatile unsigned int * multi_b;    //point to register of operand b
volatile unsigned int * multi_rslt; //point to result register of a*b

/*variables to store the value and output in printf*/
unsigned int multi_a_num;  //get value from *multi_a
unsigned int multi_b_num;  //get value from *multi_b
unsigned int multi_result; //get value from *multi_rslt

/*control register and storage matrix*/
volatile unsigned int * ctrl_reg;                      //point to control register, which lets the pcore to start to trace
volatile unsigned int * opcode;                        //point to registers that store the operation code of an instruction
volatile unsigned int * errmode_instructrap_progcnter; //point to registers that store the error mode bit, instruction trap bit and program counter(PC)
volatile unsigned int * ld_st_param;                   //point to registers that store the load address or stored data
volatile unsigned int * timetag_multicyc_unusedbit;    //point to registers that store the multi-cycle bit, time tag value of this instruction and an unused bit

/*variables to store the trace data and output in printf*/
unsigned int trace_data_opcode;
unsigned int trace_data_errormode;
unsigned int trace_data_instruction_trap;
unsigned int trace_data_programcounter;
unsigned int trace_data_ld_st_param;
unsigned int trace_data_timetag;
unsigned int trace_data_multi_cycle;

int var=0;      //a simple variable that will be incremented by one(1) in main function, imitating some actual software
int trace_num=1;//numbering the trace data

/*relating to functionality options macro*/
#if (enable_multi_tables==1)
int multi_tables(int line_size, int row_size);
#endif // enable_multi_tables
/*relating to functionality options macro*/
#if (trace_output_mode==0)
int trace_output(void);
#endif // trace_output_mode


int main(void)
{

/*the addresses below are decided in VHDL code of the pcore as well as the configuration of AMBA Plug&Play*/
  multi_a  = (unsigned int * )0x80002000;  //address of operand a register
  multi_b  = (unsigned int * )0x80002004;  //address of operand b register
  multi_rslt =(unsigned int * )0x80002008; //address of the result of a*b

  ctrl_reg = (unsigned int * )0x8000200c;  //address of control register

  opcode   = (unsigned int * )0x80002010;  //starting address of the operation code in storage matrix(i.e., the address of register in the first line)
  errmode_instructrap_progcnter = (unsigned int * )0x80002014;
  ld_st_param  = (unsigned int * )0x80002018;
  timetag_multicyc_unusedbit  = (unsigned int * )0x8000201c;
/*the addresses above are decided in VHDL code of the pcore as well as the configuration of AMBA Plug&Play*/


/*traced code below*/

  #if (enable_multi_tables==1)
  *ctrl_reg = 1;
  multi_tables(5,5);
  #endif

  *ctrl_reg = 1; //start to tracing
  asm("nop");    //these part will generate some simple SPARC V8 assembly code
  var++;
  asm("nop");
  asm("nop");
  var++;



/*traced code ends*/


/*trace output*/

  #if (trace_output_mode==0)
  trace_output();

  #elif (trace_output_mode==1)

    for (int i=1; i<=trace_size; i++) {
      printf("*******trace %d*******\n", trace_num);
      printf("this trace is retrieved from %8x %8x %8x %8x\n", opcode, errmode_instructrap_progcnter, ld_st_param, timetag_multicyc_unusedbit);

      trace_data_opcode = *opcode;
      printf("opcode     :     %8x\n", trace_data_opcode);
      opcode += 4;//point to next

      trace_data_errormode = (*errmode_instructrap_progcnter) >> 31;
      trace_data_instruction_trap = (*errmode_instructrap_progcnter & 0x40000000) >> 30;
      trace_data_programcounter = (*errmode_instructrap_progcnter & 0x3fffffff) << 2;
      printf("error mode :     %8u\n", trace_data_errormode);
      printf("trap       :     %8u\n", trace_data_instruction_trap);
      printf("PC         :     %8x\n", trace_data_programcounter);
      errmode_instructrap_progcnter += 4;

      trace_data_ld_st_param = (*ld_st_param);
      printf("load/store :     %8x\n", trace_data_ld_st_param);
      ld_st_param += 4;

      trace_data_multi_cycle = (*timetag_multicyc_unusedbit & 0x40000000) >> 30;
      trace_data_timetag = (*timetag_multicyc_unusedbit & 0x3fffffff);
      printf("multi-cycle:     %8u\n", trace_data_multi_cycle);
      printf("time tag   :     %8u\n", trace_data_timetag);
      timetag_multicyc_unusedbit += 4;

      trace_num++;
    }
  #endif // trace_output_mode
///*********************///
}



#if (enable_multi_tables==1)
int multi_tables(int line_size, int row_size){

  *multi_a = 1;
  multi_a_num = *multi_a;

  *multi_b = 1;
  multi_b_num = *multi_b;

  //multi_result = *multi_rslt;

    for(int i=1; i<=line_size; i++){

      for(int j=1; j<=row_size; j++){
        multi_result = *multi_rslt;
        printf("%u * %u = %u\t", multi_a_num, multi_b_num, multi_result);
        multi_b_num++;
        *multi_b = multi_b_num;

      if(j == row_size)
        printf("\n");
      }

      *multi_b = 1;
      multi_b_num = *multi_b;

      multi_a_num++;
      *multi_a = multi_a_num;
    }

    return 0;
}
#endif // enable_multi_tables

#if (trace_output_mode==0)
int trace_output(void){

  #if (only_output_the_last_trace==1)

    opcode   = (unsigned int * )0x80002010 + trace_size-1;
    errmode_instructrap_progcnter = (unsigned int * )0x80002014 + trace_size-1;
    ld_st_param  = (unsigned int * )0x80002018 + trace_size-1;
    timetag_multicyc_unusedbit  = (unsigned int * )0x8000201c + trace_size-1;

    printf("*******trace %d*******\n", trace_size);
    printf("this trace is retrieved from %8x %8x %8x %8x\n", opcode, errmode_instructrap_progcnter, ld_st_param, timetag_multicyc_unusedbit);

    trace_data_opcode = *opcode;
    printf("opcode     :     %8x\n", trace_data_opcode);

    trace_data_errormode = (*errmode_instructrap_progcnter) >> 31;
    trace_data_instruction_trap = (*errmode_instructrap_progcnter & 0x40000000) >> 30;
    trace_data_programcounter = (*errmode_instructrap_progcnter & 0x3fffffff) << 2;
    printf("error mode :     %8u\n", trace_data_errormode);
    printf("trap       :     %8u\n", trace_data_instruction_trap);
    printf("PC         :     %8x\n", trace_data_programcounter);

    trace_data_ld_st_param = (*ld_st_param);
    printf("load/store :     %8x\n", trace_data_ld_st_param);

    trace_data_multi_cycle = (*timetag_multicyc_unusedbit & 0x40000000) >> 30;
    trace_data_timetag = (*timetag_multicyc_unusedbit & 0x3fffffff);
    printf("multi-cycle:     %8u\n", trace_data_multi_cycle);
    printf("time tag   :     %8u\n", trace_data_timetag);

  #else

    for (int i=1; i<=trace_size; i++) {
      printf("*******trace %d*******\n", trace_num);
      printf("this trace is retrieved from %8x %8x %8x %8x\n", opcode, errmode_instructrap_progcnter, ld_st_param, timetag_multicyc_unusedbit);

      trace_data_opcode = *opcode;
      printf("opcode     :     %8x\n", trace_data_opcode);
      opcode += 4;

      trace_data_errormode = (*errmode_instructrap_progcnter) >> 31;
      trace_data_instruction_trap = (*errmode_instructrap_progcnter & 0x40000000) >> 30;
      trace_data_programcounter = (*errmode_instructrap_progcnter & 0x3fffffff) << 2;
      printf("error mode :     %8u\n", trace_data_errormode);
      printf("trap       :     %8u\n", trace_data_instruction_trap);
      printf("PC         :     %8x\n", trace_data_programcounter);
      errmode_instructrap_progcnter += 4;

      trace_data_ld_st_param = (*ld_st_param);
      printf("load/store :     %8x\n", trace_data_ld_st_param);
      ld_st_param += 4;

      trace_data_multi_cycle = (*timetag_multicyc_unusedbit & 0x40000000) >> 30;
      trace_data_timetag = (*timetag_multicyc_unusedbit & 0x3fffffff);
      printf("multi-cycle:     %8u\n", trace_data_multi_cycle);
      printf("time tag   :     %8u\n", trace_data_timetag);
      timetag_multicyc_unusedbit += 4;

      trace_num++;
    }
  #endif // only_output_the_last_trace

  return 0;
}
#endif // trace_output_mode
