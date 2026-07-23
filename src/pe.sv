`include "prim.svh"

module pe 
  import common_pkg::*;
#(
    parameter cid_t DEFAULT_CID = '0
) (
      input  logic         clk
    , input  logic         rst
    // Local communication (with 4 surrounding PEs)
      // IN
    , input  cid_t         in_cid_left
    , input  cid_t         in_cid_right
    , input  cid_t         in_cid_top
    , input  cid_t         in_cid_bot

    , input  logic         in_cpar_left
    , input  logic         in_cpar_right
    , input  logic         in_cpar_top
    , input  logic         in_cpar_bot

    , input  logic         in_erasure_left
    , input  logic         in_erasure_right
    , input  logic         in_erasure_top
    , input  logic         in_erasure_bot

    , output logic         out_erasure_left  
    , output logic         out_erasure_right
    , output logic         out_erasure_top   
    , output logic         out_erasure_bot   

      // OUT
    , output cid_t         self_cid
    , output logic         self_cpar

    // Global communication
    , input  pe_state_e    pe_state
    , input  logic         syndrome_update // pulse -> syndrome updated to 1
    , output logic         syndrome


    // Spread
    , input  logic         spread_in_request
    , input  spread_cid_t  spread_in_connect_cid
    , input  logic         spread_in_connect_parity

    , output logic         spread_out_request
    , output spread_cid_t  spread_out_connect_cid
    , output logic         spread_out_connect_parity
);
    logic self_cpar_next;
    cid_t self_cid_next;

//////////////////////////////////////////
// Grow and Connect request: 
//(Note: each point is also its own cluster at the beginning)
//////////////////////////////////////////
    logic connect_request_left, connect_request_right, connect_request_top, connect_request_bot  ;
    logic belong_cluster_left, belong_cluster_right, belong_cluster_top, belong_cluster_bot;

    logic out_erasure_left_next, out_erasure_right_next, out_erasure_top_next, out_erasure_bot_next;  

    logic connect_request_any, belong_cluster_any;
    cid_t dst_cid, src_cid;
    logic dst_cpar;
    logic is_full_grow, grow;
    logic grow_enable;
    logic upcoming_connect_cpar;

    logic cid_left_top_equal, cid_left_right_equal, cid_left_bot_equal, cid_left_self_equal;
    logic cid_top_right_equal, cid_top_bot_equal, cid_top_self_equal;
    logic cid_right_bot_equal, cid_right_self_equal;
    logic cid_bot_self_equal;

    always_comb begin
        cid_left_top_equal   = in_cid_left  == in_cid_top;
        cid_left_right_equal = in_cid_left  == in_cid_right;
        cid_left_bot_equal   = in_cid_left  == in_cid_bot;
        cid_left_self_equal  = in_cid_left  == self_cid;
        cid_top_right_equal  = in_cid_top   == in_cid_right;
        cid_top_bot_equal    = in_cid_top   == in_cid_bot;
        cid_top_self_equal   = in_cid_top   == self_cid;
        cid_right_bot_equal  = in_cid_right == in_cid_bot;
        cid_right_self_equal = in_cid_right == self_cid;
        cid_bot_self_equal   = in_cid_bot   == self_cid;
    end
    always_comb begin
        upcoming_connect_cpar = (in_cpar_left  & in_erasure_left)
                              ^ (in_cpar_top   & in_erasure_top   & (~cid_left_top_equal))
                              ^ (in_cpar_right & in_erasure_right & (~cid_left_right_equal & ~cid_top_right_equal))
                              ^ (in_cpar_bot   & in_erasure_bot   & (~cid_left_bot_equal   & ~cid_top_bot_equal   & ~cid_right_bot_equal))
                              ^ (self_cpar                        & (~cid_left_self_equal  & ~cid_top_self_equal  & ~cid_right_self_equal & ~cid_bot_self_equal));
        
    end

    always_comb begin
        connect_request_left  = in_erasure_left  & ~out_erasure_left ;
        connect_request_right = in_erasure_right & ~out_erasure_right;
        connect_request_top   = in_erasure_top   & ~out_erasure_top  ;
        connect_request_bot   = in_erasure_bot   & ~out_erasure_bot  ;

        belong_cluster_left  = in_erasure_left  & out_erasure_left ;
        belong_cluster_right = in_erasure_right & out_erasure_right;
        belong_cluster_top   = in_erasure_top   & out_erasure_top  ;
        belong_cluster_bot   = in_erasure_bot   & out_erasure_bot  ;

        connect_request_any = |{connect_request_left, connect_request_right, connect_request_top, connect_request_bot};
        belong_cluster_any  = |{belong_cluster_left , belong_cluster_right , belong_cluster_top , belong_cluster_bot};

        grow = self_cpar; 
        // Only grow if the current cpar is odd. Do not use upcomming cpar here, because
        // Do not use upcoming_cpar here, it will grow fast, but redundant

        out_erasure_left_next  = (connect_request_left  | grow) ? 1'b1 : out_erasure_left ; 
        out_erasure_right_next = (connect_request_right | grow) ? 1'b1 : out_erasure_right; 
        out_erasure_top_next   = (connect_request_top   | grow) ? 1'b1 : out_erasure_top  ; 
        out_erasure_bot_next   = (connect_request_bot   | grow) ? 1'b1 : out_erasure_bot  ; 
    end

    assign grow_enable = (pe_state == PE_GROW);

    `PRIM_FF_EN_RST(out_erasure_left , out_erasure_left_next , grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_right, out_erasure_right_next, grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_top  , out_erasure_top_next  , grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_bot  , out_erasure_bot_next  , grow_enable, rst, clk, '0)

//////////////////////////////////////////
// Spread out/in
//////////////////////////////////////////
    spread_cid_t spread_out_connect_cid_next;
    logic spread_out_connect_parity_next;
    logic spread_request_left, spread_request_right, spread_request_top, spread_request_bot;
    logic spread_request;
    logic is_spread_affected;
    logic connect_cpar;

    cid_t cid_refv;
    logic all_same;

    always_comb begin
        cid_refv = in_erasure_left  ? in_cid_left  :
                   in_erasure_right ? in_cid_right :
                   in_erasure_top   ? in_cid_top   : in_cid_bot;

        all_same = (~in_erasure_left  | (in_cid_left  == cid_refv))
                 & (~in_erasure_right | (in_cid_right == cid_refv))
                 & (~in_erasure_top   | (in_cid_top   == cid_refv))
                 & (~in_erasure_bot   | (in_cid_bot   == cid_refv));

        spread_request = ~all_same;

        is_spread_affected = (self_cid inside {spread_in_connect_cid.src, spread_in_connect_cid.dst});

        // Pick one cid to spread
        if (~cid_left_self_equal & in_erasure_left) begin
            dst_cid      = in_cid_left;
            connect_cpar = in_cpar_left;
        end
        else if (~cid_right_self_equal & in_erasure_right) begin
            dst_cid      = in_cid_right;
            connect_cpar = in_cpar_right;
        end
        else if (~cid_top_self_equal & in_erasure_top) begin
            dst_cid      = in_cid_top;
            connect_cpar = in_cpar_top;
        end
        else if (~cid_bot_self_equal & in_erasure_bot)begin
            dst_cid      = in_cid_bot;
            connect_cpar = in_cpar_bot;
        end
        else begin
            dst_cid      = self_cid;
            connect_cpar = self_cpar;
        end

        if ((dst_cid != in_cid_left) & in_erasure_left) begin
            src_cid = in_cid_left;
        end
        else if ((dst_cid != in_cid_right) & in_erasure_right) begin
            src_cid = in_cid_right;
        end
        else if ((dst_cid != in_cid_top) & in_erasure_top) begin
            src_cid = in_cid_top;
        end
        else begin // TODO: should we create another else if for bot ?
            src_cid = in_cid_bot;
        end

        spread_out_connect_cid_next.dst = dst_cid ;
        spread_out_connect_cid_next.src = src_cid;
        spread_out_connect_parity_next  = upcoming_connect_cpar;
    end

    `PRIM_FF_RST(spread_out_request       , spread_request                , rst, clk, '0)
    `PRIM_FF_RST(spread_out_connect_cid   , spread_out_connect_cid_next   , rst, clk, '0)
    `PRIM_FF_RST(spread_out_connect_parity, spread_out_connect_parity_next, rst, clk, '0)

//////////////////////////////////////////
// ???
/////////////////////////////////////////
    always_comb begin
        if(spread_in_request & is_spread_affected) begin
            self_cid_next = spread_in_connect_cid.dst;
        end
        else if(connect_request_any) begin
            self_cid_next = dst_cid;
        end
        else begin
            self_cid_next = self_cid;
        end

        if(syndrome_update) begin
            self_cpar_next = 1'b1;
        end
        else if(spread_in_request & is_spread_affected) begin
            self_cpar_next = spread_in_connect_parity; 
        end
        else if(connect_request_any) begin
            self_cpar_next = connect_cpar;
            // Do not try to update with upcoming cpar, which creates heterogeneous information (for example, same cid but different cpar)
            // which is really dangerous
        end
        else begin
            self_cpar_next = self_cpar;
        end
    end

    `PRIM_FF_RST(self_cid , self_cid_next , rst, clk, DEFAULT_CID)
    `PRIM_FF_RST(self_cpar, self_cpar_next, rst, clk, '0)

    `PRIM_FF_EN_RST(syndrome, 1'b1, syndrome_update, rst, clk, '0)
endmodule
