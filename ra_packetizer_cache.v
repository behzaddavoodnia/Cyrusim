/** @module : RA_Packetizer
 *  @author : Behzad Davoodnia
 *  Remote access cache protocol for both the instruction and data caches. 
 
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

module ra_packetizer_cache #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 32, 
							 VC_BITS = 1, ID_BITS = 4, EXTRA  = 2, TYPE_BITS = 2) ( 
					
				     clock, reset,  
					 
					// network and local cache interface	
				     net2cache_iRead, net2cache_iWrite, 
					 net2cache_iAddr, net2cache_iData, 
					 
				     cache2net_iAddr, cache2net_iData, 
					 cache2net_iValid, cache2net_iReady,
				     
				     net2cache_dRead, net2cache_dWrite, 
					 net2cache_dAddr, net2cache_dData, 
					 
				     cache2net_dAddr, cache2net_dData, 
					 cache2net_dValid, cache2net_dReady,
					 
					 //packets to cache
				     flit_to_send, v_send_flit, 
					 
  					 flit_received, v_rec_flit, 
					 ready
				     
);
localparam VC_PER_PORTS  = (1 << VC_BITS); 
localparam FLOW_BITS     = (2*ID_BITS) + EXTRA;  
localparam FLIT_WIDTH    = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;
localparam HEAD = 'b10, BODY = 'b00, TAIL = 'b01, ALL= 'b11;
localparam IDLE = 0, SEND = 1, SEND2 = 2, DONE = 3; 

input clock, reset; 

output net2cache_iRead, net2cache_iWrite;
output [ADDRESS_BITS-1:0]net2cache_iAddr; 
output [DATA_WIDTH-1:0]   net2cache_iData;

input cache2net_iValid , cache2net_iReady;
input [ADDRESS_BITS-1:0] cache2net_iAddr;
input [DATA_WIDTH-1:0]   cache2net_iData;

output net2cache_dRead, net2cache_dWrite; 
output [ADDRESS_BITS-1:0] net2cache_dAddr;
output [DATA_WIDTH-1:0]   net2cache_dData;

input cache2net_dValid,  cache2net_dReady;
input [ADDRESS_BITS-1:0] cache2net_dAddr;
input [DATA_WIDTH-1:0]   cache2net_dData;

output [FLIT_WIDTH -1:0] flit_to_send;
output v_send_flit; 
					 
input [FLIT_WIDTH -1:0] flit_received; 
input v_rec_flit; 
input ready;

wire [ID_BITS - 1: 0] core_ID = CORE; 
reg [FLIT_WIDTH -1:0] flit_to_send;
reg v_send_flit; 

reg t_cache2net_iReady, t_cache2net_dReady;

reg [FLIT_WIDTH -1:0] iflit_to_send0, iflit_to_send1; 
reg iv_send_flit0, iv_send_flit1;

reg [FLIT_WIDTH -1:0] iflit_received0, iflit_received1; 
reg iv_rec_flit0, iv_rec_flit1;

reg [FLIT_WIDTH -1:0] dflit_to_send0, dflit_to_send1; 
reg dv_send_flit0, dv_send_flit1;

reg [FLIT_WIDTH -1:0] dflit_received0, dflit_received1; 
reg dv_rec_flit0, dv_rec_flit1;

reg [1:0] iState, dState; 
reg send_turn; 
reg [ID_BITS - 1: 0] i_requester, d_requester; 
reg last_ireq_write, last_dreq_write; 

wire [ID_BITS - 1: 0]   source            = core_ID; 
wire [ID_BITS - 1: 0]   idestination      = i_requester; 
wire [EXTRA - 1: 0]     isub_flow         = 2; //from inst. cache to network
wire [TYPE_BITS - 1:0]  iflit_type0       = last_ireq_write?  ALL : HEAD;
wire [TYPE_BITS - 1:0]  iflit_type1       = TAIL;
wire [VC_BITS - 1:0]    iflit_vc          = 0; //default vc. Proper vc will be assign in the next module 
wire [DATA_WIDTH - 1:0] iflit_payload0    = cache2net_iAddr; 

wire [ID_BITS - 1: 0]   ddestination      = d_requester; 
wire [EXTRA - 1: 0]     dsub_flow         = 3; //from data cache to network
wire [TYPE_BITS - 1:0]  dflit_type0       = last_dreq_write?  ALL : HEAD;
wire [TYPE_BITS - 1:0]  dflit_type1       = TAIL;
wire [VC_BITS - 1:0]    dflit_vc          = 0; //default vc. Proper vc will be assign in the next module 
wire [DATA_WIDTH - 1:0] dflit_payload0    = cache2net_dAddr; 

wire [EXTRA - 1: 0]     rec_sub_flow  = flit_received[(FLIT_WIDTH-(2*ID_BITS)-1) -: EXTRA];
wire [ID_BITS - 1: 0]   rec_source    = flit_received[(FLIT_WIDTH -1) -: ID_BITS];
wire [TYPE_BITS - 1: 0] rec_flit_type = flit_received[((FLIT_WIDTH - FLOW_BITS) -1) -: TYPE_BITS];
wire i_read_req   = ((rec_sub_flow == 0) & (rec_flit_type == ALL) & (v_rec_flit));
wire i_write_req0 = ((rec_sub_flow == 0) & (rec_flit_type == HEAD) & (v_rec_flit));
wire i_write_req1 = ((rec_sub_flow == 0) & (rec_flit_type == TAIL) & (v_rec_flit));

wire d_read_req   = ((rec_sub_flow == 1) & (rec_flit_type == ALL) & (v_rec_flit));
wire d_write_req0 = ((rec_sub_flow == 1) & (rec_flit_type == HEAD) & (v_rec_flit));
wire d_write_req1 = ((rec_sub_flow == 1) & (rec_flit_type == TAIL) & (v_rec_flit));
		
reg t_net2cache_iRead, t_net2cache_iWrite;
reg [ADDRESS_BITS-1:0] t_net2cache_iAddr; 
reg [DATA_WIDTH-1:0]   t_net2cache_iData;

reg t_net2cache_dRead, t_net2cache_dWrite;
reg [ADDRESS_BITS-1:0] t_net2cache_dAddr; 
reg [DATA_WIDTH-1:0]   t_net2cache_dData;

wire iClear = (t_cache2net_iReady & (t_net2cache_iRead | t_net2cache_iWrite)); 
wire dClear = (t_cache2net_dReady & (t_net2cache_dRead | t_net2cache_dWrite)); 

assign net2cache_iRead   = (t_cache2net_iReady)?  t_net2cache_iRead : 0; 
assign net2cache_iWrite  = (t_cache2net_iReady)?  t_net2cache_iWrite: 0;
assign net2cache_iAddr   = (t_cache2net_iReady)?  t_net2cache_iAddr : 0; 
assign net2cache_iData   = (t_cache2net_iReady)?  t_net2cache_iData: 0;

assign net2cache_dRead   = (t_cache2net_dReady)?  t_net2cache_dRead : 0; 
assign net2cache_dWrite  = (t_cache2net_dReady)?  t_net2cache_dWrite: 0;
assign net2cache_dAddr   = (t_cache2net_dReady)?  t_net2cache_dAddr : 0; 
assign net2cache_dData   = (t_cache2net_dReady)?  t_net2cache_dData: 0;

wire change_turn = (((iState == IDLE) & (~cache2net_iValid)) |
				   ((dState == IDLE) & (~cache2net_dValid))  |
				   ((iState == DONE) | (dState == DONE)));

//Instruction sending logic from local cache to network 
always @ (posedge clock) begin  
	if(reset == 1) begin 
		iflit_to_send0     <= 0;
		iv_send_flit0      <= 0;
		iflit_to_send1     <= 0;
		iv_send_flit1      <= 0;
		iState             <= IDLE; 
	end 
	else begin 
		case (iState)
			IDLE: begin
				iflit_to_send0     <= {source, idestination, isub_flow, iflit_type0, iflit_vc, iflit_payload0};
				iv_send_flit0      <= cache2net_iValid;
				iflit_to_send1     <= last_ireq_write? 0 : 
									 {source, idestination, isub_flow, iflit_type1, iflit_vc, cache2net_iData};
				iv_send_flit1      <= last_ireq_write? 0 : cache2net_iValid;	
				iState             <= cache2net_iValid? SEND : IDLE;
			end
		
		SEND: begin
			if((send_turn == 0) & (ready)) begin
				iflit_to_send0  <= 0; 
				iv_send_flit0   <= 0; 
				iState          <=  iv_send_flit1? SEND2: DONE;
			end
		end
		
		SEND2: begin
			if((send_turn == 0) & (ready)) begin
				iflit_to_send1  <= 0; 
				iv_send_flit1   <= 0; 
				iState          <= DONE;
			end 
		end
		
		DONE: begin
				iState        <=  IDLE;
		end
		
		default: iState <= IDLE;
		endcase   
	end
 end
 
//Data sending logic from local cache to network 
always @ (posedge clock) begin  
	if(reset == 1) begin 
		dflit_to_send0     <= 0;
		dv_send_flit0      <= 0;
		dflit_to_send1     <= 0;
		dv_send_flit1      <= 0;
		dState             <= IDLE; 
	end 
	else begin 
		case (dState)
			IDLE: begin
				dflit_to_send0     <= {source, ddestination, dsub_flow, dflit_type0, dflit_vc, dflit_payload0};
				dv_send_flit0      <= cache2net_dValid;
				dflit_to_send1     <= last_dreq_write? 0 : 
									 {source, ddestination, dsub_flow, dflit_type1, dflit_vc, cache2net_dData};
				dv_send_flit1      <= last_dreq_write? 0 : cache2net_dValid;	
				dState             <= cache2net_dValid? SEND : IDLE;
			end
		
		SEND: begin
			if((send_turn == 1) & (ready)) begin
				dflit_to_send0  <= 0; 
				dv_send_flit0   <= 0; 
				dState          <=  dv_send_flit1? SEND2: DONE;
			end
		end
		
		SEND2: begin
			if((send_turn == 1) & (ready)) begin
				dflit_to_send1  <= 0; 
				dv_send_flit1   <= 0; 	
				dState          <= DONE;
			end 
		end
		
		DONE: begin
				dState        <=  IDLE;
		end
		
		default: dState <= IDLE;
		endcase   
	end
 end

//Receiving logic from network to cache
always @ (posedge clock) begin 
	if(reset == 1) begin 
		t_net2cache_iRead   <= 0; 
		t_net2cache_iWrite  <= 0; 
		t_net2cache_iAddr   <= 0; 
		t_net2cache_iData   <= 0;
		
		t_net2cache_dRead   <= 0; 
		t_net2cache_dWrite  <= 0; 
		t_net2cache_dAddr   <= 0; 
		t_net2cache_dData   <= 0;
		
		t_cache2net_iReady  <= 0; 
		t_cache2net_dReady  <= 0; 
	end 
	else begin 
		t_net2cache_iRead   <= iClear? 0 : i_read_req? 1   : t_net2cache_iRead; 
		t_net2cache_iWrite  <= iClear? 0 : i_write_req1? 1 : t_net2cache_iWrite; 
		t_net2cache_iAddr   <= iClear? 0 : (i_read_req | i_write_req0)? 
		                       flit_received : t_net2cache_iAddr;
		t_net2cache_iData   <= iClear? 0 : (i_read_req | i_write_req0)? 
		                       0 : i_write_req1? flit_received : t_net2cache_iData;
		
		t_net2cache_dRead   <= dClear? 0 : d_read_req? 1   : t_net2cache_dRead; 
		t_net2cache_dWrite  <= dClear? 0 : d_write_req1? 1 : t_net2cache_dWrite;  
		t_net2cache_dAddr   <= dClear? 0 : (d_read_req | d_write_req0)? 
		                      flit_received : t_net2cache_dAddr;
		t_net2cache_dData   <= dClear? 0 : (d_read_req | d_write_req0)?
		                       0 : d_write_req1? flit_received : t_net2cache_dData;
							   
		t_cache2net_iReady  <= cache2net_iReady; 
		t_cache2net_dReady  <= cache2net_dReady; 
	end
end
				   
//Flit sending to packetizer logic for final vc allocation.  
always @ (posedge clock) begin  
	if(reset == 1) begin 
		send_turn        <= 0;

		i_requester      <= 0;
		last_ireq_write  <= 0;
		
		d_requester      <= 0;
		last_dreq_write  <= 0;

		flit_to_send     <= 0; 
		v_send_flit      <= 0; 
	end 
	else begin 
		//send_turn        <= change_turn? (~send_turn) : send_turn;
		send_turn        <= ((iState == IDLE) & cache2net_iValid)? 0 : 
							((dState == IDLE) & cache2net_dValid)? 1 : 
							((iState == DONE) | (dState == DONE))? (~send_turn) : send_turn;
		
		i_requester      <= (i_read_req | i_write_req1)? rec_source : cache2net_iValid? 0 : i_requester;
		last_ireq_write  <= i_write_req1? 1 : cache2net_iValid? 0 : last_ireq_write;
		
		d_requester      <= (d_read_req | d_write_req1)? rec_source : cache2net_dValid? 0 : d_requester;
		last_dreq_write  <= d_write_req1? 1 : cache2net_dValid? 0 : last_dreq_write;
		
		flit_to_send     <= (ready & (iState == SEND) & (send_turn == 0))?  iflit_to_send0 : 
							(ready & (iState == SEND2) & (send_turn == 0))? iflit_to_send1 : 
							(ready & (dState == SEND) & (send_turn == 1))?  dflit_to_send0 : 
							(ready & (dState == SEND2) & (send_turn == 1))? dflit_to_send1 : 0; 
						 
		v_send_flit      <= (ready & (iState == SEND) & (send_turn == 0))?  iv_send_flit0  :
							(ready & (iState == SEND2) & (send_turn == 0))? iv_send_flit1 : 
							(ready & (dState == SEND) & (send_turn == 1))?  dv_send_flit0 : 
							(ready & (dState == SEND2) & (send_turn == 1))? dv_send_flit1 : 0;
	end
end

/*
// Debugging 
 always @ (posedge clock) begin 
	$display ("-----------------------------RA Packetizer Cache %d-------------------------------------", core_ID);  
	$display ("I - To send flit [%h]\t| Valid [%b] ", iflit_to_send0, iv_send_flit0);
	$display ("I - To send flit [%h]\t| Valid [%b] ", iflit_to_send1, iv_send_flit1);
	$display ("D - To send flit [%h]\t| Valid [%b] ", dflit_to_send0, dv_send_flit0);
	$display ("D - To send flit [%h]\t| Valid [%b] ", dflit_to_send1, dv_send_flit1);
	$display ("To send flit [%h]\t| Valid [%b] ", flit_to_send, v_send_flit);
	$display ("Ready [%b]\t\t\t\t| Send Turn [%b]\t\t\t| IState [%d] \t\t\| dState[%d]", ready, send_turn, iState, dState); 
	$display ("");
	$display ("Received flit [%h]\t| Valid [%b]\t\t| Ready [%b]", flit_received, v_rec_flit, ready);
	$display ("I Read [%b]\t\t\t| Write0 [%b]\t\t\t| Write1 [%b]", i_read_req, i_write_req0, i_write_req1);
	$display ("D Read [%b]\t\t\t| Write0 [%b]\t\t\t| Write1 [%b]", d_read_req, d_write_req0, d_write_req1);
	$display ("Source [%d]\t\t\t| Sub Flow [%d]\t\t\t| Type [%d]", rec_source , rec_sub_flow , rec_flit_type);
	$display ("");
	$display ("T- net2cache_iRead [%b]| net2cache_iWrite [%b]\t| net2cache_iAddr [%h]\t| net2cache_iData [%h]", 
	t_net2cache_iRead, t_net2cache_iWrite , t_net2cache_iAddr, t_net2cache_iData);
	$display ("T- net2cache_dRead [%b]| net2cache_dWrite [%b]\t| net2cache_dAddr [%h]\t| net2cache_dData [%h]", 
	t_net2cache_dRead, t_net2cache_dWrite , t_net2cache_dAddr, t_net2cache_dData);
	$display ("iRequester [%d]\t\t| last_req_write[%b]", i_requester , last_dreq_write);
	$display ("dRequester [%d]\t\t| last_req_write[%b]", d_requester , last_dreq_write);
	$display (""); 
	$display ("cache2net_iReady [%b]\t| cache2net_iValid [%b]\t| cache2net_iAddr [%h]\t| cache2net_iData [%h]", 
	cache2net_iReady, cache2net_iValid , cache2net_iAddr, cache2net_iData);
	$display ("cache2net_dReady [%b]\t| cache2net_dValid [%b]\t| cache2net_dAddr [%h]\t| cache2net_dData [%h] ", 
	cache2net_dReady, cache2net_dValid , cache2net_dAddr, cache2net_dData);	
	$display ("");
	$display ("net2cache_iRead [%b]\t| net2cache_iWrite [%b]\t| net2cache_iAddr [%h]\t| net2cache_iData [%h]", 
	net2cache_iRead, net2cache_iWrite , net2cache_iAddr, net2cache_iData);
	$display ("net2cache_dRead [%b]\t| net2cache_dWrite [%b]\t| net2cache_dAddr [%h]\t| net2cache_dData [%h]", 
	net2cache_dRead, net2cache_dWrite , net2cache_dAddr, net2cache_dData);
	$display ("-----------------------------------------------------------------------------------------");
 end 	
 //*/
endmodule