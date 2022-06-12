`timescale 1ns/1ns
/** @module : tb_Real_Cores_Mesh_top
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
//`include "tb_Real_Cores_Mesh.v"

module tb_Real_Cores_Mesh_top (
); 

    
wire [31: 0] data; 
wire valid;
reg cmd; 
reg Bus2IP_Reset;
reg Bus2IP_Clk; 
integer outfile3,outfile2,outfile1,outfile0,dBlockCache0,i,grantFile;     
wire [14:0] req_ports; 
assign output0 = data[0];

 parameter cacheLines=12  ;
// Connect the DUT
Real_Cores_Mesh_Wrapper TB_M(.clock(Bus2IP_Clk), .RST(Bus2IP_Reset), .cmd(cmd), .data(data), .valid(valid));  
  
// Clock generator
always #1 Bus2IP_Clk = ~Bus2IP_Clk;

initial begin
   grantFile=$fopen("grantFile.txt","w");
 outfile0=$fopen("regfile0.txt","w");
 outfile1=$fopen("regfile1.txt","w");
  outfile2=$fopen("regfile2.txt","w");
 outfile3=$fopen("regfile3.txt","w");
  $display (" --- Start --- ");
  Bus2IP_Clk <= 0; 
  Bus2IP_Reset <= 1; 
  repeat (1) @ (posedge Bus2IP_Clk);
  Bus2IP_Reset <= 0; 
  cmd <= 0;
  repeat (10) @ (posedge Bus2IP_Clk);
  
  cmd <= 1;
  repeat (300) @ (posedge Bus2IP_Clk);
 // $stop;
  
end

reg [31:0] counter=0;
always  @(posedge Bus2IP_Clk)
counter=counter+1;

always  @(posedge Bus2IP_Clk)
begin
showRequestAndGrantsStatus;
 if (counter==7500) begin
saveCacheBlocksContents;
$fclose(grantFile);
$stop;
end
end


always @ (posedge Bus2IP_Clk)
  if(valid) 
begin
  $display ("Data [%h]", data);
    saveImemContents;
	if (data==0)
	begin
	saveCacheBlocksContents;
$fclose(grantFile);
	$stop;
	end
end  

///////////////  task for leading instructions into i memory
task saveImemContents; begin
  //$readmemb("matrix_c0_c0.mem", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.mem_packetizer.m_memory.RAM_Block.ram);
  //$readmemb("fibonacci_c1_c1.mem", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.memory_sub_system.mem_packetizer.m_memory.RAM_Block.ram);
  
 // $writememb("imem0.txt", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.mem_packetizer.m_memory.RAM_Block.ram);
   // $writememb("imem1.txt", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.memory_sub_system.mem_packetizer.m_memory.RAM_Block.ram);
	 //$writememh("dcach0.txt", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram);

  end
  endtask  
  ///////////////////////////
always@(posedge Bus2IP_Clk) begin
//    if(counter == 400)    // stop after 60 cycles
  //      $stop;
      
    // print PC
   // $fdisplay(outfile0, "PC = %d", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.PC_plus4);
    // // print Registers
    // $fdisplay(outfile0, "Registers");
    // $fdisplay(outfile0, "R0(r0) =%d, R8 (t0) =%d, R16(s0) =%d, R24(t8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[0],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[8] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[16],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[24]);
    // $fdisplay(outfile0, "R1(at) =%d, R9 (t1) =%d, R17(s1) =%d, R25(t9) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[1],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[9] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[17],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[25]);
    // $fdisplay(outfile0, "R2(v0) =%d, R10(t2) =%d, R18(s2) =%d, R26(k0) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[2],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[10],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[18],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[26]);
    // $fdisplay(outfile0, "R3(v1) =%d, R11(t3) =%d, R19(s3) =%d, R27(k1) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[3],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[11],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[19],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[27]);
    // $fdisplay(outfile0, "R4(a0) =%d, R12(t4) =%d, R20(s4) =%d, R28(gp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[4],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[12],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[20],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[28]);
    // $fdisplay(outfile0, "R5(a1) =%d, R13(t5) =%d, R21(s5) =%d, R29(sp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[5],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[13],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[21],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[29]);
    // $fdisplay(outfile0, "R6(a2) =%d, R14(t6) =%d, R22(s6) =%d, R30(s8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[6],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[14],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[22],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[30]);
    // $fdisplay(outfile0, "R7(a3) =%d, R15(t7) =%d, R23(s7) =%d, R31(ra) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[7],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[15],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[23],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.decoder.registers.register_file[31]);

	end
  ///////////////////// core 4 registers value
  always@(posedge Bus2IP_Clk) begin
//    if(counter == 400)    // stop after 60 cycles
  //      $stop;
      
    // print PC
   // $fdisplay(outfile1, "PC = %d", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.PC_plus4);
    // // print Registers
    // $fdisplay(outfile1, "Registers");
    // $fdisplay(outfile1, "R0(r0) =%d, R8 (t0) =%d, R16(s0) =%d, R24(t8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[0],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[8] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[16],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[24]);
    // $fdisplay(outfile1, "R1(at) =%d, R9 (t1) =%d, R17(s1) =%d, R25(t9) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[1],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[9] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[17],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[25]);
    // $fdisplay(outfile1, "R2(v0) =%d, R10(t2) =%d, R18(s2) =%d, R26(k0) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[2],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[10],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[18],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[26]);
    // $fdisplay(outfile1, "R3(v1) =%d, R11(t3) =%d, R19(s3) =%d, R27(k1) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[3],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[11],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[19],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[27]);
    // $fdisplay(outfile1, "R4(a0) =%d, R12(t4) =%d, R20(s4) =%d, R28(gp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[4],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[12],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[20],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[28]);
    // $fdisplay(outfile1, "R5(a1) =%d, R13(t5) =%d, R21(s5) =%d, R29(sp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[5],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[13],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[21],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[29]);
    // $fdisplay(outfile1, "R6(a2) =%d, R14(t6) =%d, R22(s6) =%d, R30(s8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[6],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[14],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[22],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[30]);
    // $fdisplay(outfile1, "R7(a3) =%d, R15(t7) =%d, R23(s7) =%d, R31(ra) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[7],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[15],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[23],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[1].NODES.decoder.registers.register_file[31]);

	end
  ///////////////////// core 4 registers value
  always@(posedge Bus2IP_Clk) begin
//    if(counter == 400)    // stop after 60 cycles
  //      $stop;
      
    // print PC
   // $fdisplay(outfile2, "PC = %d", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.PC_plus4);
    // // print Registers
    // $fdisplay(outfile2, "Registers");
    // $fdisplay(outfile2, "R0(r0) =%d, R8 (t0) =%d, R16(s0) =%d, R24(t8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[0],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[8] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[16],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[24]);
    // $fdisplay(outfile2, "R1(at) =%d, R9 (t1) =%d, R17(s1) =%d, R25(t9) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[1],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[9] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[17],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[25]);
    // $fdisplay(outfile2, "R2(v0) =%d, R10(t2) =%d, R18(s2) =%d, R26(k0) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[2],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[10],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[18],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[26]);
    // $fdisplay(outfile2, "R3(v1) =%d, R11(t3) =%d, R19(s3) =%d, R27(k1) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[3],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[11],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[19],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[27]);
    // $fdisplay(outfile2, "R4(a0) =%d, R12(t4) =%d, R20(s4) =%d, R28(gp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[4],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[12],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[20],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[28]);
    // $fdisplay(outfile2, "R5(a1) =%d, R13(t5) =%d, R21(s5) =%d, R29(sp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[5],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[13],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[21],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[29]);
    // $fdisplay(outfile2, "R6(a2) =%d, R14(t6) =%d, R22(s6) =%d, R30(s8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[6],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[14],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[22],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[30]);
    // $fdisplay(outfile2, "R7(a3) =%d, R15(t7) =%d, R23(s7) =%d, R31(ra) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[7],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[15],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[23],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[2].NODES.decoder.registers.register_file[31]);

	end
  
  ///////////////////// core 4 registers value
  always@(posedge Bus2IP_Clk) begin
//    if(counter == 400)    // stop after 60 cycles
  //      $stop;
      
    // // print PC
   // $fdisplay(outfile3, "PC = %d", tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.PC_plus4);
    // // print Registers
    // $fdisplay(outfile3, "Registers");
    // $fdisplay(outfile3, "R0(r0) =%d, R8 (t0) =%d, R16(s0) =%d, R24(t8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[0],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[8] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[16],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[24]);
    // $fdisplay(outfile3, "R1(at) =%d, R9 (t1) =%d, R17(s1) =%d, R25(t9) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[1],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[9] ,     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[17],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[25]);
    // $fdisplay(outfile3, "R2(v0) =%d, R10(t2) =%d, R18(s2) =%d, R26(k0) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[2],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[10],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[18],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[26]);
    // $fdisplay(outfile3, "R3(v1) =%d, R11(t3) =%d, R19(s3) =%d, R27(k1) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[3],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[11],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[19],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[27]);
    // $fdisplay(outfile3, "R4(a0) =%d, R12(t4) =%d, R20(s4) =%d, R28(gp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[4],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[12],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[20],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[28]);
    // $fdisplay(outfile3, "R5(a1) =%d, R13(t5) =%d, R21(s5) =%d, R29(sp) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[5],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[13],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[21],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[29]);
    // $fdisplay(outfile3, "R6(a2) =%d, R14(t6) =%d, R22(s6) =%d, R30(s8) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[6],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[14],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[22],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[30]);
    // $fdisplay(outfile3, "R7(a3) =%d, R15(t7) =%d, R23(s7) =%d, R31(ra) =%d",     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[7],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[15],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[23],     tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[3].NODES.decoder.registers.register_file[31]);

	end
  
  task saveCacheBlocksContents; begin 
  dBlockCache0=$fopen("dBlockCache0.txt","w");
  for (i=0;i<2**cacheLines;i=i+1) begin
$fdisplay(dBlockCache0,"#block7=%d -#block6=%d -#block5=%d -#block4=%d -#block3=%d -#block2=%d - #block1=%d - #block0=%d -",
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][255:224],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][223:192],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][191:160],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][159:128],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][127:96],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][95:64],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][63:32],
tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE1[4].NODES.memory_sub_system.mem_packetizer.unified.DCache.CACHE.CACHE_RAM.ram[i][31:0]
);
end
$fclose(dBlockCache0);
  end
  endtask 
 
 //assign req_ports=tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.network_Interface.RT.ARB.req_ports;
  //
task showRequestAndGrantsStatus; begin
  //$fdisplay(grantFile,"requests is : %b and grants is : %b and req_ports= %d %d %d %d %d  \n",tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.network_Interface.RT.ARB.requests,tb_Real_Cores_Mesh_top.TB_M.U.MESH_NODE[0].NODES.memory_sub_system.network_Interface.RT.ARB.grants,
  //req_ports[14:12],req_ports[11:9],req_ports[8:6],req_ports[5:3],req_ports[2:0]
  //);
  end
  endtask    
  
  
  
  endmodule
