/** @module : Real_Cores_Mesh
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
//`include "Seven_Stage_MIPS_Core.v"
 
 // added
module real_cores_mesh #(parameter ROW = 4, COLUMN = 4, // size of the mesh changed to 4 and added HEIGHT
						 VC_PER_PORTS = 2,  VC_DEPTH = 8, // size of the virtual channels specifications
						 INDEX_BITS = 6, OFFSET_BITS = 3, // size of caches
						 RT_ALG = 0, EXTRA  = 2,          // routing algorithm 
						 MSG_BITS = 4,                    // inter-core message bits -- 0 for RA, 4 For DIR
						 DATA_WIDTH = 32,                 // out data width
						 LOCAL_ADDR_BITS = 16, ADDRESS_BITS = 32, // memory distribution 
						 STATS_CYCLES = 1)( // STATS_CYCLES is used to set number of cycles to collect 
						                // performance data
  clock,
  global_reset,
  
  start, prog_address,  
  operation, ON, core_ID, reset, PROG,
 
  route_table_address, route_table_data, 
  
  origin, data_out, valid_out, fault_status_all  
  ); 
  
	// Change these local parameters only if you are familar with the system composition
	localparam IN_PORTS = 1, OUT_PORTS = 1, TYPE_BITS = 2, SWITCH_TO_SWITCH = 1 , OPER_BITS = 4; 
	localparam INIT_FILE = "memory.mem";
	
	localparam target_core = 7;
	 
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
  

  //Number of bits to represent ID. 
  localparam ROW_BITS = log2(ROW); 
  localparam COLUMN_BITS = log2(COLUMN);

 // localparam HEIGHT_BITS = log2(HEIGHT);
  // added
  localparam ID_BITS = ROW_BITS + COLUMN_BITS; 

  //Number of bits to represent vcs. 
  localparam VC_BITS = log2(VC_PER_PORTS); 
  
  //Number of bits to represent vc depth. 
  localparam VC_DEPTH_BITS = log2(VC_DEPTH);

  localparam  FLOW_BITS = (2*ID_BITS) + EXTRA;  
  localparam  PAY_WIDTH     = MSG_BITS + DATA_WIDTH;
  localparam  FLIT_WIDTH    = FLOW_BITS + TYPE_BITS + VC_BITS + PAY_WIDTH;
   // added
  localparam  PORTS = OUT_PORTS + 6*(SWITCH_TO_SWITCH);
  localparam  PORTS_BITS = log2(PORTS); 
  localparam  RT_WIDTH = PORTS_BITS + VC_BITS + 1; 
  localparam  NUM_VC = (1 << VC_BITS); 
  //added
  localparam SWITCHES =  ROW * COLUMN ;
  localparam CORES = SWITCHES;
  
  
  
      //added
  localparam HEIGHT=COLUMN;
    localparam CORES_PER_PLANE = ROW;
  localparam COLUMN_PER_PLANE=COLUMN;
  
  
// -------------------------------------------------------------------------------------

  input clock;
  input global_reset;
  input start;
  input  [31:0]  prog_address; 
  
  input [OPER_BITS - 1: 0] operation;
  input ON; 
  input [ID_BITS - 1: 0] core_ID;
  input reset; 
  input PROG;
 
  input [(FLOW_BITS - 1): 0]  route_table_address;
  input [RT_WIDTH - 1: 0]     route_table_data; 
  
  //---------------------------------
  input [63:0] fault_status_all;
 //---------------------------------------
  wire [3:0] fs[0:15];
  genvar j;
  generate
	for (j = 0; j < SWITCHES; j= j + 1)
    assign fs[j]=fault_status_all[(4*j)+3 -:4];
  endgenerate
  //...
  //---------------------------------------
  
  output [ID_BITS - 1: 0] origin;
  output [31: 0] data_out; 
  output valid_out;
 
  wire report; 
  reg c_start    [0: CORES-1]; 
  reg [31 :0]  c_prog_address [0: CORES-1];

  reg  [1 :0]   from_peripheral       [0: CORES-1];
  reg  [31 :0]  from_peripheral_data  [0: CORES-1]; 
  reg           from_peripheral_valid [0: CORES-1]; 
  wire [1 :0]   to_peripheral      [0: CORES-1];
  wire [31 :0]  to_peripheral_data [0: CORES-1]; 
  wire          to_peripheral_valid[0: CORES-1];
    
  reg c_ON    [0: CORES-1];     
  reg c_reset [0: CORES-1]; 
  reg c_PROG  [0: CORES-1];
  reg c_WEn   [0: CORES-1];
  reg c_REn   [0: CORES-1];
  wire [ID_BITS - 1: 0] router_ID [0: CORES-1];
  reg [(FLOW_BITS - 1): 0] rt_flowID [0: SWITCHES-1]; 
  reg [RT_WIDTH - 1: 0] rt_entry [0: SWITCHES-1];
  
  wire [(FLIT_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_in [0: SWITCHES-1];
  wire [(SWITCH_TO_SWITCH *6) - 1: 0]s_valid_in [0: SWITCHES-1]; 
  
  wire [(FLIT_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_out [0: SWITCHES-1]; 
  wire [(SWITCH_TO_SWITCH *6) - 1: 0] s_valid_out [0: SWITCHES-1]; 
  
  wire [((NUM_VC * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_in  [0: SWITCHES-1]; 
  wire [((NUM_VC * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_in  [0: SWITCHES-1]; 

  wire [((NUM_VC * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_out [0: SWITCHES-1];
  wire [((NUM_VC * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_out [0: SWITCHES-1];  
  
  wire [(FLIT_WIDTH * SWITCH_TO_SWITCH) - 1: 0] single_s_flits_in [0: (SWITCHES*6)-1]; 
  wire [SWITCH_TO_SWITCH - 1: 0] single_s_valid_in [0: (SWITCHES*6)-1];  
  wire [(FLIT_WIDTH * SWITCH_TO_SWITCH) - 1: 0] single_s_flits_out [0: (SWITCHES*6)-1]; 
  wire [SWITCH_TO_SWITCH - 1: 0] single_s_valid_out [0: (SWITCHES*6)-1];  
  
  wire [((NUM_VC * SWITCH_TO_SWITCH) - 1): 0] single_s_empty_in  [0: (SWITCHES*6)-1]; 
  wire [((NUM_VC * SWITCH_TO_SWITCH) - 1): 0] single_s_full_in  [0: (SWITCHES*6)-1];
  wire [((NUM_VC * SWITCH_TO_SWITCH) - 1): 0] single_s_empty_out  [0: (SWITCHES*6)-1]; 
  wire [((NUM_VC * SWITCH_TO_SWITCH) - 1): 0] single_s_full_out  [0: (SWITCHES*6)-1];
  
  genvar i;
  genvar j;
  generate
	for (i = 0; i < SWITCHES; i= i + 1) begin :  S_IN_OUT
 		 assign  s_flits_in[i][((FLIT_WIDTH * SWITCH_TO_SWITCH)-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[(i*6)] ;
 		 assign  s_valid_in[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[(i*6)];
 		 assign  s_flits_in[i][((2*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*6)+1)];
 		 assign  s_valid_in[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*6)+1)]; 
 		 assign  s_flits_in[i][((3*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*6)+2)] ;
 		 assign  s_valid_in[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*6)+2)] ;
 		 assign  s_flits_in[i][((4*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*6)+3)];
 		 assign  s_valid_in[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*6)+3)] ;
 		 //added
		 assign  s_flits_in[i][((5*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*6)+4)];
 		 assign  s_valid_in[i][((5*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*6)+4)] ;
		 assign  s_flits_in[i][((6*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*6)+5)];
 		 assign  s_valid_in[i][((6*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*6)+5)] ;
		 
		 
 		 assign  single_s_flits_out[(i*6)] =  s_flits_out[i][((FLIT_WIDTH * SWITCH_TO_SWITCH)-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[(i*6)] =  s_valid_out[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*6)+1)] =  s_flits_out[i][((2*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*6)+1)] =  s_valid_out[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*6)+2)] =  s_flits_out[i][((3*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*6)+2)] =  s_valid_out[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*6)+3)] =  s_flits_out[i][((4*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*6)+3)] =  s_valid_out[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];	
 		 //added
		 assign  single_s_flits_out[((i*6)+4)] =  s_flits_out[i][((5*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*6)+4)] =  s_valid_out[i][((5*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];	
		 assign  single_s_flits_out[((i*6)+5)] =  s_flits_out[i][((6*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*6)+5)] =  s_valid_out[i][((6*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];	
 
  		 assign  s_empty_in[i][((NUM_VC * SWITCH_TO_SWITCH)-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[(i*6)] ;
 		 assign  s_empty_in[i][((2*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*6)+1)];
 		 assign  s_empty_in[i][((3*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*6)+2)] ;
 		 assign  s_empty_in[i][((4*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*6)+3)];
         //added
		  assign  s_empty_in[i][((5*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*6)+4)];
		  assign  s_empty_in[i][((6*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*6)+5)];
		 
		 
  		 assign  s_full_in[i][((NUM_VC * SWITCH_TO_SWITCH)-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[(i*6)] ;
 		 assign  s_full_in[i][((2*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[((i*6)+1)];
 		 assign  s_full_in[i][((3*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[((i*6)+2)] ;
 		 assign  s_full_in[i][((4*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[((i*6)+3)];
 		  //added		 
 		 assign  s_full_in[i][((5*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[((i*6)+4)];
   		 assign  s_full_in[i][((6*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)] = single_s_full_in[((i*6)+5)];
		 
		 assign  single_s_empty_out[(i*6)]      =  s_empty_out[i][((NUM_VC * SWITCH_TO_SWITCH)-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*6)+1)]  =  s_empty_out[i][((2*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*6)+2)]  =  s_empty_out[i][((3*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*6)+3)]  =  s_empty_out[i][((4*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
 		 //added
 		 assign  single_s_empty_out[((i*6)+4)]  =  s_empty_out[i][((5*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
 		 assign  single_s_empty_out[((i*6)+5)]  =  s_empty_out[i][((6*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
          		
		 assign  single_s_full_out[(i*6)]      =  s_full_out[i][((NUM_VC * SWITCH_TO_SWITCH)-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*6)+1)]  =  s_full_out[i][((2*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*6)+2)]  =  s_full_out[i][((3*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*6)+3)]  =  s_full_out[i][((4*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
 		 //added
         assign  single_s_full_out[((i*6)+4)]  =  s_full_out[i][((5*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
         assign  single_s_full_out[((i*6)+5)]  =  s_full_out[i][((6*(NUM_VC * SWITCH_TO_SWITCH))-1) -: (NUM_VC * SWITCH_TO_SWITCH)];  
		 
	end
  endgenerate  

 generate
  	
 // west=0,south=1,east=2,north=3,front=5,back=4
 
 //connect back port to the front port of the next node 	
 for (i = 0; i < CORES_PER_PLANE ; i= i + 1) begin
 
 for(j=1;j < HEIGHT;j=j+1) 
  begin
    assign  single_s_flits_in[((i*6)+(6*j*(CORES_PER_PLANE))+4)] =  (j % HEIGHT)? single_s_flits_out[((i*6)+(6*(j-1)*(CORES_PER_PLANE))+5)] : 0;
    assign  single_s_valid_in[((i*6)+(6*j*(CORES_PER_PLANE))+4)] =  (j % HEIGHT)? single_s_valid_out[((i*6)+(6*(j-1)*(CORES_PER_PLANE))+5)] : 0;
    assign  single_s_empty_in[((i*6)+(6*j*(CORES_PER_PLANE))+4)] =  (j % HEIGHT)? single_s_empty_out[((i*6)+(6*(j-1)*(CORES_PER_PLANE))+5)] : 0;
 	assign  single_s_full_in [((i*6)+(6*j*(CORES_PER_PLANE))+4)] = (j % HEIGHT)?  single_s_full_out[((i*6)+(6*(j-1)*(CORES_PER_PLANE))+5)] : 0;
	
	end
 end  
 ////////////////////////// zero all front ports of the first plane
  for (i = 0; i < CORES_PER_PLANE ; i= i + 1) begin
 
 for(j=HEIGHT-1;j < HEIGHT;j=j+1) 
  begin
    assign  single_s_flits_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =   0;
    assign  single_s_valid_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =   0;
    assign  single_s_empty_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =  0;
 	assign  single_s_full_in [((i*6)+(6*j*(CORES_PER_PLANE))+5)] =  0;
	
	end
 end 
 //////////////////////////

 for (i = 0; i < CORES_PER_PLANE ; i= i + 1) begin
 for(j=0;j < HEIGHT-1;j=j+1) 
  begin
    assign  single_s_flits_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =  ((j+1) % HEIGHT)? single_s_flits_out[((i*6)+(6*(j+1)*(CORES_PER_PLANE))+4)] : 0;
    assign  single_s_valid_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =  ((j+1) % HEIGHT)? single_s_valid_out[((i*6)+(6*(j+1)*(CORES_PER_PLANE))+4)] : 0;
    assign  single_s_empty_in[((i*6)+(6*j*(CORES_PER_PLANE))+5)] =  ((j+1) % HEIGHT)? single_s_empty_out[((i*6)+(6*(j+1)*(CORES_PER_PLANE))+4)] : 0;
 	assign  single_s_full_in [((i*6)+(6*j*(CORES_PER_PLANE))+5)] = ((j+1) % HEIGHT)?  single_s_full_out[((i*6)+(6*(j+1)*(CORES_PER_PLANE))+4)] : 0;
 end 
end  
 ////////////////////  zero all back ports of the first plane
 for (i = 0; i < CORES_PER_PLANE ; i= i + 1) begin
    assign  single_s_flits_in[((i*6)+4)] =   0;
    assign  single_s_valid_in[((i*6)+4)] =   0;
    assign  single_s_empty_in[((i*6)+4)] =  0;
 	assign  single_s_full_in [((i*6)+4)] =  0;
end  
 //////////////////
 
 for(j=0;j < HEIGHT;j=j+1) 
begin 
 
 // zero first node  (west port) 
	assign  single_s_flits_in[0+(6*j*(CORES_PER_PLANE))] = 0;
 	assign  single_s_valid_in[0+(6*j*(CORES_PER_PLANE))] = 0;
  	assign  single_s_empty_in[0+(6*j*(CORES_PER_PLANE))] = 0;
 	assign  single_s_full_in[0+(6*j*(CORES_PER_PLANE))]  = 0;
 	// connect west port to the east port of the previous node 
	for (i = 1; i < CORES_PER_PLANE ; i= i + 1) begin :  SS_IN
 		 assign  single_s_flits_in[(i*6)+(6*j*(CORES_PER_PLANE))] =  (i % COLUMN_PER_PLANE)? single_s_flits_out[(((i-1)*6)+ 2+(6*j*(CORES_PER_PLANE)))] : 0;
 		 assign  single_s_valid_in[(i*6)+(6*j*(CORES_PER_PLANE))] =  (i % COLUMN_PER_PLANE)? single_s_valid_out[(((i-1)*6)+ 2+(6*j*(CORES_PER_PLANE)))] : 0;
  		 assign  single_s_empty_in[(i*6)+(6*j*(CORES_PER_PLANE))] =  (i % COLUMN_PER_PLANE)? single_s_empty_out[(((i-1)*6)+ 2+(6*j*(CORES_PER_PLANE)))] : 0;
 		 assign  single_s_full_in[(i*6)+(6*j*(CORES_PER_PLANE))]  =  (i % COLUMN_PER_PLANE)?  single_s_full_out[(((i-1)*6)+ 2+(6*j*(CORES_PER_PLANE)))] : 0;
    end 
  // connects south port to north port of the corresponding next row's node
 	for (i = 0; i < CORES_PER_PLANE - COLUMN_PER_PLANE ; i= i + 1) begin :  SS_IN_2
 		 assign  single_s_flits_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  single_s_flits_out[(((i+COLUMN_PER_PLANE)*6)+ 3+(6*j*(CORES_PER_PLANE)))];
 		 assign  single_s_valid_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  single_s_valid_out[(((i+COLUMN_PER_PLANE)*6)+ 3+(6*j*(CORES_PER_PLANE)))];  
 		 assign  single_s_empty_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  single_s_empty_out[(((i+COLUMN_PER_PLANE)*6)+ 3+(6*j*(CORES_PER_PLANE)))];
 		 assign  single_s_full_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))]  =  single_s_full_out[(((i+COLUMN_PER_PLANE)*6)+ 3+(6*j*(CORES_PER_PLANE)))]; 	    
	end	
	// zero last row nodes (south)
	for (i = CORES_PER_PLANE - COLUMN_PER_PLANE; i < CORES_PER_PLANE ; i= i + 1) begin :  SS_IN_3 
 		 assign  single_s_flits_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  0;
 		 assign  single_s_valid_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  0;  
  		 assign  single_s_empty_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))] =  0;
 		 assign  single_s_full_in[((i*6)+1+(6*j*(CORES_PER_PLANE)))]  =  0;  	    
	end	
	// connect east port to the west port of the next node 	
	for (i = 0; i < CORES_PER_PLANE - 1 ; i= i + 1) begin :  SS_IN_4
 		 assign  single_s_flits_in[((i*6)+2+(6*j*(CORES_PER_PLANE)))] =  ((i+1) % COLUMN_PER_PLANE)? single_s_flits_out[((i+1)*6)+(6*j*(CORES_PER_PLANE))] : 0;
 		 assign  single_s_valid_in[((i*6)+2+(6*j*(CORES_PER_PLANE)))] =  ((i+1) % COLUMN_PER_PLANE)? single_s_valid_out[((i+1)*6)+(6*j*(CORES_PER_PLANE))] : 0;	
  		 assign  single_s_empty_in[((i*6)+2+(6*j*(CORES_PER_PLANE)))] =  ((i+1) % COLUMN_PER_PLANE)? single_s_empty_out[((i+1)*6)+(6*j*(CORES_PER_PLANE))] : 0;
 		 assign  single_s_full_in[((i*6)+2+(6*j*(CORES_PER_PLANE)))] =  ((i+1) % COLUMN_PER_PLANE)? single_s_full_out[((i+1)*6)+(6*j*(CORES_PER_PLANE))] : 0;   	    
	end
// zero last row nodes (north)	
	for (i = 0; i < COLUMN_PER_PLANE ; i= i + 1) begin :  SS_IN_5 
 		 assign  single_s_flits_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = 0;
 		 assign  single_s_valid_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = 0; 	 
  		 assign  single_s_empty_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = 0;
 		 assign  single_s_full_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = 0; 	   
	end	
	// connect north port to south port of the corresponding previous row's node
	for (i = COLUMN_PER_PLANE; i < CORES_PER_PLANE ; i= i + 1) begin :  SS_IN_6 
 		 assign  single_s_flits_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = single_s_flits_out[(((i-COLUMN_PER_PLANE)*6)+ 1+(6*j*(CORES_PER_PLANE)))];
 		 assign  single_s_valid_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = single_s_valid_out[(((i-COLUMN_PER_PLANE)*6)+ 1+(6*j*(CORES_PER_PLANE)))];  	
  		 assign  single_s_empty_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))] = single_s_empty_out[(((i-COLUMN_PER_PLANE)*6)+ 1+(6*j*(CORES_PER_PLANE)))];
 		 assign  single_s_full_in[((i*6)+3+(6*j*(CORES_PER_PLANE)))]  = single_s_full_out[(((i-COLUMN_PER_PLANE)*6)+ 1+(6*j*(CORES_PER_PLANE)))];     
	end		
	
	
  end
  endgenerate   
  

  
 //we should add SWITCHES = ROW*COLUMN*HEIGHT
 generate
	for (i = target_core; i < target_core + 1 ; i= i + 1) begin : MESH_NODE0
	 	
		 assign router_ID[i] = i;
		 MIPS_core #(i, ID_BITS, LOCAL_ADDR_BITS, DATA_WIDTH, INDEX_BITS, 
                            OFFSET_BITS, ADDRESS_BITS, INIT_FILE, IN_PORTS, 
                            OUT_PORTS, VC_BITS, VC_DEPTH_BITS,
                            MSG_BITS, EXTRA, TYPE_BITS, SWITCH_TO_SWITCH, 
							3, ROW, COLUMN) NODES (
							
                               clock, c_reset[i], 
  							   c_start[i], c_prog_address[i],

                               from_peripheral[i],
                               from_peripheral_data[i], 
                               from_peripheral_valid[i], 
                               to_peripheral[i],
                               to_peripheral_data[i], 
                               to_peripheral_valid[i],
                                                 
  							   c_ON [i], c_PROG[i], 
  							   c_WEn[i], c_REn[i], 
  							   
  							   router_ID[i], 
                               rt_flowID[i], rt_entry [i],  
  							   
                               s_flits_in[i], s_valid_in[i],  
                               s_flits_out[i], s_valid_out[i], 
                               s_empty_in[i], s_full_in[i],  
                               s_empty_out[i], s_full_out[i], 
							   report, fs[i]
		);
						
	end
	
	
		for (i = 0; i < target_core ; i= i + 1) begin : MESH_NODE
	 	 
		 assign router_ID[i] = i;
		 MIPS_core #(i, ID_BITS, LOCAL_ADDR_BITS, DATA_WIDTH, INDEX_BITS, 
                            OFFSET_BITS, ADDRESS_BITS, INIT_FILE, IN_PORTS, 
                            OUT_PORTS, VC_BITS, VC_DEPTH_BITS,
                            MSG_BITS, EXTRA, TYPE_BITS, SWITCH_TO_SWITCH, 
							RT_ALG, ROW, COLUMN) NODES (
							
                               clock, c_reset[i], 
  							   c_start[i], c_prog_address[i],

                               from_peripheral[i],
                               from_peripheral_data[i], 
                               from_peripheral_valid[i], 
                               to_peripheral[i],
                               to_peripheral_data[i], 
                               to_peripheral_valid[i],
                                                 
  							   c_ON [i], c_PROG[i], 
  							   c_WEn[i], c_REn[i], 
  							   
  							   router_ID[i], 
                               rt_flowID[i], rt_entry [i],  
  							   
                               s_flits_in[i], s_valid_in[i],  
                               s_flits_out[i], s_valid_out[i], 
                               s_empty_in[i], s_full_in[i],  
                               s_empty_out[i], s_full_out[i], 
							   report, fs[i]
		);
						
	
 end
 
	for (i = target_core + 1; i < 16 ; i= i + 1) begin : MESH_NODE1
	 	 
		 assign router_ID[i] = i;
		 MIPS_core #(i, ID_BITS, LOCAL_ADDR_BITS, DATA_WIDTH, INDEX_BITS, 
                            OFFSET_BITS, ADDRESS_BITS, INIT_FILE, IN_PORTS, 
                            OUT_PORTS, VC_BITS, VC_DEPTH_BITS,
                            MSG_BITS, EXTRA, TYPE_BITS, SWITCH_TO_SWITCH, 
							RT_ALG, ROW, COLUMN) NODES (
							
                               clock, c_reset[i], 
  							   c_start[i], c_prog_address[i],

                               from_peripheral[i],
                               from_peripheral_data[i], 
                               from_peripheral_valid[i], 
                               to_peripheral[i],
                               to_peripheral_data[i], 
                               to_peripheral_valid[i],
                                                 
  							   c_ON [i], c_PROG[i], 
  							   c_WEn[i], c_REn[i], 
  							   
  							   router_ID[i], 
                               rt_flowID[i], rt_entry [i],  
  							   
                               s_flits_in[i], s_valid_in[i],  
                               s_flits_out[i], s_valid_out[i], 
                               s_empty_in[i], s_full_in[i],  
                               s_empty_out[i], s_full_out[i], 
							   report, fs[i]
		);
						
	
 end
 
 
  endgenerate  


  reg  out_rdEn [0:CORES-1];
  wire out_read_valid [0:CORES-1];
  wire [31: 0] out_read_data [0:CORES-1];
  wire out_full [0:CORES-1];
  wire out_empty [0:CORES-1];
 
  generate
	for (i = 0; i < CORES ; i= i + 1) begin : OUT_DATA_BUFS
		fifo  #(32, VC_DEPTH_BITS) Bufs (
			clock,
			c_reset[i],
			to_peripheral_data[i], 
			to_peripheral_valid[i], 
			out_rdEn[i],
			1'b0, 
 
			out_read_data [i], 
			out_read_valid[i],			
			out_full[i], 
			out_empty[i] 
		);
	end
  endgenerate  
 
 reg [31: 0] cycles;
 integer index; 
 
 reg [ID_BITS - 1: 0] cur_read; 
 reg [ID_BITS - 1: 0] prev_read;

 always @ (posedge clock) begin 
 	 	if(global_reset == 1)begin
			cycles   <= 1;
			cur_read <= 0;
			prev_read <= 0;
			for (index = 0; index < CORES; index = index+1) out_rdEn[index] <= 0; 		
		end
		else begin
			cycles   <= cycles + 1;
			cur_read <= (cur_read == (CORES - 1))? 0 : cur_read + 1;
			prev_read <= cur_read;
			if (prev_read != cur_read) begin 
			   out_rdEn[cur_read]  <= (out_empty[cur_read] || ~c_ON[cur_read])? 0 : 1;
			   out_rdEn[prev_read] <= 0;
			end
			else
				 out_rdEn[cur_read] <= (out_empty[cur_read] || ~c_ON[cur_read])? 0 : 1; 	
		end 
  end   	
 
    always @ (posedge clock) begin
		  if(global_reset == 1)begin
			   for (index = 0; index < CORES; index = index+1) begin
			       c_ON[index] <= 0;
			   end 		
		  end
		  else begin
            if(operation[0] == 1) begin
                 c_ON  [core_ID]   <=  ON;
            	 c_WEn [core_ID]   <= (ON == 1)? 1 : 0;
            	 c_REn [core_ID]   <= (ON == 1)? 1 : 0;
            end  
            if(operation[1] == 1) c_reset [core_ID] <= reset;
            if(operation[2] == 1) c_PROG  [core_ID] <= PROG;
            if(operation[3] == 1) begin
                c_start[core_ID]        <= start;
                c_prog_address[core_ID] <= prog_address;
            end
      
            rt_flowID [core_ID] <= route_table_address;
            rt_entry [core_ID]  <= route_table_data;
		  end
    end
	
	assign origin     = prev_read; 
	assign valid_out  = c_ON[prev_read]? out_read_valid [prev_read]: 0; 
	assign data_out   = c_ON[prev_read]? out_read_data[prev_read]:0; 
	
	assign report = (cycles == STATS_CYCLES)? 1 : 0; // for performance reporting 	  
	
endmodule
