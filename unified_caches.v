/** @module : unified_caches
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
 */

// Two cahces: Instruction and Data caches, but with unified back-end that can be attached to 
// a level 2 unified cache or main memory 
 module unified_caches #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
                     OFFSET_BITS = 3, ADDRESS_BITS = 20, MSG_BITS = 4)(
                     clock, reset,
                     
				     read, write, address, in_data, 
				     out_address, out_data, valid, ready,
				     
				     //Caches2Memory
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data, 
				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data, 
					 // performance reporting
					 report
 ); 

input clock, reset; 
//Core2Cache
input [1:0] read, write;
input [(2*ADDRESS_BITS)-1:0] address;
input [(2*DATA_WIDTH)-1:0] in_data;

output [1:0] valid, ready;
output [(2*ADDRESS_BITS)-1:0] out_address;
output[(2*DATA_WIDTH)-1:0] out_data;

input [(MSG_BITS * 2)-1:0]     mem2cache_msg; 
input [(ADDRESS_BITS * 2)-1:0] mem2cache_address; 
input [(DATA_WIDTH * 2)-1:0]   mem2cache_data;

output [(MSG_BITS * 2)-1:0]      cache2mem_msg; 
output [(ADDRESS_BITS * 2)-1:0] cache2mem_address; 
output [(DATA_WIDTH * 2)-1:0]   cache2mem_data;
input  report;

wire [MSG_BITS-1:0]      i_mem2cache_msg; 
wire [ADDRESS_BITS-1:0]  i_mem2cache_address; 
wire [DATA_WIDTH-1:0]    i_mem2cache_data;
 				     
wire [MSG_BITS-1:0]     i_cache2mem_msg; 
wire [ADDRESS_BITS-1:0] i_cache2mem_address; 
wire [DATA_WIDTH-1:0]   i_cache2mem_data;

wire [MSG_BITS-1:0]      d_mem2cache_msg; 
wire [ADDRESS_BITS-1:0]  d_mem2cache_address; 
wire [DATA_WIDTH-1:0]    d_mem2cache_data;
 				     
wire [MSG_BITS-1:0]     d_cache2mem_msg; 
wire [ADDRESS_BITS-1:0] d_cache2mem_address; 
wire [DATA_WIDTH-1:0]   d_cache2mem_data;

wire [ADDRESS_BITS-1:0]  i_address;
wire [ADDRESS_BITS-1:0]  d_address;
wire [DATA_WIDTH-1:0]    i_in_data;
wire [DATA_WIDTH-1:0]    d_in_data;
wire [ADDRESS_BITS-1:0]  i_out_addr;
wire [ADDRESS_BITS-1:0]  d_out_addr;
wire [DATA_WIDTH-1:0]    i_out_data;
wire [DATA_WIDTH-1:0]    d_out_data;

assign i_mem2cache_msg     = mem2cache_msg[(MSG_BITS-1) -: MSG_BITS]; 
assign i_mem2cache_address = mem2cache_address[(ADDRESS_BITS-1) -: ADDRESS_BITS]; 
assign i_mem2cache_data    = mem2cache_data[(DATA_WIDTH-1) -: DATA_WIDTH];
      		
assign cache2mem_msg[(MSG_BITS-1) -: MSG_BITS]            = i_cache2mem_msg;
assign cache2mem_address[(ADDRESS_BITS-1) -: ADDRESS_BITS]= i_cache2mem_address;
assign cache2mem_data[(DATA_WIDTH-1) -: DATA_WIDTH]       = i_cache2mem_data;  
	    
assign d_mem2cache_msg     = mem2cache_msg[((2*MSG_BITS)-1) -: MSG_BITS]; 
assign d_mem2cache_address = mem2cache_address[((2*ADDRESS_BITS)-1) -: ADDRESS_BITS]; 
assign d_mem2cache_data    = mem2cache_data[((2*DATA_WIDTH)-1) -: DATA_WIDTH];
      		
assign cache2mem_msg[((2*MSG_BITS)-1) -: MSG_BITS]             = d_cache2mem_msg;
assign cache2mem_address[((2*ADDRESS_BITS)-1) -: ADDRESS_BITS] = d_cache2mem_address;
assign cache2mem_data[((2*DATA_WIDTH)-1) -: DATA_WIDTH]        = d_cache2mem_data;

assign i_address  = address[(ADDRESS_BITS-1) -: ADDRESS_BITS];
assign d_address  = address[((2*ADDRESS_BITS)-1) -: ADDRESS_BITS];
	
assign i_in_data  = in_data[(DATA_WIDTH-1) -: DATA_WIDTH];
assign d_in_data  = in_data[((2*DATA_WIDTH)-1) -: DATA_WIDTH];

assign out_address[(ADDRESS_BITS-1) -: ADDRESS_BITS] = i_out_addr;
assign out_address[((2*ADDRESS_BITS)-1) -: ADDRESS_BITS] = d_out_addr;

assign out_data[(DATA_WIDTH-1) -: DATA_WIDTH]     = i_out_data ;
assign out_data[((2*DATA_WIDTH)-1) -: DATA_WIDTH] = d_out_data;

cache_wrapper #((2*CORE), DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS, MSG_BITS) 
             ICache (
				     clock, reset,
				       
				     read[0], write[0], i_address, i_in_data, 
				     i_out_addr, i_out_data, valid[0], ready[0],
				     
				     i_mem2cache_msg, 
				     i_mem2cache_address, i_mem2cache_data, 
				     
				     i_cache2mem_msg, 
				     i_cache2mem_address, i_cache2mem_data, 
					 report
);

cache_wrapper #(((2*CORE+1)), DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS, MSG_BITS) 
             DCache (
				     clock, reset,
				       
				     read[1], write[1], d_address, d_in_data, 
				     d_out_addr, d_out_data, valid[1], ready[1],
				     
				     d_mem2cache_msg, 
				     d_mem2cache_address, d_mem2cache_data, 
				     
				     d_cache2mem_msg, 
				     d_cache2mem_address, d_cache2mem_data, 
					 report
);

endmodule
