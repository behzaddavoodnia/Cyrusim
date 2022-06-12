
/** @module : ALU
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

module ALU #(parameter DATA_WIDTH = 32)(
		ALU_Op, 
		operand_A, operand_B, 
		ALU_result, zero
); 
input [3:0] ALU_Op; 
input [DATA_WIDTH-1:0]  operand_A ;
input [DATA_WIDTH-1:0]  operand_B ;
output zero; 
output [DATA_WIDTH-1:0] ALU_result;

assign zero = (ALU_result==0); 
assign ALU_result   = (ALU_Op == 0)? operand_A + operand_B : 
					  (ALU_Op == 1)? operand_A & operand_B :
					  (ALU_Op == 2)? ~(operand_A | operand_B) :
					  (ALU_Op == 3)? operand_A | operand_B :
					  (ALU_Op == 4)? operand_A << operand_B :
					  (ALU_Op == 5)? (operand_A < operand_B)? 1 : 0 :
					  (ALU_Op == 6)? operand_A >> operand_B :
					  (ALU_Op == 7)? operand_A >>> operand_B :
					  (ALU_Op == 8)? operand_A - operand_B :
					  (ALU_Op == 9)? operand_A ^ operand_B :
					  (ALU_Op == 10)? (operand_A == operand_B)? 0 : 1  :
					  (ALU_Op == 11)? (operand_A >= operand_B)? 0 : 1  :
					  (ALU_Op == 12)? (operand_A > operand_B)? 0 : 1  :
					  (ALU_Op == 13)? (operand_A <= operand_B)? 0 : 1  :
					  (ALU_Op == 14)? (operand_A < operand_B)? 0 : 1  :
					  (ALU_Op == 15)? (operand_A != operand_B)? 0 : 1  : 1;
endmodule
