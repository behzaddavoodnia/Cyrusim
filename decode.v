
/** @module : decode
 *  @author : Behzad Davoodnia
 
 *  Copyright (c) 2010 Heracles (CSG/CSAIL/MIT)
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
 */
module inst_decoder (
	  clock, reset, PC, instruction, 
	  branch, PCSource, ALU_Op, operand_A, operand_B, 
	  write, ws_reg,
	  read2_data,
	  logic_r_type, zeroEXT_type, 
	  branchAddr, jumpAddr, targetReg,
	  RF_write, RF_ws_reg, RF_write_data
); 
 
    input  clock; 
    input  reset; 
	input  [3:0]  PC;
    input  [31:0]  instruction; 
    input  RF_write;
    input  [4:0]  RF_ws_reg;
    input  [31:0] RF_write_data;
    
   output branch; 
   output [2:0] PCSource ;   
   output [3:0] ALU_Op; 
   output [31:0]  operand_A ; 
   output [31:0]  operand_B ;  
   output [31:0]  read2_data; 
   output logic_r_type;
   output zeroEXT_type;              
   output [4:0]   ws_reg ; 
   output write ; 	
   output [31:0]  targetReg;  
   output [31:0]  branchAddr; 
   output [31:0]  jumpAddr;    
       
   wire [5:0]   opcode = instruction[31:26]; 
   wire [4:0]   rs     = instruction[25:21];
   wire [4:0]   rt     = instruction[20:16];
   wire [4:0]   rd     = instruction[15:11];
   wire [4:0]   shamt  = instruction[10:6];
   wire [5:0]   funct  = instruction[5:0];
   wire [15:0]  immediate   = instruction[15:0];
   wire [25:0]  address     = instruction[25:0];
   wire [31:0]  signExtImm  = (immediate[15])? {16'hFFFF, immediate}: {16'h0000, immediate};
   wire [31:0]  zeroExtImm  = {16'h0000, immediate};  
   wire [31:0]  shamtExt    = {27'h0000000, shamt};
   wire [31:0]  rs_data, rt_data; 
   
   //No logic for LUI for now
   wire  LW     = (opcode == 6'b100011);
   wire  SW     = (opcode == 6'b101011); 
   wire  ADD    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100000);
   wire  ADDI   = (opcode == 6'b001000);
   wire  ADDIU  = (opcode == 6'b001001);
   wire  ADDU   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100001);
   wire  AND    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100100);
   wire  ANDI   = (opcode == 6'b001100);
   wire  NOR    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100111);
   wire  OR     = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100101);
   wire  ORI    = (opcode == 6'b001101); 
   wire  LUI    = (opcode == 6'b001111) & (rs == 5'b00000);  
   wire  SLL    = (opcode == 6'b000000) & (rs == 5'b00000) & (funct == 6'b000000);
   wire  SLLV   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b000100); 
   wire  SLT    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b101010);
   wire  SLTI   = (opcode == 6'b001010);
   wire  SLTIU  = (opcode == 6'b001011);
   wire  SLTU   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b101011);
   wire  SRA    = (opcode == 6'b000000) & (rs == 5'b00000) & (funct == 6'b000011);
   wire  SRAV   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b000111);
   wire  SRL    = (opcode == 6'b000000) & (rs == 5'b00000) & (funct == 6'b000010);
   wire  SRLV   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b000110);
   wire  SUB    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100010);
   wire  SUBU   = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100011);
   wire  XOR    = (opcode == 6'b000000) & (shamt == 5'b00000) & (funct == 6'b100110);
   wire  XORI   = (opcode == 6'b001110);  
   wire  BEQ     = (opcode == 6'b000100);
   wire  BGEZ    = (opcode == 6'b000001) & (rt == 5'b00001);
   wire  BGTZ    = (opcode == 6'b000111) & (rt == 5'b00000);
   wire  BLEZ    = (opcode == 6'b000110) & (rt == 5'b00000);
   wire  BLTZ    = (opcode == 6'b000001) & (rt == 5'b00000);
   wire  BNE     = (opcode == 6'b000101);   
   wire  J       = (opcode == 6'b000010);
   wire  JAL     = (opcode == 6'b000011);
   wire  JALR    = (opcode == 6'b000000) & (funct == 6'b001001);  
   wire  JR      = (opcode == 6'b000000) & (funct == 6'b001000);
   wire r_type  = (ADD | ADDU | AND | NOR | OR | SLL | SLLV | 
   				   SLT | SLTU | SRA | SRAV| SRL | SRLV | SUB |
   				   SUBU | XOR); 
   wire i_type_we      = (ADDI | ADDIU | ANDI | LW | ORI | SLTI | SLTIU | XORI);
   
   assign logic_r_type   = (SLL | SRL | SRA);
   assign zeroEXT_type   = (SW | i_type_we);

   
   assign branch   = BEQ  | BGEZ | BGTZ | BLEZ  | BLTZ | BNE;
   assign PCSource = (J | JAL)? 1 : (JALR | JR)? 2 : branch? 3: 0;  
   assign ALU_Op   = (LW | SW | ADD | ADDI | ADDIU | ADDU)? 0 : 
   				 (AND | ANDI)? 1: 
   				  NOR? 2: (OR | ORI)? 3:
   				 (SLL | SLLV)? 4:
   				 (SLT | SLTI | SLTIU | SLTU)? 5:
   				 (SRA | SRAV)? 6:
   				 (SRL | SRLV)? 7:
   				 (SUB | SUBU)? 8:
   				 (XOR | XORI)? 9:
				  BEQ? 10: BGEZ? 11: BGTZ? 12:  BLEZ? 13: BLTZ? 14: BNE? 15: 0; 
  assign  operand_A = (SLL | SRA |SRL )? rt_data : rs_data;  
  assign  operand_B = (ADD | ADDU | AND | NOR | OR | SLLV | SLT | SLTU | SRAV | SRLV 
  							| SUB | SUBU | XOR | BEQ | BGEZ | BGTZ | BLEZ | BLTZ | BNE)? rt_data: 
				  			(LW | SW | ADDI | ADDIU | SLTI | SLTIU)? signExtImm:
        		    (ADDI | ORI | XORI)? zeroExtImm: (SLL | SRA |SRL )? shamtExt: 0;
 assign read2_data = rt_data;              
 assign ws_reg = (JALR | JAL)? 31 : r_type? rd : rt; 
 assign write = (JALR | JAL)? 1 : r_type? 1 : i_type_we? 1 : 0; 	
 assign targetReg  = rs_data; 
 assign branchAddr = (immediate[15])? {14'h3FFF, immediate, 2'b00}: {14'h0000, immediate, 2'b00}; 
 assign jumpAddr  = {PC, address, 2'b00};
 	  
regFile #(32, 5) registers (
				.clock(clock), 
				.reset(reset), 
				.read_sel1(rs), 
				.read_sel2(rt),
				.wEn(RF_write), 
				.write_sel(RF_ws_reg), 
				.write_data(RF_write_data), 
				.read_data1(rs_data), 
				.read_data2(rt_data)
);
endmodule
