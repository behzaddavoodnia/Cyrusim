 
/** @module : 3D router
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
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRfANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */
//`include "crossbar.v"
//`include "arbiter.v"
//`include "buffer_port.v"
//FLOW_BITS = src__ROW_BITS + COLUMN_BITS + dest__ROW_BITS + COLUMN_BITS + EXTRA;
module router #(parameter RT_ALG = 0, RT_WIDTH = 5, FLOW_BITS = 8, FLIT_WIDTH = 32, CORE_IN_PORTS  = 1, 
						  CORE_OUT_PORTS  = 1, SWITCH_TO_SWITCH  = 1, VC_BITS = 1, 
						  VC_DEPTH_BITS = 3, ID_BITS = 4, ROW = 4, COLUMN = 4) (
   //---------------------------------------------------  Changed and added HEIGHT = 4 --------------
	ON, clk, 
	reset, PROG, 
	router_ID, rt_flowID, rt_entry,
	
	c_flits_in, c_valid_in, 
	s_flits_in, s_valid_in,
	
	c_empty_in, c_full_in, 
	s_empty_in, s_full_in,
	
	s_flits_out, s_valid_out, 
	c_flits_out, c_valid_out, 
	
	c_empty_out, c_full_out, 
	s_empty_out, s_full_out,
	// performance reporting
    report,fault_status
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
	
  localparam flit_bit = 32; // One bit of flit for change the RT_ALG.	
  localparam TYPE_BITS = 2; // flit type 
  localparam MAX_FLOW = 1 << FLOW_BITS ; 
  localparam VC_PER_IN_PORTS = 1 << VC_BITS;  

   //Number of unique in ports. 
  localparam IN_PORTS =  ((SWITCH_TO_SWITCH *6) + CORE_IN_PORTS); // all SWITCH_TO_SWITCH * 6 //

  //Number of bits to represent input port number. 
  localparam IN_PORT_BITS = log2(IN_PORTS); 
  
  //Number of unique out ports. 
  localparam OUT_PORTS =  ((SWITCH_TO_SWITCH *6) + CORE_OUT_PORTS);
  
  //Number of bits to represent output port number. 
  localparam OUT_PORT_BITS = log2(OUT_PORTS);

  //Number of bits to represent coordinates. 
  localparam ROW_BITS = log2(ROW); 
  localparam COLUMN_BITS = log2(COLUMN);
  localparam HEIGHT=COLUMN; 
  localparam HEIGHT_BITS = log2(HEIGHT);
  localparam ROW_3D=ROW/COLUMN; 
  localparam ROW_3D_BITS=log2(ROW_3D); 
  // added
  //localparam HEIGHT=2;
  //localparam HEIGHT_BITS = log2(HEIGHT);
  
  
  
  localparam NUM_VCS    = (1 << VC_BITS); 
  localparam DOR_XY = 0,  DOR_YX = 1, TABLE = 2;
  localparam DATA_WIDTH    = FLIT_WIDTH - (FLOW_BITS + TYPE_BITS + VC_BITS);
  localparam HEAD_BITS     = FLOW_BITS + TYPE_BITS;
  localparam VC_IN_BUFFERS = 2; 
  
	//added--------------------------------------------------------------
	function [ID_BITS-1:0] grid_id;
	input integer id; 
	integer i, j,k, count; 
	reg [ROW_3D_BITS - 1:0] row; reg [COLUMN_BITS - 1:0] col;  reg [HEIGHT_BITS - 1:0] hei ; 
	begin
        count = 0; row = 0; col = 0; hei=0;
	for(k= 0; k< HEIGHT; k = k+1) begin
		for(i= 0; i < ROW_3D; i = i+1) begin
			for(j= 0; j < COLUMN; j = j+1) begin
				
				
				    if (count == id) begin
					   row = i; 
					   col = j; 
					   hei = k; 
				    end
				    count = count +1; 
				end
			end
		end  
		grid_id = {hei,row, col}; 
	end
  endfunction
  
  ///////////////////////
  input [3:0]fault_status;  
  //added--------------------------------------------------------------
/* 	function [ID_BITS-1:0] grid_id_dest;
	input [ ID_BITS - 1: 0] id_dest; 
	//integer id=((id_dest[((ROW_BITS + COLUMN_BITS) - 1) -: ROW_BITS])*COLUMN)+id_dest[(COLUMN_BITS - 1) -: 0];
	integer i, j,k, count; 
	reg [ROW_3D_BITS - 1:0] row; reg [COLUMN_BITS - 1:0] col;  reg [HEIGHT_BITS - 1:0] hei ; 
	begin
        count = 0; row = 0; col = 0; hei=0;
	for(k= 0; k< HEIGHT; k = k+1) begin
		for(i= 0; i < ROW_3D; i = i+1) begin
			for(j= 0; j < COLUMN; j = j+1) begin
				
				
				    if (count == ((id_dest[((ROW_BITS + COLUMN_BITS) - 1) -: ROW_BITS])*COLUMN)+id_dest[(COLUMN_BITS - 1) -: 0]) begin
					   row = i; 
					   col = j; 
					   hei = k; 
				    end
				    count = count +1; 
				end
			end
		end  
		grid_id_dest = {hei,row, col}; 
	end
  endfunction */
  //////////////////////
 //--------------------------------------------------------edited------------ 
  input ON; 
  input clk;    
  input reset;
  input PROG;
   
  input [(ID_BITS - 1): 0]    router_ID;
  input [(FLOW_BITS - 1): 0]  rt_flowID; 
  input [RT_WIDTH - 1: 0]     rt_entry;
   
  input [(FLIT_WIDTH * CORE_IN_PORTS) - 1: 0] c_flits_in;
  input [CORE_IN_PORTS - 1: 0]c_valid_in; 
  input [(FLIT_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_in;
  input [(SWITCH_TO_SWITCH *6) - 1: 0]s_valid_in;
 
  input [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_empty_in; 
  input [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_full_in;
  input [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_in; 
  input [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_in; 
  
  output [(FLIT_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_out; 
  output [(SWITCH_TO_SWITCH *6) - 1: 0] s_valid_out; 
  output [(FLIT_WIDTH * CORE_OUT_PORTS) - 1: 0] c_flits_out; 
  output [CORE_OUT_PORTS - 1: 0]c_valid_out; 
  
  output [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_empty_out; 
  output [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_full_out;
  output [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_out; 
  output [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_out; 
  input report; 
   
  reg  [NUM_VCS - 1: 0] free_vcs [0: (OUT_PORTS - 1)];  
 
  wire [FLIT_WIDTH - 1: 0] temp_s_flits_out [0: ((SWITCH_TO_SWITCH *6) - 1)]; 
  wire temp_s_valid_out [0: ((SWITCH_TO_SWITCH *6) - 1)]; 
  wire [FLIT_WIDTH - 1: 0] temp_c_flits_out [0: (CORE_OUT_PORTS - 1)]; 
  wire temp_c_valid_out [0: (CORE_OUT_PORTS - 1)];
  
  wire [FLIT_WIDTH - 1:0] in_flit [0:IN_PORTS-1];
  wire [VC_BITS - 1:0] in_vc [0:IN_PORTS-1]; 
  wire WEn [0:IN_PORTS-1];
   
  wire [VC_BITS - 1:0] read_vc [0:IN_PORTS-1];
  wire REn [0:IN_PORTS-1];
  wire [IN_PORTS-1: 0] PeekEn = 0; 
  
  wire [FLIT_WIDTH - 1:0] out_flit [0:IN_PORTS-1];
  wire [VC_BITS - 1:0] out_vc [0:IN_PORTS-1];
  wire valid [0:IN_PORTS-1];
  
  wire [VC_PER_IN_PORTS -1:0] empty [0:IN_PORTS-1];
  wire [VC_PER_IN_PORTS - 1:0] full [0:IN_PORTS-1];
    
  wire [VC_PER_IN_PORTS - 1:0] empty_in [0: (IN_PORTS - 1)];  
  wire [VC_PER_IN_PORTS - 1:0] full_in [0: (IN_PORTS - 1)];  
 
  reg [OUT_PORT_BITS - 1: 0] Routing_table  [0: (MAX_FLOW - 1)];
  reg [VC_BITS - 1: 0]       Routing_vc     [0: (MAX_FLOW - 1)];
  reg                        Routing_status [0: (MAX_FLOW - 1)];
	
  reg   [(IN_PORTS * OUT_PORT_BITS) - 1: 0] req_ports;  
  reg   [IN_PORTS - 1: 0] requests;  	
  wire  [IN_PORTS - 1: 0] grants; 
  
  reg   [(IN_PORTS * FLIT_WIDTH) - 1: 0]    xb_in_data;       	
  reg   [(IN_PORTS * OUT_PORT_BITS) - 1: 0] xb_req_ports;
  wire  [(OUT_PORTS * FLIT_WIDTH) - 1: 0]   xb_out_data;
  wire	[OUT_PORTS - 1: 0]  xb_valid;  
  
  wire  [FLIT_WIDTH - 1: 0] in_data [0: (IN_PORTS - 1)];
  wire  in_valid [0: (IN_PORTS - 1)]; 

  wire  [FLIT_WIDTH - 1: 0] out_data [0: (OUT_PORTS - 1)];
  wire	out_valid [0: (OUT_PORTS - 1)];

  wire bubble [0:IN_PORTS-1];
  wire stall  [0:IN_PORTS-1];
  wire [VC_PER_IN_PORTS -1:0]  vc_stall [0:IN_PORTS-1];
  wire [VC_PER_IN_PORTS -1:0]  sw_stall [0:IN_PORTS-1];
  wire [VC_PER_IN_PORTS -1:0]  drained  [0:IN_PORTS-1];
  wire SG1_stall  [0:IN_PORTS-1];
  wire SG2_stall  [0:IN_PORTS-1];
  wire SG3_stall  [0:IN_PORTS-1];
  wire SG4_stall  [0:IN_PORTS-1];
 
  wire [VC_PER_IN_PORTS -1:0] full_stall [0:IN_PORTS-1];
  reg [OUT_PORT_BITS - 1:0]   last_port [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [VC_BITS - 1: 0]        last_vc [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  
  wire [ID_BITS - 1: 0] router_coord = grid_id(router_ID); 
  //added
  wire [ID_BITS - 1: 0] dest_coord[0:IN_PORTS-1];
  
  wire [(COLUMN_BITS - 1): 0] cur_x = router_coord[(COLUMN_BITS - 1): 0]; 
  wire [(ROW_3D_BITS - 1): 0]    cur_y = router_coord[((ROW_3D_BITS + COLUMN_BITS) - 1)-: ROW_3D_BITS]; 
  //added  
  wire [(HEIGHT_BITS - 1): 0]    cur_z = router_coord[((HEIGHT_BITS + ROW_3D_BITS+COLUMN_BITS) - 1)-: HEIGHT_BITS];  
 
  wire [(COLUMN_BITS - 1): 0] dest_x[0:IN_PORTS-1]; 
  wire [(ROW_3D_BITS - 1): 0]    dest_y[0:IN_PORTS-1];
  //added
 wire [(HEIGHT_BITS - 1): 0] dest_z[0:IN_PORTS-1];
  //added
  wire [((ROW_BITS + COLUMN_BITS) - 1): 0]  destination [0:IN_PORTS-1];   
  
  reg [VC_BITS -1: 0]         current_vc [0:IN_PORTS-1];
  reg [VC_PER_IN_PORTS -1:0]  vc_status [0:IN_PORTS-1];
  reg [VC_BITS - 1: 0]        vc_table [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  wire [OUT_PORT_BITS - 1:0]  port_info [0:OUT_PORTS-1];
  wire 						  cal_route [0:OUT_PORTS-1];

  wire 				   allocate   [0:OUT_PORTS-1];
  wire 				  no_allocate [0:OUT_PORTS-1];
  wire 				   deallocate [0:OUT_PORTS-1];
  reg  [VC_BITS:0]     vc_allocate[0:OUT_PORTS-1];  
  reg [VC_BITS - 1:0]  new_vc     [0:OUT_PORTS-1]; 
  reg 				   val_vc     [0:OUT_PORTS-1];
  
 
  wire                       flit_valid   [0:IN_PORTS-1]; 
  wire [FLIT_WIDTH - 1:0]    flit         [0:IN_PORTS-1];
  wire [VC_BITS - 1:0]       flit_vc      [0:IN_PORTS-1];
  wire [FLOW_BITS - 1:0]     flit_id      [0:IN_PORTS-1]; 
  wire [TYPE_BITS - 1:0]     flit_type    [0:IN_PORTS-1];
  wire [OUT_PORT_BITS - 1:0] route        [0:OUT_PORTS-1]; 
  
  reg                       SG1_valid     [0:IN_PORTS-1];
  reg [FLIT_WIDTH - 1:0]    SG1_flit      [0:IN_PORTS-1];
  reg [VC_BITS - 1:0]       SG1_flit_vc   [0:IN_PORTS-1];
  reg [FLOW_BITS - 1:0]     SG1_flit_id   [0:IN_PORTS-1]; 
  reg [TYPE_BITS - 1:0]     SG1_flit_type [0:IN_PORTS-1];
  reg [OUT_PORT_BITS - 1:0] SG1_outport   [0:OUT_PORTS-1];
  
  reg                       SG1S_valid     [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLIT_WIDTH - 1:0]    SG1S_flit      [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [VC_BITS - 1:0]       SG1S_flit_vc   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLOW_BITS - 1:0]     SG1S_flit_id   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [TYPE_BITS - 1:0]     SG1S_flit_type [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [OUT_PORT_BITS - 1:0] SG1S_outport   [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 

  reg                       SG2_valid     [0:IN_PORTS-1];
  reg [FLIT_WIDTH - 1:0]    SG2_flit      [0:IN_PORTS-1];
  reg [VC_BITS - 1:0]       SG2_flit_vc   [0:IN_PORTS-1];
  reg [FLOW_BITS - 1:0]     SG2_flit_id   [0:IN_PORTS-1]; 
  reg [TYPE_BITS - 1:0]     SG2_flit_type [0:IN_PORTS-1];
  reg [OUT_PORT_BITS - 1:0] SG2_outport   [0:OUT_PORTS-1]; 
  reg [VC_BITS - 1:0]       SG2_out_vc    [0:OUT_PORTS-1];
  reg                       SG2_vc_status [0:OUT_PORTS-1];
  
  reg                       SG2S_valid     [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLIT_WIDTH - 1:0]    SG2S_flit      [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [VC_BITS - 1:0]       SG2S_flit_vc   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLOW_BITS - 1:0]     SG2S_flit_id   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [TYPE_BITS - 1:0]     SG2S_flit_type [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [OUT_PORT_BITS - 1:0] SG2S_outport   [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [VC_BITS - 1:0]       SG2S_out_vc    [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg                       SG2S_vc_status [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg                       SG2_sw_stall   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
   
  reg                       SG3_valid     [0:IN_PORTS-1];
  reg [FLIT_WIDTH - 1:0]    SG3_flit      [0:IN_PORTS-1];
  reg [VC_BITS - 1:0]       SG3_flit_vc   [0:IN_PORTS-1];
  reg [FLOW_BITS - 1:0]     SG3_flit_id   [0:IN_PORTS-1]; 
  reg [TYPE_BITS - 1:0]     SG3_flit_type [0:IN_PORTS-1];
  reg [OUT_PORT_BITS - 1:0] SG3_outport   [0:OUT_PORTS-1];
  reg [VC_BITS - 1:0]       SG3_out_vc    [0:OUT_PORTS-1];    
  
  reg                       SG3S_valid     [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLIT_WIDTH - 1:0]    SG3S_flit      [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [VC_BITS - 1:0]       SG3S_flit_vc   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLOW_BITS - 1:0]     SG3S_flit_id   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [TYPE_BITS - 1:0]     SG3S_flit_type [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [OUT_PORT_BITS - 1:0] SG3S_outport   [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [VC_BITS - 1:0]       SG3S_out_vc    [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0];   
  
  reg [(IN_PORTS * OUT_PORT_BITS) - 1: 0] SG3_req_ports;  
  wire[HEAD_BITS - 1:0]     SG3_head  [0:IN_PORTS-1];
  wire[DATA_WIDTH - 1:0]    SG3_data  [0:IN_PORTS-1]; 
  wire[FLIT_WIDTH - 1:0]    new_SG3_flit  [0:IN_PORTS-1];

  reg                       SG4_valid     [0:IN_PORTS-1];
  reg [FLIT_WIDTH - 1:0]    SG4_flit      [0:IN_PORTS-1];
  reg [VC_BITS - 1:0]       SG4_flit_vc   [0:IN_PORTS-1];
  reg [FLOW_BITS - 1:0]     SG4_flit_id   [0:IN_PORTS-1]; 
  reg [TYPE_BITS - 1:0]     SG4_flit_type [0:IN_PORTS-1];
  reg [OUT_PORT_BITS - 1:0] SG4_outport   [0:OUT_PORTS-1];
  reg [VC_BITS - 1:0]       SG4_out_vc     [0:OUT_PORTS-1];    
  
  reg                       SG4S_valid     [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLIT_WIDTH - 1:0]    SG4S_flit      [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [VC_BITS - 1:0]       SG4S_flit_vc   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [FLOW_BITS - 1:0]     SG4S_flit_id   [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [TYPE_BITS - 1:0]     SG4S_flit_type [0:IN_PORTS-1][VC_PER_IN_PORTS -1:0];
  reg [OUT_PORT_BITS - 1:0] SG4S_outport   [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [VC_BITS - 1:0]       SG4S_out_vc     [0:OUT_PORTS-1][VC_PER_IN_PORTS -1:0]; 
  reg [IN_PORTS - 1: 0]     SG4_requests;
  
  reg DYNAMIC_VC; 
  localparam HEAD = 'b10; 
  localparam BODY = 'b00;
  localparam TAIL = 'b01;
  localparam ALL  = 'b11;
  
  function [VC_BITS:0] get_free_vc;
	input [(OUT_PORT_BITS - 1): 0]    port;	
	integer j; reg val; reg [VC_BITS - 1:0] vc ; 
	begin
        val = 0; vc  = 0; 
		for(j= 0; j < NUM_VCS; j = j+1) begin
			if ((free_vcs[port][j] == 1) & (val == 0) & (~full_in[port][j])) begin
				free_vcs[port][j] = 0; val = 1; vc  = j; 
			end
		end  
		get_free_vc = {vc, val}; 
	end
  endfunction

  function [VC_BITS:0] release_vc;
	input [(OUT_PORT_BITS - 1): 0]    port;	
	input [VC_BITS - 1:0]             vc; 
	reg val; 
	begin
		val = 0; 
		if (free_vcs[port][vc] == 0) begin 
			free_vcs[port][vc] = 1; 
			val = 1; 
		end 
		release_vc = val; 
	end
  endfunction  
  
  function [0:0] header;
	input[TYPE_BITS - 1:0]   flit_type; 
	begin
		header = ((flit_type == HEAD) | (flit_type == ALL)); 
	end
  endfunction 
  
  integer index, j; 
  genvar i, u;

  generate
  	if(VC_PER_IN_PORTS > 0) begin 
 		for (i=0; i < IN_PORTS; i=i+1) begin : INPUT_PORTS
			buffer_port #(FLIT_WIDTH, VC_BITS, VC_DEPTH_BITS, VC_IN_BUFFERS) IP (
			  clk, reset, 
			  WEn[i], in_flit[i], in_vc[i], 
			  REn[i], PeekEn[i], read_vc[i],  
			  out_flit[i], out_vc[i], valid[i], 
			  empty[i], full[i]
			);
	    end
	    
	    for (i = 0; i < CORE_IN_PORTS; i=i+1) begin : CE_OUT
      		assign c_empty_out[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS] = empty[i]; 
      		assign c_full_out[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS] = full[i];
  		end 
	    for (i = 0; i < (SWITCH_TO_SWITCH *6); i=i+1) begin : SE_OUT
      		assign s_empty_out[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS] = empty[(i + CORE_IN_PORTS)]; 
      		assign s_full_out[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS] = full[(i + CORE_IN_PORTS)];
  		end

	    for (i = 0; i < CORE_IN_PORTS; i=i+1) begin : CE_IN
      		assign empty_in[i] = c_empty_in[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS]; 
      		assign full_in[i] = c_full_in[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS];
  		end 
	    for (i = 0; i < (SWITCH_TO_SWITCH *6); i=i+1) begin : SE_IN
      		assign empty_in[(i + CORE_IN_PORTS)] = s_empty_in[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS]; 
      		assign full_in[(i + CORE_IN_PORTS)] = s_full_in[(((i + 1) *(VC_PER_IN_PORTS))-1) -: VC_PER_IN_PORTS];
  		end
	end
  
	for (i = 0; i < CORE_OUT_PORTS; i=i+1) begin : CF_OUT
	  assign c_flits_out[(((i + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH] = temp_c_flits_out[i]; 
	  assign c_valid_out[i] = temp_c_valid_out[i];
	end   

	for (i = 0; i < (SWITCH_TO_SWITCH *6); i=i+1) begin : SF_OUT
	   assign s_flits_out[(((i + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH] = temp_s_flits_out[i];
	   assign s_valid_out[i] = temp_s_valid_out[i]; 
	end	
      	
	// With no output buffer
	for (i = 0; i < OUT_PORTS; i =i + 1) begin : CN1
		assign out_data[i]   = xb_out_data[(((i + 1)* FLIT_WIDTH)-1) -: FLIT_WIDTH];
		assign out_valid[i]  = xb_valid[i];
	end

	for (i = 0; i < CORE_OUT_PORTS; i=i+1) begin : CN2
		assign temp_c_flits_out[i] = out_data[i]; 
		assign temp_c_valid_out[i] = out_valid[i];
	end 

	for (i = CORE_OUT_PORTS; i < OUT_PORTS; i=i+1) begin : CN3
		assign temp_s_flits_out[i - CORE_OUT_PORTS] = out_data[i];
		assign temp_s_valid_out[i - CORE_OUT_PORTS] = out_valid[i]; 
	end

	for (i= 0; i< CORE_IN_PORTS; i=i+1) begin : CN4
		assign in_data[i]  = c_flits_in[(((i+ 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH];
		assign in_valid[i] = c_valid_in[i]; 
	end

	for (i= CORE_IN_PORTS; i< IN_PORTS; i=i+1) begin : CN5 
		assign in_data[i]  = s_flits_in[((((i- CORE_IN_PORTS) + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH];
		assign in_valid[i] = s_valid_in[i- CORE_IN_PORTS];
	end 

// 1) buffer write (BW) and for head flits route computation (RC)	 
	for(i= 0; i < IN_PORTS; i = i+1) begin : CN6
		assign in_vc [i]      = in_data[i][(FLIT_WIDTH - FLOW_BITS - TYPE_BITS -1) -: VC_BITS]; 
		//
		assign {in_flit[i][44:flit_bit+1], in_flit[i][flit_bit-1:0], in_flit[i][flit_bit]} =
	    {in_data[i][44:flit_bit+1],in_data[i][flit_bit-1:0],(fault_status[3:0] == 4'b0000)? in_data[i][flit_bit]:~in_data[i][flit_bit]};
		//
		assign WEn[i]         = in_valid[i]; 
		
		assign bubble[i]      = (empty[i][current_vc[i]])? 1 : 0;  
		assign stall[i]       = (SG1S_valid[i][current_vc[i]] | SG2S_valid[i][current_vc[i]] | 
								 SG3S_valid[i][current_vc[i]] | SG4S_valid[i][current_vc[i]] |
								 full_stall[i][current_vc[i]]);
		assign REn[i]         = (reset | stall[i] | bubble[i])? 0 : 1; 
		assign read_vc[i]     = current_vc[i];
		
		assign flit[i]        = out_flit[i]; 
		assign flit_vc[i]     = out_vc[i];
		assign flit_valid[i]  = valid[i];
		
		assign flit_id [i]    = flit[i][(FLIT_WIDTH -1) -: FLOW_BITS];
		assign flit_type[i]   = flit[i][(FLIT_WIDTH - FLOW_BITS -1) -: TYPE_BITS];
		
		assign destination[i] = reset? 0: 
        //added			  
		flit_id[i][(FLOW_BITS - (ROW_BITS + COLUMN_BITS ) - 1) -: (ROW_BITS + COLUMN_BITS)];
//convert_tb_16 tb0(destination[i],{dest_y[i],dest_x[i],dest_z[i]});	
	 assign dest_coord[i]=((destination[i][((ROW_BITS + COLUMN_BITS) - 1) -: ROW_BITS])*COLUMN)+destination[i][(COLUMN_BITS - 1) : 0];
	assign {dest_z[i],dest_y[i],dest_x[i]} = grid_id(dest_coord[i]); 

		//added
		assign route[i] = (cur_x == dest_x[i])? (cur_y == dest_y[i])?(cur_z > dest_z[i]) ? 5:(cur_z < dest_z[i]) ?6:0:
		(cur_y > dest_y[i])? 4 :2:(cur_x > dest_x[i]) ? 1 : 3;
	  
    
	   assign route[i] =(RT_ALG == 3)?in_flit[i][flit_bit]:(in_flit[i][flit_bit] == 0)? (cur_x == dest_x[i])? (cur_y > dest_y[i])? 
						 4 : (cur_y < dest_y[i])? 2 : 0 : (cur_x > dest_x[i]) ? 1 : 3
						 :(in_flit[i][flit_bit] == 1)? (cur_y == dest_y[i])? (cur_x > dest_x[i])? 
						 1 : (cur_x < dest_x[i])? 3 : 0 : (cur_y > dest_y[i]) ? 4 : 2
						 : 0; 	  
	
	/*
	//Adaptive routing firewall
	assign route[i] = (RT_ALG == 3) ? 0 :
	(in_flit[i][flit_bit_3D+1:flit_bit_3D] == 2'b00)? (cur_y > dest_y[i]) ? 4 :(cur_y < dest_y[i]) ? 2 :
	(cur_x > dest_x[i]) ? 1 : (cur_x < dest_x[i])? 3 :(cur_z > dest_z[i]) ? 5 :(cur_z < dest_z[i]) ? 6 : 0:
	(in_flit[i][flit_bit_3D+1:flit_bit_3D] == 2'b01)? (cur_x > dest_x[i])?  1 :(cur_x < dest_x[i]) ? 3 :
	(cur_y > dest_y[i]) ? 4 :(cur_y < dest_y[i])? 2 :(cur_z > dest_z[i]) ? 5 :(cur_z < dest_z[i]) ? 6 : 0:
	(in_flit[i][flit_bit_3D+1:flit_bit_3D] == 2'b10)? (cur_z > dest_z[i]) ? 5 :(cur_z < dest_z[i]) ? 6 :
	(cur_y > dest_y[i]) ? 4 :(cur_y < dest_y[i])? 2 : (cur_x > dest_x[i]) ? 1 :(cur_x < dest_x[i]) ? 3 :  0:
	(in_flit[i][flit_bit_3D+1:flit_bit_3D] == 2'b11)? (cur_z > dest_z[i]) ? 5 : (cur_z < dest_z[i]) ? 6 :
	(cur_x > dest_x[i])? 1 : (cur_x < dest_x[i])?  3 :(cur_y < dest_y[i]) ? 2 : (cur_y > dest_y[i]) ? 4 : 0;		

	//Normal Routing
	assign route[i] = (RT_ALG == 3) ? 0 :
	(cur_x == dest_x[i])?
	(cur_y == dest_y[i])?
	(cur_z > dest_z[i]) ? 5 :
	(cur_z < dest_z[i]) ? 6 : 0:
	(cur_y > dest_y[i]) ? 4 : 2:
	(cur_x > dest_x[i]) ? 1 : 3;
	*/
	
	//	(cur_y > dest_y[i])? 
		//				 4 : (cur_y < dest_y[i]) ? 2 : (cur_z > dest_z[i]) ? 5 : (cur_z < dest_z[i]) ?
			//			 6 :0: (cur_x > dest_x[i]) ? 1 : 3; 
						 
	/* 	assign route[i] =(RT_ALG == DOR_XY)? (cur_x == dest_x[i])? (cur_y > dest_y[i])? 
						 4 : (cur_y < dest_y[i])? 2 : 0 : (cur_x > dest_x[i]) ? 1 : 3
						 :(RT_ALG == DOR_YX)? (cur_y == dest_y[i])? (cur_x > dest_x[i])? 
						 1 : (cur_x < dest_x[i])? 3 : 0 : (cur_y > dest_y[i]) ? 4 : 2
						 : 0;  */
						 
						// :(RT_ALG == DOR_YX)? (cur_y == dest_y[i])? (cur_x > dest_x[i])? 
						 //1 : (cur_x < dest_x[i])? 3 : 0 : (cur_y > dest_y[i]) ? 4 : 2
						 //: 0; 
						
		//Other assignments 
		assign cal_route[i] = (flit_valid[i] & header(flit_type[i]) & (RT_ALG != TABLE)); 
							  
		assign port_info[i] = cal_route[i]? route[i] : Routing_table[flit_id[i]];  
		
		assign SG1_stall[i] = (vc_stall[i][SG1_flit_vc[i]] | SG2S_valid[i][SG1_flit_vc[i]]| 
				               SG3S_valid[i][SG1_flit_vc[i]]| SG4S_valid[i][SG1_flit_vc[i]] | 
				               sw_stall[i][SG1_flit_vc[i]] | 
							   full_in[last_port[i][SG1_flit_vc[i]]][last_vc[i][SG1_flit_vc[i]]]);
		assign SG2_stall[i] = (vc_stall[i][SG2_flit_vc[i]] | SG3S_valid[i][SG2_flit_vc[i]]| 
				               SG4S_valid[i][SG2_flit_vc[i]] | sw_stall[i][SG2_flit_vc[i]]);	
		assign SG3_stall[i] = (sw_stall[i][SG3_flit_vc[i]] & ~SG3S_valid[i][SG3_flit_vc[i]]);  
		assign SG4_stall[i] = (sw_stall[i][SG4_flit_vc[i]]); 
		
		for(u= 0; u < VC_PER_IN_PORTS; u = u+1) begin : VC1	
			assign vc_stall [i][u] = (SG2_valid[i] & ~(SG2_vc_status[i]) & (SG2_flit_vc[i] == u))? 1 : 0; 
			assign sw_stall[i][u]  = ((SG4_flit_vc[i] == u) & SG4_requests[i] & ~grants[i])? 1: 0;
			assign full_stall[i][u]= (reset)? 0 : ((current_vc[i] == u) & 
									 full_in[last_port[i][u]][last_vc[i][u]])? 1: 0;
			assign drained[i][u]   = (((SG2_flit_vc[i] == u) & SG2_valid[i] & header(SG2_flit_type[i])) |
									 (SG2S_valid[i][u] &  header(SG2S_flit_type[i][u]))|
									 ((SG3_flit_vc[i] == u) & SG3_valid[i] & header(SG3_flit_type[i])) |
									 (SG3S_valid[i][u] & header(SG3S_flit_type[i][u]))); 
		end 
		
		assign SG3_head[i]     = SG3_flit[i][(FLIT_WIDTH-1) -: HEAD_BITS]; 
		assign SG3_data[i]     = SG3_flit[i][(DATA_WIDTH-1) -: DATA_WIDTH]; 
		assign new_SG3_flit[i] = {SG3_head[i], SG3_out_vc[i], SG3_data[i]};
	end  		
endgenerate      

  crossbar #(FLIT_WIDTH, IN_PORTS, OUT_PORTS, OUT_PORT_BITS) XBar (  
	clk, reset, xb_in_data , xb_req_ports, grants, xb_out_data, xb_valid  
  );
 
  arbiter #(IN_PORTS,OUT_PORT_BITS) ARB (
     clk, reset, requests, req_ports, grants   
  );    

generate
  	for(i= 0; i < IN_PORTS; i = i+1) begin : VC1
		assign no_allocate[i] = ((~DYNAMIC_VC) | (SG2S_valid[i][SG1_flit_vc[i]] & 
								SG2S_vc_status[i][SG1_flit_vc[i]]) | 
								(SG3S_valid[i][SG1_flit_vc[i]] | SG4S_valid[i][SG1_flit_vc[i]]));
								  
 		assign allocate[i]    = (no_allocate[i])? 0 : ((SG1_valid[i] &  header(SG1_flit_type[i])) |
							    (SG2S_valid[i][SG1_flit_vc[i]] &  
								header(SG2S_flit_type[i][SG1_flit_vc[i]])))? 1 : 0; 
								
		assign deallocate[i] = (SG4_valid[i] & ((SG4_flit_type[i] == TAIL) |
							   (SG4_flit_type[i] == ALL)) & (DYNAMIC_VC == 1) &
							    grants[i]); 
	end
endgenerate    

reg temp ; 
reg [VC_BITS -1: 0]  allocate_vc [0:IN_PORTS-1];
reg [FLOW_BITS -1: 0]  allocate_id [0:IN_PORTS-1];
  
always @ (posedge clk) begin
	if (reset | PROG) begin	
		DYNAMIC_VC       = 1; // for dynamic vc allocation
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			vc_allocate[index]      = 0;
			val_vc[index]           = 0; 
			new_vc[index]           = 0;
			free_vcs[index]         = ~0;
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				vc_table[index][j]  = 0;
				vc_status[index][j] = 0;				
			end
		end 
	end 
    else begin
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if(SG2S_valid[index][SG1_flit_vc[index]]) begin 
				allocate_id[index]  = SG2S_flit_id[index][SG1_flit_vc[index]]; 
				allocate_vc[index]  = SG2S_flit_vc[index][SG1_flit_vc[index]]; 
			end 
			else begin
				allocate_id[index]  = SG1_flit_id[index]; 
				allocate_vc[index]  = SG1_flit_vc[index]; 
			end
			if(allocate[index]) begin 
				vc_allocate[index]   = get_free_vc(Routing_table[allocate_id[index]]); 
				val_vc[index]        = vc_allocate[index][0]; 
				new_vc[index]        = vc_allocate[index][VC_BITS : 1]; 
				vc_table [index][allocate_vc[index]]   = new_vc[index];
				vc_status [index][allocate_vc[index]]  = val_vc[index];
			end
			if (deallocate[index]) begin 
				vc_status [index][SG4_flit_vc[index]] = (drained[index][SG4_flit_vc[index]])? 
														vc_status [index][SG4_flit_vc[index]] : 0 ; 
				temp = release_vc(SG4_outport[index], SG4_out_vc[index]); 
			end 
		end 
	end 	
end 

always @ (posedge clk) begin
  if (ON) begin	
    if (PROG)begin
		Routing_table [rt_flowID]     <=  rt_entry[(RT_WIDTH -1) -: OUT_PORT_BITS];
		Routing_vc [rt_flowID]        <=  rt_entry[(RT_WIDTH - OUT_PORT_BITS -1) -: VC_BITS];
		Routing_status [rt_flowID]    <=  rt_entry[0];
		$display (" Routing table:  [FlowID: %d ] [Route:  %b]", rt_flowID , rt_entry);
    end
    else
      if (reset) begin  
		 requests         <= 0; 
		 for (index = 0; index < OUT_PORTS; index=index+1) begin
			current_vc[index]        <= 0;
			SG2_vc_status[index]     <= 0;
			SG4_requests			 <= 0;
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				last_port     [index][j]   <= 0;
                last_vc       [index][j]   <= 0;
				SG1S_valid    [index][j]   <= 0;
				SG2S_valid    [index][j]   <= 0;
				SG3S_valid    [index][j]   <= 0;
				SG4S_valid    [index][j]   <= 0;
				SG2S_vc_status[index][j]   <= 0;
			end 
			
			if (DYNAMIC_VC == 1) begin 
				for(j= 0; j < MAX_FLOW; j = j+1) begin 
					Routing_status [j]   <= 0;
				end 
			end
		end																				  
      end 
      else begin  
		 for (index = 0; index < IN_PORTS; index=index+1) begin
			current_vc[index]    <= current_vc[index] + 1; 
		 end 
		 
 // 1) buffer write (BW) and for head flits route computation (RC)
 		for (index = 0; index < IN_PORTS; index=index+1) begin 
				Routing_table[flit_id[index]]   <= port_info[index]; 
		end
		
		for (index = 0; index < IN_PORTS; index=index+1) begin		
			if (SG1S_valid[index][out_vc[index]]) begin 
				SG1_valid[index]      <= SG1S_valid[index][out_vc[index]]; 
				SG1_flit_vc[index]    <= SG1S_flit_vc[index][out_vc[index]]; 				
				SG1_flit[index]       <= SG1S_flit[index][out_vc[index]]; 
				SG1_flit_id[index]    <= SG1S_flit_id[index][out_vc[index]]; 
				SG1_flit_type[index]  <= SG1S_flit_type[index][out_vc[index]];
				SG1_outport[index]    <= SG1S_outport[index][out_vc[index]];
			end 
			else begin 
				SG1_valid[index]      <= flit_valid[index]; 
				SG1_flit_vc[index]    <= out_vc[index]; 				
				SG1_flit[index]       <= flit[index]; 
				SG1_flit_id[index]    <= flit_id[index]; 
				SG1_flit_type[index]  <= flit_type[index];
				SG1_outport[index]    <= port_info[index];
			end 
		end

		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG1_stall[index]) begin 
				SG1S_valid[index]    [SG1_flit_vc[index]] <= SG1_valid[index]; 
				SG1S_flit_vc[index]  [SG1_flit_vc[index]] <= SG1_flit_vc[index]; 				
				SG1S_flit[index]     [SG1_flit_vc[index]] <= SG1_flit[index]; 
				SG1S_flit_id[index]  [SG1_flit_vc[index]] <= SG1_flit_id[index]; 
				SG1S_flit_type[index][SG1_flit_vc[index]] <= SG1_flit_type[index];
				SG1S_outport[index]  [SG1_flit_vc[index]] <= SG1_outport[index];
			end 
			else begin 
				SG1S_valid[index]    [SG1_flit_vc[index]] <= 0; 
			end 
		end
		
// 2) virtual channel allocation (VA) 
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG2S_valid[index][SG1_flit_vc[index]]) begin 
				SG2_valid[index]      <= SG2S_valid[index][SG1_flit_vc[index]]; 
				SG2_flit_vc[index]    <= SG2S_flit_vc[index][SG1_flit_vc[index]]; 				
				SG2_flit[index]       <= SG2S_flit[index][SG1_flit_vc[index]]; 
				SG2_flit_id[index]    <= SG2S_flit_id[index][SG1_flit_vc[index]]; 
				SG2_flit_type[index]  <= SG2S_flit_type[index][SG1_flit_vc[index]];
				SG2_outport[index]    <= SG2S_outport[index][SG1_flit_vc[index]];	
				SG2_out_vc[index]     <= vc_table [index][SG1_flit_vc[index]]; 
				SG2_vc_status[index]  <= vc_status[index][SG1_flit_vc[index]];
			end 
			else begin 
				SG2_valid[index]      <= (SG1_stall[index])? 0 : SG1_valid[index] ; 
				SG2_flit_vc[index]    <= SG1_flit_vc[index]; 				
				SG2_flit[index]       <= SG1_flit[index]; 
				SG2_flit_id[index]    <= SG1_flit_id[index]; 
				SG2_flit_type[index]  <= SG1_flit_type[index];
				SG2_outport[index]    <= SG1_outport[index];
				SG2_out_vc[index]     <= vc_table [index][SG1_flit_vc[index]]; 
				SG2_vc_status[index]  <= vc_status [index][SG1_flit_vc[index]];	
			end 									  
		end  
		
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG2_stall[index]) begin 
				SG2S_valid[index]    [SG2_flit_vc[index]] <= SG2_valid[index]; 
				SG2S_flit_vc[index]  [SG2_flit_vc[index]] <= SG2_flit_vc[index]; 				
				SG2S_flit[index]     [SG2_flit_vc[index]] <= SG2_flit[index]; 
				SG2S_flit_id[index]  [SG2_flit_vc[index]] <= SG2_flit_id[index]; 
				SG2S_flit_type[index][SG2_flit_vc[index]] <= SG2_flit_type[index];
				SG2S_outport[index]  [SG2_flit_vc[index]] <= SG2_outport[index];
				SG2S_out_vc[index]  [SG2_flit_vc[index]]  <= SG2_out_vc[index];
				SG2S_vc_status[index][SG2_flit_vc[index]] <= SG2_vc_status[index];
			end 
			else begin 
				SG2S_valid[index]    [SG2_flit_vc[index]] <= 0; 
			end 
		end 
		
// 3) switch allocation (SA) 
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG4S_valid[index][SG2_flit_vc[index]]) begin 
				SG3_valid[index]     <= SG4S_valid[index][SG2_flit_vc[index]]; 
				SG3_flit_vc[index]   <= SG4S_flit_vc[index][SG2_flit_vc[index]]; 				
				SG3_flit[index]      <= SG4S_flit[index][SG2_flit_vc[index]]; 
				SG3_flit_id[index]   <= SG4S_flit_id[index][SG2_flit_vc[index]]; 
				SG3_flit_type[index] <= SG4S_flit_type[index][SG2_flit_vc[index]];
				SG3_outport[index]   <= SG4S_outport[index][SG2_flit_vc[index]]; 
				SG3_out_vc[index]    <= SG4S_out_vc[index][SG2_flit_vc[index]]; 
			end 
			else begin 
				if (SG3S_valid[index][SG2_flit_vc[index]]) begin 
					SG3_valid[index]      <= SG3S_valid[index][SG2_flit_vc[index]]; 
					SG3_flit_vc[index]    <= SG3S_flit_vc[index][SG2_flit_vc[index]]; 				
					SG3_flit[index]       <= SG3S_flit[index][SG2_flit_vc[index]]; 
					SG3_flit_id[index]    <= SG3S_flit_id[index][SG2_flit_vc[index]]; 
					SG3_flit_type[index]  <= SG3S_flit_type[index][SG2_flit_vc[index]];
					SG3_outport[index]    <= SG3S_outport[index][SG2_flit_vc[index]];
					SG3_out_vc[index]     <= SG3S_out_vc[index][SG2_flit_vc[index]];
				end 
				else begin 
					SG3_valid[index]      <= (vc_stall[index][SG2_flit_vc[index]] | 
						                     sw_stall[index][SG2_flit_vc[index]])? 0 
											 : SG2_valid[index]; 
					SG3_flit_vc[index]    <= SG2_flit_vc[index]; 				
					SG3_flit[index]       <= SG2_flit[index]; 
					SG3_flit_id[index]    <= SG2_flit_id[index]; 
					SG3_flit_type[index]  <= SG2_flit_type[index];
					SG3_outport[index]    <= SG2_outport[index]; 
					SG3_out_vc[index]     <= SG2_out_vc[index];
				end 
			end 
		end
		
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG3_stall[index]) begin 
				SG3S_valid[index]    [SG3_flit_vc[index]] <= SG3_valid[index]; 
				SG3S_flit_vc[index]  [SG3_flit_vc[index]] <= SG3_flit_vc[index]; 				
				SG3S_flit[index]     [SG3_flit_vc[index]] <= SG3_flit[index]; 
				SG3S_flit_id[index]  [SG3_flit_vc[index]] <= SG3_flit_id[index]; 
				SG3S_flit_type[index][SG3_flit_vc[index]] <= SG3_flit_type[index];
				SG3S_outport[index]  [SG3_flit_vc[index]] <= SG3_outport[index];
				SG3S_out_vc[index]  [SG3_flit_vc[index]]  <= SG3_out_vc[index];
			end
			else begin 
				if (~SG4S_valid[index] [SG3_flit_vc[index]]) begin 
					SG3S_valid[index][SG3_flit_vc[index]] <= 0; 
				end 
			end 
		end 
		
// 4) switch traversal(ST)
		for (index = 0; index < IN_PORTS; index=index+1) begin 
				requests[index]      <=  (SG4S_valid[index][SG2_flit_vc[index]] |
										  SG3S_valid[index][SG2_flit_vc[index]])? 1 : 
										 (vc_stall[index][SG2_flit_vc[index]] |
										 sw_stall[index][SG2_flit_vc[index]])? 0 : SG2_valid[index];
										  
				req_ports[(((index + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS] <= 
										  (SG4S_valid[index][SG2_flit_vc[index]])?  
										  SG4S_outport[index][SG2_flit_vc[index]]:
										  (SG3S_valid[index][SG2_flit_vc[index]])?  
										  SG3S_outport[index][SG2_flit_vc[index]]: SG2_outport[index];
		end
		
		for (index = 0; index < IN_PORTS; index=index+1) begin
			 xb_in_data [(((index + 1)* FLIT_WIDTH)-1) -: FLIT_WIDTH] <= new_SG3_flit[index]; 
			 xb_req_ports                                             <= req_ports;	
			 SG4_requests                                             <= requests;
		end

// 5) Link traversal(LT)		
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (SG4_stall[index]) begin 
				SG4S_valid[index][SG4_flit_vc[index]]     <= SG4_valid[index]; 
				SG4S_flit_vc[index][SG4_flit_vc[index]]   <= SG4_flit_vc[index]; 				
				SG4S_flit[index][SG4_flit_vc[index]]      <= SG4_flit[index]; 
				SG4S_flit_id[index][SG4_flit_vc[index]]   <= SG4_flit_id[index]; 
				SG4S_flit_type[index][SG4_flit_vc[index]] <= SG4_flit_type[index];
				SG4S_outport[index][SG4_flit_vc[index]]   <= SG4_outport[index]; 
				SG4S_out_vc[index][SG4_flit_vc[index]]    <= SG4_out_vc[index]; 
			end 
			else begin 
				SG4S_valid[index][SG4_flit_vc[index]]     <= 0; 
			end 	
		end
	
		for (index = 0; index < IN_PORTS; index=index+1) begin 
				SG4_valid[index]         <= SG3_valid[index]; 
				SG4_flit_vc[index]       <= SG3_flit_vc[index]; 				
				SG4_flit[index]          <= SG3_flit[index]; 
				SG4_flit_id[index]       <= SG3_flit_id[index]; 
				SG4_flit_type[index]     <= SG3_flit_type[index];
				SG4_outport[index]       <= SG3_outport[index]; 
				SG4_out_vc[index]        <= SG3_out_vc[index]; 
		end 
		
// Book keeping 
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if(SG3_valid[index]) begin
				last_port [index][SG3_flit_vc[index]]      <= SG3_outport[index]; 
				last_vc [index][SG3_flit_vc[index]]        <= SG3_out_vc[index];
			end 
			else begin 
				if(deallocate[index]) begin
					last_port [index][SG4_flit_vc[index]]      <= 0; 
					last_vc [index][SG4_flit_vc[index]]        <= 0;
				end  
			end 
		end 	
	  
	  end 
  end
end

// Performance data
reg [31 : 0] cycles;
reg [31 : 0] preformance_counters[0:OUT_PORTS-1]; 

always @ (posedge clk) begin
	if (reset | PROG) begin	
		cycles           <= 0;  
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			preformance_counters [index] <= 0; 
		end 
	end 
    else begin
		cycles           <= cycles + 1;
		for (index = 0; index < IN_PORTS; index=index+1) begin 
			if (out_valid[index]) begin 
				preformance_counters [index] <= preformance_counters [index] + 1; 
			end 
		end

		if (report & ON) begin 
			$display ("----------------------- Router %d link utilization -----------------------------", router_ID);  
			$display ("Total run cycles       [%d]", cycles);
			for (index = 0; index < IN_PORTS; index=index+1) begin 
				$display ("Port         [%d]  used cycles [%d]", index, preformance_counters [index]);
			end
			$display ("-------------------------------------------------------------------------------");
		end 	
	end 
end






/* wire [1:0] ddd=5/2;

integer outfile3;
initial outfile3=$fopen("router.txt","w");
always @ (posedge clk) begin 
        $fdisplay (outfile3,"----------------------------------Router %d-----------------------------------------",  router_ID); 
       for(index= 0; index < IN_PORTS; index = index + 1) begin
	           $fdisplay (outfile3,"destination[i] =%b ",destination[index]); 
	   
		end	   
		   $fdisplay (outfile3,"cur_x , cur_y  = %b  %b %b\n",cur_x,cur_y,grid_id(5)); 
		
		

end */

/*
// Debugging 
 always @ (posedge clk) begin 
        $display ("----------------------------------Router %d-----------------------------------------",  router_ID);   
		for(index= 0; index < IN_PORTS; index = index + 1) begin
			$display ("------------------ Port %d -----------------------", index); 
			$display ("| In_flit  [%h]",  in_flit[index]);
			$display ("| In_vc    [%d]", in_vc [index]); 
			$display ("| In_valid [%b]", WEn[index]); 
			$display ("| Empty [%b]", empty[index]);
			$display ("| Full [%b]", full[index]);
			$display ("| "); 
			$display ("| Stall       [%b]",  stall[index]); 
			$display ("| Bubble      [%b]",  bubble[index]); 
			$display ("| Cur REn     [%b]",  REn[index]); 
			$display ("| Cur read_vc [%d]",  read_vc[index]);		
			$display ("| Out flit    [%h]",  out_flit[index]); 
			$display ("| Out vc      [%b]",  out_vc[index]);
			$display ("| Valid       [%b]",  valid[index]);
			$display ("| ");
			$display ("|\t\t\t| SG1 valid [%b]",  SG1_valid[index]);
			$display ("|\t\t\t| SG1 flit [%h]",   SG1_flit[index]); 
			$display ("|\t\t\t| SG1 flit vc [%b]",  SG1_flit_vc[index]);
			$display ("|\t\t\t| SG1 flit type [%b]",  SG1_flit_type[index]); 
			$display ("|\t\t\t| SG1 flit src (%d,%d) dest (%d, %d)",  
			SG1_flit_id[index][(FLOW_BITS -1) -: ROW_BITS], 
			SG1_flit_id[index][(FLOW_BITS - ROW_BITS-1) -:  COLUMN_BITS], 
			SG1_flit_id[index][(FLOW_BITS - ROW_BITS - COLUMN_BITS-1) -:  ROW_BITS],
			SG1_flit_id[index][(FLOW_BITS - ROW_BITS - COLUMN_BITS - ROW_BITS-1) -:  COLUMN_BITS]); 
			$display ("|\t\t\t| SG1 outport [%d]",  SG1_outport[index]);
			$display ("|\t\t\t| SG1 vc status [%b]",  vc_status [index][SG1_flit_vc[index]]); 
			$display ("|\t\t\t| VC stall at SG1[%b]", vc_stall[index][SG1_flit_vc[index]]); 
			$display ("| ");
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				$display ("|\t\t\t| SG1S valid vc %d [%b]", j, SG1S_valid[index][j]);
				$display ("|\t\t\t| SG1S flit [%h]",   SG1S_flit[index][j]); 
				$display ("|\t\t\t| SG1S flit vc [%b]",  SG1S_flit_vc[index][j]);
				$display ("|\t\t\t| SG1S flit type [%b]",  SG1S_flit_type[index][j]); 
			end 
			$display ("| ");
			$display ("|\t\t\t|\t\t\t| SG2 valid [%b]",  SG2_valid[index]);
			$display ("|\t\t\t|\t\t\t| SG2 flit [%h]", SG2_flit[index]); 
			$display ("|\t\t\t|\t\t\t| SG2 flit vc [%b]",  SG2_flit_vc[index]);
			$display ("|\t\t\t|\t\t\t| SG2 flit type [%b]",  SG2_flit_type[index]); 
			$display ("|\t\t\t|\t\t\t| SG2 flit src (%d,%d) dest (%d, %d)",  
			SG2_flit_id[index][(FLOW_BITS -1) -: ROW_BITS], 
			SG2_flit_id[index][(FLOW_BITS - ROW_BITS-1) -:  COLUMN_BITS], 
			SG2_flit_id[index][(FLOW_BITS - ROW_BITS - COLUMN_BITS-1) -:  ROW_BITS],
			SG2_flit_id[index][(FLOW_BITS - ROW_BITS - COLUMN_BITS - ROW_BITS-1) -:  COLUMN_BITS]); 
			$display ("|\t\t\t|\t\t\t| SG2 outport [%d]",  SG2_outport[index]);
			$display ("|\t\t\t|\t\t\t| SG2 out vc [%b]",  SG2_out_vc[index]);
			$display ("|\t\t\t|\t\t\t| SG2 vc status [%b]",  SG2_vc_status[index]); 
			$display ("|\t\t\t|\t\t\t| VC stall at SG2[%b]", vc_stall[index][SG2_flit_vc[index]]); 
			$display ("|\t\t\t|\t\t\t| Full_in [%b]", full_in[SG2_outport[index]][SG2_out_vc[index]]);
			$display ("| ");
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				$display ("|\t\t\t|\t\t\t| SG2S valid vc %d [%b]", j, SG2S_valid[index][j]);
				$display ("|\t\t\t|\t\t\t| SG2S flit [%h]", SG2S_flit[index][j]); 
				$display ("|\t\t\t|\t\t\t| SG2S flit vc [%b]",  SG2S_flit_vc[index][j]);
				$display ("|\t\t\t|\t\t\t| SG2S flit type [%b]",  SG2S_flit_type[index][j]); 
				$display ("|\t\t\t|\t\t\t| SG2S outport [%d]",  SG2S_outport[index][j]);
				$display ("|\t\t\t|\t\t\t| SG2S out vc [%b]",  SG2S_out_vc[index][j]);
				$display ("|\t\t\t|\t\t\t| SG2S vc status [%b]",  SG2S_vc_status[index][j]); 
			end 
			$display ("| ");
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 valid [%b]",  SG3_valid[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 flit [%h]", SG3_flit[index]); 
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 flit vc [%b]",  SG3_flit_vc[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 flit type [%b]",  SG3_flit_type[index]); 
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 outport [%d]",  SG3_outport[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 out vc [%b]",  SG3_out_vc[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| SG3 vc status [%b]",  vc_status [index][SG3_flit_vc[index]]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| SW stall at SG3[%b]", sw_stall[index][SG3_flit_vc[index]]); 
			$display ("| ");
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S valid vc %d [%b]", j, SG3S_valid[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S flit [%h]", SG3S_flit[index][j]); 
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S flit vc [%b]",  SG3S_flit_vc[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S flit type [%b]",  SG3S_flit_type[index][j]); 
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S outport [%d]",  SG3S_outport[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t| SG3S out vc [%b]",  SG3S_out_vc[index][j]);
			end 
			$display ("| ");		
			$display ("|\t\t\t|\t\t\t|\t\t\t| Flit [%h]", SG3_flit[index]); 
			$display ("|\t\t\t|\t\t\t|\t\t\t| Request [%b]",  requests[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t| Req Port [%b]",  req_ports[(((index + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS]);   
			$display ("| ");
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 valid [%b]",  SG4_valid[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 flit [%h]", SG4_flit[index]); 
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 flit vc [%b]",  SG4_flit_vc[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 flit type [%b]",  SG4_flit_type[index]); 
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 outport [%d]",  SG4_outport[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 out vc [%b]",  SG4_out_vc[index]);
			$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SW stall at SG4[%b]", sw_stall[index][SG4_flit_vc[index]]); 
			$display ("| ----------");
			for(j= 0; j < NUM_VCS; j = j+1) begin 
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S valid vc %d [%b]", j, SG4S_valid[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S flit [%h]", SG4S_flit[index][j]); 
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S flit vc [%b]",  SG4S_flit_vc[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S flit type [%b]",  SG4S_flit_type[index][j]); 
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S outport [%d]",  SG4S_outport[index][j]);
				$display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4S out vc [%b]",  SG4S_out_vc[index][j]);
			end 
			$display ("| ");	
			 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| Flit [%h]", xb_in_data [(((index + 1)* FLIT_WIDTH)-1) -: FLIT_WIDTH]); 
			 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| Grants [%b]", grants[index]); 
			 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| Req Port [%b]",  xb_req_ports[(((index + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS]);
			 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 Req [%b]", SG4_requests[index]); 
			 $display ("|\t\t\t|\t\t\t|\t\t\t|\t\t\t| SG4 Full in   [%b]", full_in[SG4_outport[index]][SG4_out_vc[index]]); 
        end		
		$display ("----------------------------------------------------------------------------------------"); 	
 end
//*/

endmodule


/* module convert_tb_8(in, out);

input [2:0] in;

output reg [2:0] out;
always @(in)
begin
case (in)
3'b000: out<=3'b000;
3'b001: out<=3'b010;
3'b010: out<=3'b100;
3'b011: out<=3'b110;
3'b100: out<=3'b001;
3'b101: out<=3'b011;
3'b110: out<=3'b101;
3'b111: out<=3'b111;

default: out<=3'b000;
endcase
end
endmodule

module convert_tb_16(in, out);

input [3:0] in;

output reg [3:0] out;
always @(in)
begin
case (in)
// 4'b (3b-row)-(1b-col)= 4'b (2b-row)-(1b-col)-(1b-height)
4'b0000: out<=4'b0000;
4'b0001: out<=4'b0010;
4'b0010: out<=4'b0100;
4'b0011: out<=4'b0110;
4'b0100: out<=4'b1000;
4'b0101: out<=4'b1010;
4'b0110: out<=4'b1100;
4'b0111: out<=4'b1110;
4'b1000: out<=4'b0001;
4'b1001: out<=4'b0011;
4'b1010: out<=4'b0101;
4'b1011: out<=4'b0111;
4'b1100: out<=4'b1001;
4'b1101: out<=4'b1011;
4'b1110: out<=4'b1101;
4'b1111: out<=4'b1111;

default: out<=4'b000;
endcase
end
endmodule


 */