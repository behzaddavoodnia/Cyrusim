/** @module : Cache_wrapper
 *  @author : Behzad Davoodnia
 
 *  Copyright (c) 2012 Heracles (CSG/CSAIL/MIT)
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
module cache_wrapper #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
                     OFFSET_BITS = 3, ADDRESS_BITS = 20, MSG_BITS = 4) (
				     clock, reset,  
				     //Core2Cache
				     read, write, address, in_data, 
				     out_addr, out_data, valid, ready,
				     
				     //Cache2Memory
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data, 
				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data, 
					 report
);

input clock, reset; 
//Core2Cache
input read, write;
input [ADDRESS_BITS-1:0] address;
input [DATA_WIDTH-1:0] in_data;
output valid, ready;
output[ADDRESS_BITS-1:0] out_addr;
output[DATA_WIDTH-1:0] out_data;

//Cache2Memory
input [MSG_BITS-1:0]      mem2cache_msg; 
input [ADDRESS_BITS-1:0]  mem2cache_address; 
input [DATA_WIDTH-1:0]    mem2cache_data;
 				     
output [MSG_BITS-1:0]     cache2mem_msg; 
output [ADDRESS_BITS-1:0] cache2mem_address; 
output [DATA_WIDTH-1:0]   cache2mem_data; 

input  report;// performance reporting 

direct_mapped_cache #(CORE, DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS, MSG_BITS) CACHE (
				     clock, reset,  
				     //Core2Cache
				     read, write, address, in_data, 
				     out_addr, out_data, valid, ready,
				     
				     //Cache2Memory
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data, 
				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data, 
					 report
);

endmodule

