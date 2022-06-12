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

module ra_packetizer_core #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 32, 
							REAL_ADDR_BITS = 16, VC_BITS = 1, ID_BITS = 4, EXTRA  = 2, 
							TYPE_BITS = 2) ( 
					
				     clock, reset, 
					 
					 // core and packetizer interface
				     core2net_iRead, core2net_iWrite, 
					 core2net_iAddr, core2net_iData, 
					 
				     net2core_iAddr, net2core_iData, 
					 net2core_iValid, net2core_iReady,
				     
				     core2net_dRead, core2net_dWrite, 
					 core2net_dAddr, core2net_dData, 
					 
				     net2core_dAddr, net2core_dData, 
					 net2core_dValid, net2core_dReady,
					 
					 //packets to core
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

input core2net_iRead,    core2net_iWrite;
input [ADDRESS_BITS-1:0] core2net_iAddr; 
input [DATA_WIDTH-1:0]   core2net_iData;  

output [ADDRESS_BITS-1:0] net2core_iAddr; 
output [DATA_WIDTH-1:0]   net2core_iData;
output net2core_iValid,   net2core_iReady;
					 				     
input core2net_dRead,    core2net_dWrite;
input [ADDRESS_BITS-1:0] core2net_dAddr; 
input [DATA_WIDTH-1:0]   core2net_dData; 
				     
output [ADDRESS_BITS-1:0] net2core_dAddr; 
output [DATA_WIDTH-1:0]   net2core_dData; 
output net2core_dValid,   net2core_dReady;

output [FLIT_WIDTH -1:0] flit_to_send;
output v_send_flit; 
					 
input [FLIT_WIDTH -1:0] flit_received; 
input v_rec_flit; 
input ready; 

wire[ID_BITS - 1: 0] core_ID = CORE; 
reg [ADDRESS_BITS-1:0] net2core_iAddr; 
reg [DATA_WIDTH-1:0]   net2core_iData;
reg net2core_iValid,   net2core_iReady;
					 				    			     
reg [ADDRESS_BITS-1:0] net2core_dAddr; 
reg [DATA_WIDTH-1:0]   net2core_dData; 
reg net2core_dValid,   net2core_dReady;

reg [FLIT_WIDTH -1:0] flit_to_send;
reg v_send_flit; 
					
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

wire [ID_BITS - 1: 0]   source            = core_ID; 
wire [ID_BITS - 1: 0]   idestination      = core2net_iAddr >> REAL_ADDR_BITS; 
wire [EXTRA - 1: 0]     isub_flow         = 0; //from inst. cache to network
wire [TYPE_BITS - 1:0]  iflit_type0       = core2net_iWrite?  HEAD : ALL;
wire [TYPE_BITS - 1:0]  iflit_type1       = TAIL;
wire [VC_BITS - 1:0]    iflit_vc          = 0; //default vc. Proper vc will be assign in the next module 
wire [DATA_WIDTH - 1:0] iflit_payload0    = core2net_iAddr; 

wire [ID_BITS - 1: 0]   ddestination      = core2net_dAddr >> REAL_ADDR_BITS; 
wire [EXTRA - 1: 0]     dsub_flow         = 1; //from data cache to network
wire [TYPE_BITS - 1:0]  dflit_type0       = core2net_dWrite?  HEAD : ALL;
wire [TYPE_BITS - 1:0]  dflit_type1       = TAIL;
wire [VC_BITS - 1:0]    dflit_vc          = 0; //default vc. Proper vc will be assign in the next module 
wire [DATA_WIDTH - 1:0] dflit_payload0    = core2net_dAddr; 

wire [EXTRA - 1: 0]     rec_sub_flow  = flit_received[(FLIT_WIDTH-(2*ID_BITS)-1) -: EXTRA];
wire [TYPE_BITS - 1: 0] rec_flit_type = flit_received[((FLIT_WIDTH - FLOW_BITS) -1) -: TYPE_BITS];
wire i_read_req   = ((rec_sub_flow == 2) & (rec_flit_type == ALL) & (v_rec_flit));
wire i_read_resp0 = ((rec_sub_flow == 2) & (rec_flit_type == HEAD) & (v_rec_flit));
wire i_read_resp1 = ((rec_sub_flow == 2) & (rec_flit_type == TAIL) & (v_rec_flit));

wire d_read_req   = ((rec_sub_flow == 3) & (rec_flit_type == ALL) & (v_rec_flit));
wire d_read_resp0 = ((rec_sub_flow == 3) & (rec_flit_type == HEAD) & (v_rec_flit));
wire d_read_resp1 = ((rec_sub_flow == 3) & (rec_flit_type == TAIL) & (v_rec_flit));

wire change_turn = (((iState == IDLE) & (~(core2net_iRead | core2net_iWrite))) |
				   ((dState == IDLE) & (~(core2net_dRead | core2net_dWrite)))  |
				   ((iState == DONE) | (dState == DONE)));

//Instruction sending logic from local core to network 
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
				iv_send_flit0      <= (core2net_iRead | core2net_iWrite);
				iflit_to_send1     <= core2net_iRead? 0 : 
									 {source, idestination, isub_flow, iflit_type1, iflit_vc, core2net_iData};
				iv_send_flit1      <= core2net_iRead? 0 : core2net_iWrite;	
				iState             <= (core2net_iRead | core2net_iWrite)? SEND : IDLE;
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
 
//Data sending logic from local core to network 
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
				dv_send_flit0      <= (core2net_dRead | core2net_dWrite);
				dflit_to_send1     <= core2net_dRead? 0 : 
									 {source, ddestination, dsub_flow, dflit_type1, dflit_vc, core2net_dData};
				dv_send_flit1      <= core2net_dRead? 0 : core2net_dWrite;	
				dState             <= (core2net_dRead | core2net_dWrite)? SEND : IDLE;
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

//Receiving logic from network to core
always @ (posedge clock) begin  
	net2core_iAddr   <= reset? 0 : (i_read_req | i_read_resp0)? flit_received : net2core_iAddr;
	net2core_iData   <= reset? 0 : (i_read_req | i_read_resp0)? 0 :i_read_resp1? flit_received : 0;
	net2core_iValid  <= reset? 0 : (i_read_req | i_read_resp1)? 1 : 0;
	
	net2core_dAddr   <= reset? 0 : (d_read_req | d_read_resp0)? flit_received : net2core_dAddr; 
	net2core_dData   <= reset? 0 : (d_read_req | d_read_resp0)? 0 : d_read_resp1? flit_received : 0;
	net2core_dValid  <= reset? 0 : (d_read_req | d_read_resp1)? 1 : 0;
end
				   
//Flit sending to packetizer logic for final vc allocation.  
always @ (posedge clock) begin  
	if(reset == 1) begin 
		send_turn        <= 0;
		
		flit_to_send     <= 0; 
		v_send_flit      <= 0; 

		net2core_iReady  <= 1;
		net2core_dReady  <= 1;
	end 
	else begin 
		send_turn     <= change_turn? (~send_turn) : send_turn;
		
		flit_to_send  <= (ready & (iState == SEND) & (send_turn == 0))?  iflit_to_send0 : 
						 (ready & (iState == SEND2) & (send_turn == 0))? iflit_to_send1 : 
						 (ready & (dState == SEND) & (send_turn == 1))?  dflit_to_send0 : 
						 (ready & (dState == SEND2) & (send_turn == 1))? dflit_to_send1 : 0; 
						 
		v_send_flit   <= (ready & (iState == SEND) & (send_turn == 0))?  iv_send_flit0  :
						 (ready & (iState == SEND2) & (send_turn == 0))? iv_send_flit1 : 
						 (ready & (dState == SEND) & (send_turn == 1))?  dv_send_flit0 : 
						 (ready & (dState == SEND2) & (send_turn == 1))? dv_send_flit1 : 0;

		net2core_iReady  <= (i_read_req | i_read_resp1)? 1 : (core2net_iRead | core2net_iWrite)? 0 : net2core_iReady;
		net2core_dReady  <= (d_read_req | d_read_resp1)? 1 : (core2net_dRead | core2net_dWrite)? 0 : net2core_dReady;
	end
end
 
/*
// Debugging 
 always @ (posedge clock) begin 
	$display ("-----------------------------RA Packetizer Core %d-------------------------------------", core_ID);  
	$display ("I State [%d]\t\t| D State [%d]", iState, dState);
	$display ("idestination [%b]\t| isub_flow [%b]", idestination , isub_flow);
	$display ("0-iflit_type[%d]\t| iflit_vc [%b]\t\t| iflit_payload [%h]",iflit_type0, iflit_vc , iflit_payload0);
	$display ("1-iflit_type[%d]\t| iflit_vc [%b]",iflit_type1, iflit_vc);
	$display ("");
	$display ("ddestination [%b]\t| dsub_flow [%b]", ddestination, dsub_flow);
	$display ("0-dflit_type[%d]\t| dflit_vc [%b]\t\t| dflit_payload [%h]",dflit_type0, dflit_vc , dflit_payload0);
	$display ("1-dflit_type[%d]\t| dflit_vc [%b]",dflit_type1, dflit_vc);
	$display ("");
	$display ("Received flit [%h]\t| Valid [%b]\t\t| Ready [%b]", flit_received, v_rec_flit, ready);
	$display ("I Read [%b]\t\t\t| Write0 [%b]\t\t\t| Write1 [%b]", i_read_req, i_read_resp0, i_read_resp1);
	$display ("D Read [%b]\t\t\t| Write0 [%b]\t\t\t| Write1 [%b]", d_read_req, d_read_resp0, d_read_resp1);
	$display ("Sub Flow [%d]\t\t\t| Type [%d]", rec_sub_flow , rec_flit_type);
	$display ("");
	$display ("core2net_iRead [%b]\t| core2net_iWrite [%b]\t| core2net_iAddr [%h]\t| core2net_iData [%h]", core2net_iRead, 
	core2net_iWrite , core2net_iAddr, core2net_iData);
	$display ("core2net_dRead [%b]\t| core2net_dWrite [%b]\t| core2net_dAddr [%h]\t| core2net_dData [%h]", core2net_dRead, 
	core2net_dWrite , core2net_dAddr, core2net_dData);
	$display ("net2core_iReady [%b]\t| net2core_iValid [%b]\t| net2core_iAddr [%h]\t| net2core_iData [%h]", 
	net2core_iReady, net2core_iValid , net2core_iAddr, net2core_iData);
	$display ("net2core_dReady [%b]\t| net2core_dValid [%b]\t| net2core_dAddr [%h]\t| net2core_dData [%h]", 
	net2core_dReady, net2core_dValid , net2core_dAddr, net2core_dData);
	$display ("");
	$display ("0-To send flit [%h] ", iflit_to_send0);
	$display ("0-Valid [%b] ", iv_send_flit0);
	$display ("1-To send flit [%h] ", iflit_to_send1);
	$display ("1-Valid [%b] ", iv_send_flit1);
	$display ("To send flit [%h] ", flit_to_send);
	$display ("Valid [%b] ", v_send_flit);
	$display ("-----------------------------------------------------------------------------------------");
 end 	
 //*/ 
endmodule