
/** @module : arbiter
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
//----------------------------------------------------
// Parameterized weak round-robin arbiter.
//----------------------------------------------------
module arbiter #(parameter IN_PORTS = 5, OUT_PORT_BITS = 3) (
    input  clk,
    input  reset,
 	input  [IN_PORTS - 1:0]                   requests, 
	input  [(IN_PORTS * OUT_PORT_BITS) - 1:0] req_ports, 
	output [IN_PORTS - 1:0]                   grants
);

//--------------Internal Registers----------------------
reg   [OUT_PORT_BITS - 1: 0]   port_priority [IN_PORTS - 1:0]; // to store temporary values 
reg   [IN_PORTS - 1: 0]        temp_grants; 
wire  [OUT_PORT_BITS - 1: 0]   p_req_ports [IN_PORTS - 1:0]; // to store temporary values
reg   [OUT_PORT_BITS - 1: 0] turn; 

integer i; 
genvar j;
generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : ARB_PORTS
      		assign p_req_ports[j] = req_ports [(((j + 1) *OUT_PORT_BITS)-1) -: OUT_PORT_BITS]; 
  	   end
endgenerate 

//--------------Code Starts Here----------------------- 
always @ (posedge clk)
	if (reset) begin
		for (i = 0; i < IN_PORTS; i = i + 1) begin
  			port_priority  [i]  = 0;
  			temp_grants [i]     = 0;
  		end 
	end 
    else begin  
        temp_grants = 0; // resetting  
    
  		for (i = 0; i < IN_PORTS; i = i + 1) begin
  			port_priority[i] = turn; 
  		end 

 	    for (i = 0; i < IN_PORTS; i = i + 1) begin
		   //$display (" Port :  %d requesting: %d request bit: %b priority: %b ", i, p_req_ports [i], 
		   //           requests [i], port_priority[p_req_ports [i]]); 
  			if (requests [i]) begin
    	          if (port_priority[p_req_ports [i]] == i) begin
    	              temp_grants[i] = 1;  
    	          end
	             else begin 
    	                 if ((p_req_ports[i] != p_req_ports[port_priority[p_req_ports [i]]]) 
  	                       | (~requests[port_priority[p_req_ports [i]]]))begin
    	                   temp_grants[i] = 1; 
    	                   port_priority[p_req_ports [i]] = i;  
    	                 end    
	             end 
	       end
 	  end 
    	//$display ("Requests:      %b ",  requests);
    	//$display ("Granted :      %b ", grants); 	  
	end

//----------------------------------------------------
// To change priority
//----------------------------------------------------	
always @ (posedge clk)
     turn <= ((turn >= IN_PORTS - 1)| reset)? 0: turn + 1;

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
	assign grants   = temp_grants;
	 
endmodule



