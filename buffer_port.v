
/** @module : buffer_port
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
//`include "fifo.v" 
 
module buffer_port #(parameter DATA_WIDTH = 32, BUF_BITS = 1, Q_DEPTH_BITS = 3, Q_IN_BUFFERS = 2) (
    input clk,
    input reset,
    
    input wrtEn,
    input [DATA_WIDTH - 1:0]  write_data,
	input [BUF_BITS - 1:0]    in_vc, 

    input rdEn,	
    input peek,
	input [BUF_BITS - 1:0]    read_vc, 
	
    output [DATA_WIDTH - 1:0] read_data, 
	output [BUF_BITS - 1:0]   out_vc, 
	output valid, 
	
	output [(1 << BUF_BITS) -1:0] empty, 
	output [(1 << BUF_BITS) -1:0] full 
); 

  localparam BUF_PER_PORT = 1 << BUF_BITS; 
  
  reg [DATA_WIDTH - 1:0] b_write_data [0:BUF_PER_PORT-1];
  reg b_wrtEn[0:BUF_PER_PORT-1];
  reg b_rdEn [0:BUF_PER_PORT-1];
  reg b_peek [0:BUF_PER_PORT-1];

  wire b_valid [0:BUF_PER_PORT-1];
  wire [DATA_WIDTH - 1:0] b_read_data [0:BUF_PER_PORT-1];
  
  
  localparam IDLE = 0, WRITE = 1, READ = 1; 
  reg w_state; 
  reg [BUF_BITS - 1:0] written_vc;
  
  reg r_state;
  reg [BUF_BITS - 1:0] prev_read_vc;
  
  genvar i;
  integer vc;
 
  generate
 	for (i=0; i < BUF_PER_PORT; i=i+1) begin : BUFFERS
		fifo  #(DATA_WIDTH, Q_DEPTH_BITS, Q_IN_BUFFERS) U (
			clk,
			reset,
			b_write_data[i], 
			b_wrtEn[i], 
			b_rdEn[i],
			b_peek[i], 
 
			b_read_data [i], 
			b_valid[i],			
			full[i], 
			empty[i] 
		);
	end
   endgenerate

//--------------Code Starts Here----------------------- 
always @ (posedge clk) begin
  if (reset) begin 
     w_state      <= IDLE;  
     r_state      <= IDLE; 
	 written_vc   <= 0; 
	 prev_read_vc <= 0; 
     
     for (vc = 0; vc < BUF_PER_PORT; vc = vc+1) begin 
          b_wrtEn[vc] <= 0;  
		  b_rdEn [vc] <= 0; 
		  b_peek[vc]  <= 0;
      end
  end 
  else begin 
      case (w_state)
      	IDLE: begin 
			w_state             <= (wrtEn)? WRITE : IDLE; 
			b_write_data[in_vc] <= write_data;
		    b_wrtEn[in_vc]      <= wrtEn;
		    written_vc 	        <= in_vc; 
		end 
      	WRITE: begin 
			w_state             <= (wrtEn)? WRITE : IDLE; 
			b_write_data[in_vc] <= write_data;
		    b_wrtEn[in_vc]      <= wrtEn;
		    written_vc 	        <= in_vc; 
			if (written_vc != in_vc) begin 
				b_wrtEn[written_vc]   <= 0;
			end 
		end 
      endcase  
  
      case (r_state)
      	IDLE: begin 
			prev_read_vc    <= read_vc;
			r_state         <= (rdEn | peek)? READ : IDLE; 
			b_rdEn[read_vc] <= rdEn;
			b_peek[read_vc] <= peek;
			
      		// if(rdEn | peek) begin
  	      		// if(rdEn) $display ("Dequeue data req on Q: %d", read_vc);
  	      		// else $display ("Peeked data req on Q: %d", read_vc);
      		// end
		end
      	READ: begin 
			prev_read_vc    <= read_vc;
			r_state         <= (rdEn | peek)? READ : IDLE; 
			b_rdEn[read_vc] <= rdEn;
			b_peek[read_vc] <= peek;
			
			if (prev_read_vc != read_vc) begin
				b_rdEn[prev_read_vc] <= 0;  
				b_peek[prev_read_vc] <= 0;
			end
			
      		if(rdEn | peek) begin 		
  	      		if(~b_valid[prev_read_vc]) begin
  	      			$display ("ERROR_1: On dequeue or peek req response!");
  	      		end		 
  	      		//if(rdEn) $display ("Dequeue data req on Q: %d", read_vc);
  	      		//else $display ("Peeked data req on Q: %d", read_vc);  
      		end 
      		else begin
  	      			if(~b_valid[prev_read_vc]) begin
  	      				$display ("ERROR_2: On dequeue or peek req response!");
  	      			end	
      		end  
		end
      endcase    

   end             
end

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
	assign read_data   = (b_valid[prev_read_vc])? b_read_data [prev_read_vc]: 0; 
	assign out_vc      = prev_read_vc;
    assign valid       = (b_valid[prev_read_vc])? 1 : 0;
    
endmodule
