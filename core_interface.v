
/** @module : core_interface
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

module core_interface  #(parameter FLIT_WIDTH = 32, IN_PORTS  = 1, 
						 OUT_PORTS  = 1, VC_PER_IN_PORTS = 2)(
  input  clk, reset, WEn, REn, 
  input  [(FLIT_WIDTH * IN_PORTS) -1:0] from_core_flit,
  input  [IN_PORTS-1: 0] v_from_core,
  
  output [(FLIT_WIDTH * OUT_PORTS) -1:0] to_core_flit,
  output [OUT_PORTS-1: 0] v_to_core,
  output [(FLIT_WIDTH * OUT_PORTS) -1:0] to_router_flit,
  output [OUT_PORTS-1: 0] v_to_router,
  
  input  [(FLIT_WIDTH * IN_PORTS) -1:0] from_router_flit,
  input  [IN_PORTS-1: 0] v_from_router,
  
  input  [(VC_PER_IN_PORTS * IN_PORTS) -1:0] from_router_empty,
  input  [(VC_PER_IN_PORTS * IN_PORTS) -1:0] from_router_full,
  input  [(VC_PER_IN_PORTS * IN_PORTS) -1:0] from_core_empty,
  input  [(VC_PER_IN_PORTS * IN_PORTS) -1:0] from_core_full, 
 
  output [(VC_PER_IN_PORTS * IN_PORTS) -1:0] to_router_empty,
  output [(VC_PER_IN_PORTS * IN_PORTS) -1:0] to_router_full,
  output [(VC_PER_IN_PORTS * IN_PORTS) -1:0] to_core_empty,
  output [(VC_PER_IN_PORTS * IN_PORTS) -1:0] to_core_full	 
); 
  
  wire [FLIT_WIDTH -1:0] t_from_core_flit[0:IN_PORTS-1];
  wire t_v_from_core  [0:IN_PORTS-1];
  wire [FLIT_WIDTH -1:0] t_from_router_flit[0:IN_PORTS-1];
  wire t_v_from_router  [0:IN_PORTS-1];
 
  reg [FLIT_WIDTH -1:0] t_to_core_flit[0:OUT_PORTS-1];
  reg t_v_to_core[0:OUT_PORTS-1];
  reg [FLIT_WIDTH -1:0] t_to_router_flit[0:OUT_PORTS-1];
  reg t_v_to_router[0:OUT_PORTS-1];
    
  reg  [FLIT_WIDTH -1:0] c_buffers[0:IN_PORTS-1];
  reg  [FLIT_WIDTH -1:0] s_buffers[0:IN_PORTS-1];
  reg  c_valid[0:IN_PORTS-1];
  reg  s_valid[0:IN_PORTS-1];
    
  integer i; 
  
  genvar j;
  generate
      	for (j = 0; j < IN_PORTS; j = j+1) begin : CPORTS
      	 	assign t_from_core_flit[j]   = from_core_flit[((FLIT_WIDTH *(j + 1))-1) -: FLIT_WIDTH];
      	 	assign t_v_from_core[j]      = v_from_core[j];
      	 	assign t_from_router_flit[j] = from_router_flit[((FLIT_WIDTH *(j + 1))-1) -: FLIT_WIDTH]; 
      	 	assign t_v_from_router[j]    = v_from_router[j]; 
      	end  	
  endgenerate 
  
  //--------------Code Starts Here----------------------- 
  always @ (posedge clk) begin
  if (reset) begin
    for (i = 0; i < OUT_PORTS; i = i+1) begin
       t_v_to_core[i]   <= 0;  
       t_v_to_router[i] <= 0;
    end
  end 
  else begin
      // Assuming that IN_PORTS = OUT_PORTS
      for (i = 0; i < IN_PORTS; i = i+1) begin
      	c_valid[i] <=  (REn & t_v_from_core[i])? 1: (WEn & c_valid[i])? 0: c_valid[i]; 
      	s_valid[i] <=  (REn & t_v_from_router[i])? 1: (WEn & s_valid[i])? 0: s_valid[i]; 
      end 
      
      if(REn)
      	for (i = 0; i < IN_PORTS; i = i+1) begin
      	   if(t_v_from_core[i]) begin
      	        c_buffers[i] <= t_from_core_flit[i];
      	   end
      	   if(t_v_from_router[i]) begin
      	       s_buffers[i]  <= t_from_router_flit[i];
      	   end  
      	end   
          
      if(WEn)
      	for (i = 0; i < OUT_PORTS; i = i+1) begin
           if(s_valid[i]) begin
           		t_v_to_core[i]    <= 1; 
           		t_to_core_flit[i] <= s_buffers[i];
           end   
           else t_v_to_core[i]    <= 0;
           
           if(c_valid[i]) begin
           		t_v_to_router[i]    <= 1; 
           		t_to_router_flit[i] <= c_buffers[i]; 
           end 
           else  t_v_to_router[i]   <= 0;     	     
      	end 
      else 
      	for (i = 0; i < OUT_PORTS; i = i+1) begin
          t_v_to_core[i]   <= 0;
          t_v_to_router[i] <= 0;     	     
      	end 
  end 
  end
  
  
//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
  generate
      	for (j = 0; j < OUT_PORTS; j = j+1) begin : C_OUT
           	assign to_core_flit[(((j + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH] = t_to_core_flit[j];
           	assign v_to_core[j] = t_v_to_core[j]; 
           	assign to_router_flit[(((j + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH] = t_to_router_flit[j];
           	assign v_to_router[j] = t_v_to_router[j];
      	end  	
  endgenerate 
  
  assign to_core_empty = from_router_empty;
  assign to_core_full = from_router_full;
  assign to_router_empty = from_core_empty;
  assign to_router_full =  from_core_full;
           		
endmodule
