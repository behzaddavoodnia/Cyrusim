/** @module : 7_Stage_MIPS_Core
 *  @author : Behzad Davoodnia
 
 *  Copyright (c) 2010   Heracles (CSG/CSAIL/MIT)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 */

// 7-Stage MIPS Core, fully-passed, no branch delay slot... 
module MIPS_core #(parameter CORE = 0, ID_BITS = 4, LOCAL_ADDR_BITS = 16, 
                            DATA_WIDTH = 32, INDEX_BITS = 6, 
                            OFFSET_BITS = 3, FULL_ADDRESS_BITS = 32, INIT_FILE = "memory.mem",
                            IN_PORTS = 1, OUT_PORTS = 1, VC_BITS = 1, VC_DEPTH_BITS = 4,
                            MSG_BITS = 4, EXTRA  = 2, TYPE_BITS = 2 , SWITCH_TO_SWITCH  = 1, 
							RT_ALG = 0, ROW = 3, COLUMN = 3)(
  clock, 
  reset, 
  start,
  prog_address, 
  
  from_peripheral,
  from_peripheral_data, 
  from_peripheral_valid, 
  to_peripheral,
  to_peripheral_data, 
  to_peripheral_valid,
  
  ON, PROG, WEn, REn,
  router_ID, rt_flowID, rt_entry, 
  s_flits_in, s_valid_in, 
  s_flits_out, s_valid_out, 
  s_empty_in, s_full_in, 
  s_empty_out, s_full_out, 
  // performance and debugging 
  report, fault_status
); 

//define the log2 function
function integer log2;
	input integer num;
	integer i, result;
	begin
		for (i = 0; 2 ** i < num; i = i + 1)
			result = i + 1;
		log2 = result;
	end
endfunction

//---------------  Network and IO Inputs/Outputs -- Up to for 4 peripherals
localparam  FLOW_BITS     = (2*ID_BITS) + EXTRA;  
localparam  PAY_WIDTH     = MSG_BITS + DATA_WIDTH;
localparam  FLIT_WIDTH    = FLOW_BITS + TYPE_BITS + VC_BITS + PAY_WIDTH;
localparam  REAL_ADDR_BITS= LOCAL_ADDR_BITS -2; //Word alignment
localparam  ADDRESS_BITS  = ID_BITS + REAL_ADDR_BITS; 

localparam  PORTS = OUT_PORTS + 4*(SWITCH_TO_SWITCH);
localparam  PORTS_BITS = log2(PORTS); 
localparam  RT_WIDTH = PORTS_BITS + VC_BITS + 1; 
localparam  NUM_VC = (1 << VC_BITS); 

input  clock, reset, start; 
input  [31:0]  prog_address; 

input  [1:0]   from_peripheral;
input  [31:0]  from_peripheral_data; 
input  from_peripheral_valid;

input [3:0] fault_status;

output  [1:0]   to_peripheral;
output  [31:0]  to_peripheral_data; 
output  to_peripheral_valid;
reg  [1:0]   to_peripheral;
reg  [31:0]  to_peripheral_data; 
reg  to_peripheral_valid;

input ON, PROG, WEn, REn;
input [ID_BITS - 1: 0]    router_ID;
input [FLOW_BITS - 1: 0]  rt_flowID; 
input [RT_WIDTH - 1: 0]   rt_entry;
     
input [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] s_flits_in;
input [(SWITCH_TO_SWITCH *4) - 1: 0]s_valid_in; 
input [((NUM_VC * (SWITCH_TO_SWITCH *4)) - 1): 0] s_empty_in; 
input [((NUM_VC * (SWITCH_TO_SWITCH *4)) - 1): 0] s_full_in;
   
output [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] s_flits_out; 
output [(SWITCH_TO_SWITCH *4) - 1: 0] s_valid_out;
output [((NUM_VC * (SWITCH_TO_SWITCH *4)) - 1): 0] s_empty_out;
output [((NUM_VC * (SWITCH_TO_SWITCH *4)) - 1): 0] s_full_out; 

input report; 
//----------------------------------------------------------------------

wire   branch, zero, write ;  
wire   [2:0] PCSource; 
wire   [3:0] ALU_Op;
reg    [3:0] ALU_control;  
				 
reg    fetch, fetch_IC, load, store, write_EX, write_MEM, write_WB ; 
reg    load_MEM2, store_MEM2, write_MEM2; 
reg    [31:0]  PC_plus4, r_inst_addr, inst_addr_IC, r_data_addr, data_in;
reg    [31:0]  MEM2_addr, MEM2_data_in; 
wire   [31:0]  instruction, data_out, jumpAddr, targetReg, branchAddr;
wire   [31:0]  IC_out_addr, DC_out_addr; 
wire   [31:0]  ALU_result, operand_A,  operand_B, read2_data;
reg    [31:0]  op_A, op_B, MD, result; 

wire   [4:0]   ws_reg; 
reg    [4:0]   ws_reg_WB, ws_reg_EX, ws_reg_MEM, ws_reg_MEM2 ;
reg    [31:0]  IR_D, IR_EX, IR_MEM, IR_MEM2, MEM_Data, MEM2_Data, WB_Data; 
reg    [31:0]  PC_D, PC_EX;
reg    [31:0]  branchAddr_EX, targetReg_EX, jumpAddr_EX;
reg    [2:0]   PCSource_EX;	 

//Bypass logic
wire [4:0]   rs     = IR_D[25:21];
wire [4:0]   rt     = IR_D[20:16];
wire logic_r_type; 
wire zeroEXT_type;
wire [2:0]  bypass1 = (rs == 0)? 0 :((rs == ws_reg_EX) & (write_EX))? 1:
					  ((rs == ws_reg_MEM) & (write_MEM))? 2:
					  ((rs == ws_reg_MEM2) & (write_MEM2))? 3: 
					  ((rs == ws_reg_WB) & (write_WB))? 4: 0; 
wire [2:0]  bypass2 = (rt == 0)? 0 :((rt == ws_reg_EX) & (write_EX))? 1:
					  ((rt == ws_reg_MEM) & (write_MEM))? 2:
					  ((rt == ws_reg_MEM2) & (write_MEM2))? 3:
					  ((rt == ws_reg_WB) & (write_WB))? 4: 0;	



wire [2:0]   ASource  = logic_r_type? bypass2 : bypass1; 
wire [2:0]   BSource  = (logic_r_type | zeroEXT_type)? 0 : bypass2;
wire [2:0]   MDSource = logic_r_type? 0 : bypass2;

wire lw_stall = ((IR_EX[31:26] == 6'b100011) & ((bypass1 == 1) | (bypass2 == 1))) ? 1 : 
				((IR_MEM[31:26] == 6'b100011) & ((bypass1 == 2) | (bypass2 == 2))) ? 1 : 0; 
wire kill     = ((PCSource_EX == 1)| (PCSource_EX == 2) | ((PCSource_EX == 3) & zero))? 1: 0; 
                // kill on branch and jump 

localparam IDLE = 0, CLEAR = 1, INIT = 2, RUN = 3; 
reg [1:0] state;
reg  stall; 
wire IC_ready, DC_ready;
wire i_valid, d_valid;  

wire d_stall = ((load_MEM2 | store_MEM2) & (~d_valid)); 
wire i_stall = ((fetch_IC & ~i_valid) | (~IC_ready)); 
wire IRSrc   = ~stall;   

reg t_cur_iValid ; 
reg [31:0] t_cur_inst; 
reg [31:0] t_PC; 

wire cur_iValid      =(reset | (inst_addr_IC == 0))? 0 : 
                      (IC_out_addr == inst_addr_IC)? i_valid : t_cur_iValid; 
wire [31:0] cur_inst =(reset | (inst_addr_IC == 0))? 0 : 
                      (IC_out_addr == inst_addr_IC)? instruction : t_cur_inst;		 
wire stop = 0; //Not stopping for now  

wire  [31:0] PC = (state != RUN)? prog_address : (lw_stall | d_stall)? t_PC : 
		        		 (PCSource_EX == 0)? PC_plus4 : 
		        		 (PCSource_EX == 1)?  jumpAddr_EX : 
		        		 (PCSource_EX == 2)?  targetReg_EX : 
						  zero? (PC_EX + 4 + branchAddr_EX) :
						  i_stall?  t_PC: PC_plus4; 

// Re-adjustment of the adrresses
wire [ADDRESS_BITS-1:0] INS_out_addr; 
wire [ADDRESS_BITS-1:0] DAT_out_addr; 
wire [32-ADDRESS_BITS-1 :0] pad = 0; 	
reg  [ID_BITS - 1: 0]   program_core;
wire [ADDRESS_BITS-1:0] inst_addr = {program_core, r_inst_addr[REAL_ADDR_BITS+1:2]};
wire [ADDRESS_BITS-1:0] data_addr = {r_data_addr[ADDRESS_BITS+1:2]};

wire  [ID_BITS - 1: 0] inst_core = inst_addr_IC[ADDRESS_BITS+1 -:ID_BITS]; 
assign IC_out_addr =  {pad, inst_core, INS_out_addr[REAL_ADDR_BITS-1:0],2'b00}; 
assign DC_out_addr =  {pad, DAT_out_addr[ADDRESS_BITS-1:0], 2'b00}; 

wire forward_report; 
						  
memory_router_system #(CORE, ID_BITS, REAL_ADDR_BITS, DATA_WIDTH, INDEX_BITS, 
                            OFFSET_BITS, ADDRESS_BITS, INIT_FILE, IN_PORTS, 
                            OUT_PORTS, VC_BITS, VC_DEPTH_BITS,
                            MSG_BITS, EXTRA, TYPE_BITS, SWITCH_TO_SWITCH, 
							RT_ALG, ROW, COLUMN)  
					memory_sub_system (
                     .clock(clock), 
                     .reset(reset),
				     .i_read(fetch), 
				     .i_write(1'b0), 
				     .i_address(inst_addr), 
				     .i_in_data(0), 
					 .i_out_addr(INS_out_addr),
				     .i_out_data(instruction), 
				     .i_valid(i_valid), 
				     .i_ready(IC_ready),
				     
				     .d_read(load), 
				     .d_write(store), 
				     .d_address(data_addr), 
				     .d_in_data(data_in), 
					 .d_out_addr(DAT_out_addr),
				     .d_out_data(data_out), 
				     .d_valid(d_valid), 
				     .d_ready(DC_ready), 
				    
				     .ON(ON),   .PROG(PROG),
				     .WEn(WEn), .REn(REn),
				     .router_ID(router_ID), 
				     .rt_flowID(rt_flowID), 
				     .rt_entry(rt_entry), 

  				     .s_flits_in(s_flits_in),  
  				     .s_valid_in(s_valid_in), 
  					 .s_flits_out(s_flits_out), 
  					 .s_valid_out(s_valid_out), 
  					 .s_empty_in(s_empty_in), 
  					 .s_full_in(s_full_in), 
					 .s_empty_out(s_empty_out), 
					 .s_full_out(s_full_out), 

					 // performance and debugging 
					 .report(forward_report),
					 .fault_status(fault_status)
); 

ALU #(32) alu_unit(
		.ALU_Op(ALU_control), 
		.operand_A(op_A), 
		.operand_B(op_B), 
		.ALU_result(ALU_result), 
		.zero(zero)
); 

inst_decoder decoder (
	  .clock(clock), 
	  .reset(reset), 
	  .PC(PC_D[31:28]), 
	  .instruction(IR_D), 
	  .branch(branch), 
	  .PCSource(PCSource), 
	  .ALU_Op(ALU_Op), 
	  .operand_A(operand_A), 
	  .operand_B(operand_B), 
	  .write(write), 
	  .ws_reg(ws_reg),
	  .read2_data(read2_data),
	  .logic_r_type(logic_r_type), 
	  .zeroEXT_type(zeroEXT_type), 
	  .branchAddr(branchAddr), 
	  .jumpAddr(jumpAddr),
	  .targetReg(targetReg), 
	  .RF_write(write_WB), 
	  .RF_ws_reg(ws_reg_WB), 
	  .RF_write_data(WB_Data)
);  
           		      
always @ (posedge clock) begin
      if (reset) begin 
    		    fetch        <= 0;
    		    stall        <= 1;
    		    state        <= IDLE;
    		    r_inst_addr  <= 0; 
				inst_addr_IC <= 0;
				fetch_IC	 <= 0; 		
				
				t_cur_inst  <= 0; 
				t_cur_iValid <= 0; 
				program_core <= 0; 
    		    
    		    r_data_addr  <= 0; 
    		    data_in      <= 0;
    		    load         <= 0; 
    		    store        <= 0;
    		    load_MEM2    <= 0; 
    		    store_MEM2   <= 0;		
    		    $display (" Reset .................................");  
      end 
  	  else begin  
		 	t_cur_inst   <= (d_stall | lw_stall)? cur_inst   : 0; 
			t_cur_iValid <= (d_stall | lw_stall)? cur_iValid : 0;
			t_PC         <= PC; 
		
  	     case (state)
          	IDLE: begin
          		state <= (start)? CLEAR : IDLE; 
            end
				 
            CLEAR: begin
  		     	IR_D      <= 0; IR_EX      <= 0;  IR_MEM    <= 0;
  		     	write_EX  <= 0; write_MEM  <= 0;  write_WB  <= 0;
  		     	ws_reg_EX <= 0; ws_reg_MEM <= 0;  ws_reg_WB <= 0;
  		     	MEM_Data <=  0; WB_Data <= 0;  IR_MEM2    <= 0;
				write_MEM2 <=  0; ws_reg_MEM2  <= 0; MEM2_Data  <= 0;
				
  				op_A     <=  0; op_B    <= 0;   MD          <= 0; 	
          		branchAddr_EX    <= 0;  jumpAddr_EX         <= 0;
          		ALU_control      <= 0;
          				     	
  		        PC_plus4      <= prog_address + 4;
  		        PCSource_EX   <= 0;
				program_core  <= prog_address[ADDRESS_BITS+1 -:ID_BITS]; 
  		        state         <= INIT;
				$display (" Core [%d] Start [%b] Program [%h]", CORE, start, prog_address);
            end
            
          	INIT: begin
     	        stall     <= 0; 
         	    fetch     <= 1;
         	    PC_plus4  <= PC + 4; 
  		     	r_inst_addr <= PC; 
  		     	state     <= RUN;
  		     	$display (" Running ...............................");
            end
            
            RUN: begin
    		     // Fetch			 
          		 PC_plus4      <= kill? PC + 4 : (lw_stall | d_stall | i_stall)? PC_plus4    : PC + 4;
		         r_inst_addr   <= kill? PC     : (lw_stall | d_stall | i_stall)? r_inst_addr : PC; 
				 
				 // ICache Read
				 fetch_IC     <=  fetch;
		         inst_addr_IC <=  (d_stall | lw_stall)? inst_addr_IC : kill? 0 : i_stall? inst_addr_IC : r_inst_addr;  
          		      
          		 // Decode  
          		 IR_D         <= d_stall? IR_D : kill? 0: lw_stall? IR_D : IRSrc? cur_inst : 32'h00000000; 
          		 PC_D         <= d_stall? PC_D : kill? 0: lw_stall? PC_D : inst_addr_IC;
	             op_A	      <= d_stall? op_A : kill? 0: lw_stall? op_A: (ASource == 0)? operand_A : 
										  (ASource == 1)? ALU_result : (ASource == 2)? MEM_Data : 
										  (ASource == 3)? (IR_MEM2[31:26] == 6'b100011)? data_out : MEM2_Data :
	           					          (ASource == 4)? WB_Data : 0;
	             op_B	      <= d_stall? op_B : kill? 0: lw_stall? op_B:(BSource == 0)? operand_B : 
				                          (BSource == 1)? ALU_result : (BSource == 2)? MEM_Data : 
										  (BSource == 3)? (IR_MEM2[31:26] == 6'b100011)? data_out : MEM2_Data : 
	            				          (BSource == 4)? WB_Data : 0;
										  
          		 MD           <= d_stall? MD : kill? 0: lw_stall? MD:(MDSource == 0)? read2_data : (MDSource == 1)? 
          						            ALU_result : (MDSource == 2)? MEM_Data : 
											(MDSource == 3)? (IR_MEM2[31:26] == 6'b100011)? 
          						            data_out : MEM2_Data :(MDSource == 4)? WB_Data : 0; 
          						
          		 branchAddr_EX    <= d_stall? branchAddr_EX : kill? 0: lw_stall? branchAddr_EX : branchAddr;
          		 PCSource_EX      <= d_stall? PCSource_EX : kill? 0: lw_stall? PCSource_EX : PCSource; 
				 
				 targetReg_EX     <= d_stall? targetReg_EX : kill? 0: lw_stall? targetReg_EX : 
				                              (ASource == 0)? targetReg : (ASource == 1)? ALU_result : 
	           					              (ASource == 2)? MEM_Data : (ASource == 3)? (IR_MEM2[31:26] == 6'b100011)? 
											  data_out : MEM2_Data : (ASource == 4)? WB_Data : 0;
										  
          		 jumpAddr_EX      <= d_stall? jumpAddr_EX : kill? 0: lw_stall? jumpAddr_EX : jumpAddr;					
          		     
 		         // EXECUTE  
   		         PC_EX         <= d_stall? PC_EX : kill? 0: PC_D;
    		     IR_EX         <= d_stall? IR_EX : kill? 0: lw_stall? 0: IR_D ;
    		     write_EX      <= d_stall? write_EX : kill? 0: lw_stall? 0: write ; 
    		     ws_reg_EX     <= d_stall? ws_reg_EX : kill? 0: lw_stall? 0: ws_reg ;	     
    		     ALU_control   <= d_stall? ALU_control : kill? 0: lw_stall? 0: ALU_Op; 
  		       
    		     // Memory 
    		     IR_MEM       <= d_stall? IR_MEM: IR_EX ;
    		     write_MEM    <= d_stall? write_MEM: write_EX ; 
    		     ws_reg_MEM   <= d_stall? ws_reg_MEM: ws_reg_EX ;
    		     r_data_addr    <= d_stall? r_data_addr: ALU_result; 
    		     data_in      <= d_stall? data_in: MD;            // store data
    		     load         <= d_stall? load: (IR_EX[31:26] == 6'b100011)? 1 : 0; 
    		     store        <= d_stall? store: (IR_EX[31:26] == 6'b101011)? 1 : 0; 
        		 MEM_Data     <= d_stall? MEM_Data: (write_EX & (ws_reg_EX == 31))? (PC_EX + 4) : ALU_result;
        		 
				// Memory  Out
				 IR_MEM2        <= d_stall? IR_MEM2    : IR_MEM; 
    		     write_MEM2     <= d_stall? write_MEM2 : write_MEM ; 
    		     ws_reg_MEM2    <= d_stall? ws_reg_MEM2: ws_reg_MEM ;
    		     MEM2_Data      <= d_stall? MEM2_Data  : MEM_Data; 
				 load_MEM2	  	<= d_stall? load_MEM2  : load; 
				 store_MEM2	  	<= d_stall? store_MEM2 : store;
				 MEM2_addr	  	<= d_stall? MEM2_addr  : r_data_addr;
				 MEM2_data_in 	<= d_stall? MEM2_data_in : data_in;
				 
    		     // WriteBack
    		     write_WB     <= d_stall? write_WB : write_MEM2 ; 
    		     ws_reg_WB    <= d_stall? ws_reg_WB: ws_reg_MEM2 ;
    		     WB_Data      <= d_stall? WB_Data  : (IR_MEM2[31:26] == 6'b100011)? data_out : MEM2_Data;
    		     
    		     //End of program 
    		     state        <= (stop)? IDLE : RUN;           	
          	end
         endcase
  	  end
end

reg [31:0] cycles        = 0; 
reg [31:0] prev_inst     = 0; 
reg [31:0] inst_counter   = 0; 
reg [31:0] prev_IR       = 0;

// Performance 
always @ (posedge clock) begin 
	cycles    <= cycles + 1; 
	prev_inst <= IR_MEM2;
	prev_IR   <= IR_D; 

	if((IR_MEM2 > 0) & (IR_MEM2 != prev_inst)) begin 
		inst_counter <= inst_counter + 1; 
		//$display ("| Core [%d] Executed instruction [%h] Count [%d]", CORE, IR_MEM2, inst_counter);
	end 
	
	/*
	// Deburging 
		 $display ("-----------------------------------MIPS Core %d ------------------------------------------", CORE);   
		 $display ("| PC [%h]", PC);
		 $display ("| Next PC [%h]", PC_plus4);
		 $display ("| PC Source [%h]", PCSource);
		 $display ("| PC Src EX [%h]", PCSource_EX);
		 $display ("| Current PC [%h]", r_inst_addr); 
		 $display ("| IC Ready [%b]", IC_ready);
		 $display ("| IC Stall [%b]", i_stall);
		 $display ("| IRSrc [%b]", IRSrc ); 
		 $display ("|\t\t\t| Fetch Inst [%h]", instruction);
		 $display ("|\t\t\t| i_valid [%b]", i_valid);
		 $display ("|\t\t\t| IC_out_addr [%h]", IC_out_addr);
		 $display ("|\t\t\t| Cur Inst [%h]", cur_inst);
		 $display ("|\t\t\t| Cur i_valid [%b]", cur_iValid);		 
		 $display ("|\t\t\t| IC Read Addr [%h]", inst_addr_IC);
		 $display ("|\t\t\t|\t\t\t| LW Stall [%d]", lw_stall);
		 $display ("|\t\t\t|\t\t\t| Read 1 [%h]", operand_A);
		 $display ("|\t\t\t|\t\t\t| Read 2 [%h]", operand_B);  
		 $display ("|\t\t\t|\t\t\t| RegRead2 [%h]", read2_data); 
		 $display ("|\t\t\t|\t\t\t| Branch [%h]", branchAddr);  
		 $display ("|\t\t\t|\t\t\t| Jump   [%h]", jumpAddr); 
		 $display ("|\t\t\t|\t\t\t| Jump Reg   [%h]", targetReg);  
		 $display ("|\t\t\t|\t\t\t| Source A [%d]", ASource);
		 $display ("|\t\t\t|\t\t\t| Source B [%d]", BSource);           
		 $display ("|\t\t\t|\t\t\t| ALU_control [%d]", ALU_control);
		 $display ("|\t\t\t|\t\t\t| Branch_EX [%h]", branchAddr_EX);
		 $display ("|\t\t\t|\t\t\t| Branch Taken [%b]",zero);
		 $display ("|\t\t\t|\t\t\t| Operand A [%h]",op_A);
		 $display ("|\t\t\t|\t\t\t| Operand B [%h]", op_B);
		 $display ("|\t\t\t|\t\t\t| MD [%h] ", MD);
		 $display ("|\t\t\t|\t\t\t|\t\t\t| write_EX [%b]\t\t| write_MEM [%b]\t\t| write_MEM2 [%b]\t| write_WB [%b]",write_EX, write_MEM, write_MEM2, write_WB);
		 $display ("|\t\t\t|\t\t\t|\t\t\t| ws_reg_EX [%d]\t| ws_reg_MEM [%d]\t| ws_reg_MEM2 [%d]\t| ws_reg_WB [%d]",ws_reg_EX, ws_reg_MEM, ws_reg_MEM2, ws_reg_WB);
		 $display ("|\t\t\t|\t\t\t| IR_D [%h]\t| IR_EX [%h]\t| IR_MEM [%h]\t| IR_MEM2 [%h]",IR_D, IR_EX, IR_MEM, IR_MEM2);
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| load [%b]\t\t| MEM2_load [%b]", load, load_MEM2);
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| store [%b]\t\t| MEM2_store [%b]", store, store_MEM2);
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| Data_addr [%h]\t| MEM2_addr [%h]", r_data_addr, MEM2_addr);
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| Data_in [%h]\t| MEM2_Data_in [%h]", data_in, MEM2_data_in);  
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t|\t\t\t| d_stall [%b]", d_stall); 
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t|\t\t\t| d_valid [%b]", d_valid); 
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t|\t\t\t| DC_out_addr [%h]", DC_out_addr); 
		 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| MEM_Data [%h]\t| MEM2_Data [%h]\t| WB_Data [%h]",MEM_Data, MEM2_Data, WB_Data);
		 $display ("----------------------------------------------------------------------------------------");   
	 //*/
end

//Register $s0-$s7 [16-23] are saved across a call ... Heracles [17-20] for final results
wire reserved_reg = (write_WB & ((ws_reg_WB >= 17) & (ws_reg_WB <= 20))); 
wire reg_reset    = ((inst_counter < 25) & (WB_Data ==0)); // Initial reset

reg result_report; 
always @ (posedge clock) begin            
	if (reserved_reg & ~reg_reset)  begin
		to_peripheral       <= 0;
		to_peripheral_data  <= WB_Data ; 
		to_peripheral_valid <= 1;
		$display ("-------------------------- CORE %d -----------------------------------", CORE);
		$display (" Result: Register [%d] Value = %d", ws_reg_WB, WB_Data);
		$display (" Current cycles [%d] instructions executed [%d]", cycles, inst_counter);
		$display ("-------------------------------------------------------------------------------");
	end
	else to_peripheral_valid <= 0;  
	if (report & start)  begin
		$display ("-------------------------- CORE %d -----------------------------------", CORE);
		$display (" Current cycles [%d] instructions executed [%d]", cycles, inst_counter);
		$display ("-------------------------------------------------------------------------------");
	end
	
	result_report <= reset? 0 : (reserved_reg & ~reg_reset); //change this logic for multiple prints.
end

//Finish or report activation 
assign forward_report = ((report | result_report) & start); 

endmodule
